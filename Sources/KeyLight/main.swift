import AppKit
import HotkeyKit
import KeyLightCore
import StatusItemKit

/// KeyLight — a standalone menu-bar app that remaps Ctrl + brightness keys to
/// keyboard-backlight up/down (a drop-in replacement for the BetterTouchTool
/// setup), with a live level indicator and a small rebind UI.
final class App: NSObject, NSApplicationDelegate {
    private var status: StatusItemController!
    /// Steps this icon aside while Curtain reveals the hidden block — the bar has
    /// no spare room, so a reveal borrows slots from the apps that cooperate.
    /// Restores itself on a timer if Curtain goes away mid-reveal.
    private var yieldClient: YieldClient!
    private let backlight = makeBacklightController()
    private let model = BindingsModel()
    private var tap: HotkeyTap!
    private var prefs: PreferencesWindowController?
    private var trustTimer: Timer?
    private var iconStyle = IconStyleStore.load(from: .standard)

    /// Menu previews are drawn at a fixed level, not the live one: at 0% the
    /// arc, pie and wedge all collapse to an empty disk and stop being tellable
    /// apart — exactly when someone adjusting the backlight opens the menu. The
    /// preview's job is the shape; the level is on the menu's first row.
    private static let previewFraction: CGFloat = 0.6

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = StatusItemController(
            pollInterval: 5,
            onPoll: { [weak self] in
                self?.reassertTap()
                self?.refreshIcon()
            },
            onBuildMenu: { [weak self] menu in self?.buildMenu(menu) }
        )
        status.start()
        yieldClient = YieldClient(item: status)
        yieldClient.start()

        tap = HotkeyTap(
            bindings: model.bindings,
            onMatch: { [weak self] token in self?.handle(token: token) ?? false }
        )
        model.onChange = { [weak self] bindings in self?.tap.setBindings(bindings) }

        if !tap.isTrusted { tap.requestTrust() }
        startTapIfPossible()
        refreshIcon()
    }

    // MARK: - Tap lifecycle

    private func startTapIfPossible() {
        // Gate on trust, not on start()'s return: an untrusted process can get a
        // non-nil-but-inert tap, and granting permission later won't activate it
        // without recreating. So only create the tap once actually trusted.
        guard tap.isTrusted else {
            scheduleTrustRecheck()
            refreshIcon()
            return
        }
        if !tap.isRunning { tap.start() }
        trustTimer?.invalidate()
        trustTimer = nil
        refreshIcon()
    }

    /// Other apps (BetterDisplay, notably) re-create their session filter taps
    /// on display reconfiguration, head-inserting them in front of ours — after
    /// which they see our bound keys first and can swallow them before we do.
    /// Re-creating our tap on each poll tick keeps it frontmost within seconds
    /// of any such leapfrog, at negligible cost.
    private func reassertTap() {
        // Optional-safe: the first poll fires from status.start() before the
        // tap exists (same reason refreshIcon uses `tap?`).
        guard let tap, tap.isTrusted, tap.isRunning else { return }
        tap.stop()
        tap.start()
    }

    private func scheduleTrustRecheck() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.tap.isTrusted { self.startTapIfPossible() }
        }
    }

    // MARK: - Action

    /// Returns true to swallow the key (always, for our backlight bindings).
    private func handle(token: String) -> Bool {
        guard let action = BacklightAction(rawValue: token) else { return false }
        let current = backlight.currentLevel() ?? 0
        let next = LevelMath.nextLevel(current: current, direction: action.direction)
        backlight.setLevel(next)
        refreshIcon()
        return true
    }

    // MARK: - Icon + menu

    /// All four meters share a `(fraction:color:)` signature, so the style is a
    /// pure swap — the suppressed/untrusted coloring below is unaffected.
    private func makeIcon(_ style: IconStyle, fraction: CGFloat, color: NSColor) -> NSImage {
        switch style {
        case .key: return CharacterIcon.key(level: fraction, active: color == .black)
        case .gauge: return MeterIcon.gauge(fraction: fraction, color: color)
        case .arc: return MeterIcon.arc(fraction: fraction, color: color)
        case .pie: return MeterIcon.pie(fraction: fraction, color: color)
        case .wedge: return MeterIcon.wedge(fraction: fraction, color: color)
        }
    }

    private func refreshIcon() {
        let level = backlight.currentLevel() ?? 0
        let active = tap?.isRunning == true
        let icon: NSImage
        if active && !backlight.isSuppressed {
            // Match the default menu-bar glyph color. A template image is tinted
            // by the system — white in dark mode, black in light, and inverted
            // when the menu is open. Template tinting uses only the drawn alpha
            // (so the conventional black ink is fine); the level still reads from
            // the drawn geometry against the faint 28%-alpha track.
            icon = makeIcon(iconStyle, fraction: CGFloat(level), color: .black)
            // The key is full colour (its lit rays are the level); the meters are templates.
            icon.isTemplate = iconStyle != .key
        } else {
            // KeyLight can't change the backlight right now: either the tap isn't
            // running (Accessibility not yet granted) or macOS is suppressing the
            // backlight (lid closed). A muted gray keeps that visually distinct;
            // the menu says which ("⚠ Grant Accessibility…" / "Backlight
            // suppressed (lid closed)").
            icon = makeIcon(iconStyle, fraction: CGFloat(level), color: .systemGray)
        }
        status.setIcon(icon)
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        if !backlight.isAvailable {
            menu.addItem(disabledItem("Backlight control unavailable"))
        } else if backlight.isSuppressed {
            menu.addItem(disabledItem("Backlight suppressed (lid closed)"))
        } else {
            let pct = Int(((backlight.currentLevel() ?? 0) * 100).rounded())
            menu.addItem(disabledItem("Backlight: \(pct)%"))
        }

        if !(tap?.isTrusted ?? false) {
            menu.addItem(.separator())
            menu.addItem(actionItem("⚠ Grant Accessibility…", #selector(grantTrust)))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("Preferences…", #selector(openPrefs), key: ","))

        let icon = NSMenuItem(title: "Icon", action: nil, keyEquivalent: "")
        icon.submenu = buildIconMenu()
        menu.addItem(icon)

        let login = actionItem("Start at Login", #selector(toggleLogin))
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(actionItem("Quit KeyLight", #selector(quit), key: "q"))
    }

    /// One row per meter style, each previewing itself. Rebuilt on every menu
    /// open, so the checkmark always reflects the live choice.
    private func buildIconMenu() -> NSMenu {
        let menu = NSMenu()
        for style in IconStyle.allCases {
            let item = actionItem(style.label, #selector(selectIcon(_:)))
            item.representedObject = style.rawValue
            item.state = style == iconStyle ? .on : .off
            // Native 18pt: resizing would re-run the drawing handler in a
            // smaller rect while MeterIcon's radii stay put, clipping the glyph.
            let preview = makeIcon(style, fraction: Self.previewFraction, color: .black)
            preview.isTemplate = true
            item.image = preview
            menu.addItem(item)
        }
        return menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        NSMenuItem(title: title, action: nil, keyEquivalent: "")
    }

    private func actionItem(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Menu selectors

    @objc private func grantTrust() {
        tap.requestTrust()
        startTapIfPossible()
    }

    @objc private func openPrefs() {
        if prefs == nil { prefs = PreferencesWindowController(model: model) }
        prefs?.show()
    }

    @objc private func selectIcon(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = IconStyle(rawValue: raw)
        else { return }
        iconStyle = style
        IconStyleStore.save(style, to: .standard)
        refreshIcon()
    }

    @objc private func toggleLogin() { LoginItem.toggle() }

    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
