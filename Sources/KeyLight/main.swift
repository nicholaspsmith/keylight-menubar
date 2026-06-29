import AppKit
import HotkeyKit
import KeyLightCore
import StatusItemKit

/// KeyLight — a standalone menu-bar app that remaps Ctrl + brightness keys to
/// keyboard-backlight up/down (a drop-in replacement for the BetterTouchTool
/// setup), with a live level indicator and a small rebind UI.
final class App: NSObject, NSApplicationDelegate {
    private var status: StatusItemController!
    private let backlight = makeBacklightController()
    private let model = BindingsModel()
    private var tap: HotkeyTap!
    private var prefs: PreferencesWindowController?
    private var trustTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = StatusItemController(
            pollInterval: 5,
            onPoll: { [weak self] in self?.refreshIcon() },
            onBuildMenu: { [weak self] menu in self?.buildMenu(menu) }
        )
        status.start()

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
        let next = LevelMath.nextLevel(
            current: current,
            step: LevelMath.defaultStep,
            direction: action.direction
        )
        backlight.setLevel(next)
        refreshIcon()
        return true
    }

    // MARK: - Icon + menu

    private func refreshIcon() {
        let level = backlight.currentLevel() ?? 0
        let active = tap?.isRunning == true
        let icon: NSImage
        if active {
            // Match the default menu-bar glyph color. A template image is tinted
            // by the system — white in dark mode, black in light, and inverted
            // when the menu is open. Template tinting uses only the drawn alpha
            // (so the conventional black ink is fine); the level still reads from
            // the needle angle and the faint 28%-alpha track.
            icon = MeterIcon.gauge(fraction: CGFloat(level), color: .black)
            icon.isTemplate = true
        } else {
            // Tap not running (Accessibility not yet granted): a muted gray keeps
            // the "needs permission" state visually distinct (the menu also shows
            // the "⚠ Grant Accessibility…" item).
            icon = MeterIcon.gauge(fraction: CGFloat(level), color: .systemGray)
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

        let login = actionItem("Start at Login", #selector(toggleLogin))
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(actionItem("Quit KeyLight", #selector(quit), key: "q"))
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

    @objc private func toggleLogin() { LoginItem.toggle() }

    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
