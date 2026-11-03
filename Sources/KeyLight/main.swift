// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import HotkeyKit
import KeyLightCore
import StatusItemKit
import os

let log = Logger(subsystem: "com.nicholaspsmith.KeyLight", category: "backlight")

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
    /// The same F-key remap in the HID driver, where Safari's Secure Event
    /// Input can't hide the keys from it.
    private let hidRemapper = HIDKeyRemapper()
    private lazy var preferences = makePreferences(model: model, iconChoice: iconChoice)
    private var trustTimer: Timer?
    /// The menu-bar icon style, chosen in the Preferences window.
    private lazy var iconChoice = IconChoice(
        style: IconStyleStore.load(from: .standard),
        // The Preferences tiles are the dark bar: Lumen lit in colour (black
        // ink is what marks him active), the meters in white, as a dark bar
        // tints its templates.
        preview: { [unowned self] style in
            self.makeIcon(style, fraction: Self.previewFraction, color: style == .key ? .black : .white)
        },
        onChange: { [weak self] style in
            IconStyleStore.save(style, to: .standard)
            self?.refreshIcon()
        })
    private var iconStyle: IconStyle { iconChoice.style }
    /// The slider in the open menu, if any, so hotkey presses keep it in step.
    private weak var sliderView: BrightnessSliderView?
    /// SIGTERM/SIGINT/SIGHUP become a normal quit, so a held sub-floor level
    /// is put back to the native floor (a SIGKILL is cleaned up at next launch).
    private var signalSources: [DispatchSourceSignal] = []
    /// Lumen's once-a-minute shimmer, in his turn with the other mascots: a
    /// gleam sweeps once round his rays. Only the Lumen icon, and only while
    /// the backlight is on and KeyLight can drive it.
    private var minuteCue: MinuteCue!
    /// The level the icon last showed lit, or nil when it showed grey or off;
    /// the shimmer redraws from this rather than asking CoreBrightness 60 times a second.
    private var litLevel: CGFloat?
    private lazy var shimmer = IconAnimation(duration: CharacterIcon.lumenShimmerDuration, frame: { [weak self] t in
        guard let self, let keycap = Self.keycap, let level = self.litLevel else { return }
        let progress = CGFloat(t / CharacterIcon.lumenShimmerDuration)
        self.status.setIcon(CharacterIcon.lumen(keycap: keycap, level: level, active: true, shimmer: progress))
    }, completion: { [weak self] in
        self?.refreshIcon()
    })

    /// Icon previews are drawn at a fixed level, not the live one: at 0% the
    /// arc, pie and wedge all collapse to an empty disk and stop being tellable
    /// apart. The preview's job is the shape, not the level.
    private static let previewFraction: CGFloat = 0.6

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = StatusItemController(
            pollInterval: 5,
            onPoll: { [weak self] in
                self?.reassertTap()
                self?.syncHIDRemap()
                self?.refreshIcon()
            },
            onBuildMenu: { [weak self] menu in self?.buildMenu(menu) }
        )
        status.start()
        yieldClient = YieldClient(item: status)
        yieldClient.start()

        tap = HotkeyTap(
            bindings: model.tapBindings,
            onMatch: { [weak self] token in self?.handle(token: token) ?? false }
        )
        model.onChange = { [weak self] bindings in
            self?.tap.setBindings(bindings)
            self?.syncHIDRemap()
        }
        syncHIDRemap()

        if !tap.isTrusted { tap.requestTrust() }
        startTapIfPossible()
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
        backlight.onExternalChange = { [weak self] in self?.levelChanged() }
        backlight.restoreAfterLaunch()
        refreshIcon()
        reapplyTimeout()

        minuteCue = MinuteCue { [weak self] in
            guard let self, self.iconStyle == .key, Self.keycap != nil, self.litLevel != nil else { return }
            self.shimmer.start()
        }
        minuteCue.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        backlight.shutdown()
        hidRemapper.sync(enabled: false)
    }

    private func syncHIDRemap() {
        hidRemapper.sync(enabled: model.functionKeysOnOtherKeyboards)
    }

    /// Keep the icon and an open menu's slider on the live level.
    private func levelChanged() {
        refreshIcon()
        if let level = backlight.currentLevel() { sliderView?.update(level: level) }
    }

    /// System Settings can overwrite the inactivity timeout at any time (its
    /// own picker writes the same value), so a choice made here is stored and
    /// pushed back at every launch. No choice stored means macOS keeps its own.
    private func reapplyTimeout() {
        guard let chosen = BacklightTimeoutStore.load(from: .standard) else { return }
        backlight.setIdleDimTime(chosen.seconds)
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

    /// Returns true to swallow the key (always, for our own bindings).
    private func handle(token: String) -> Bool {
        if let media = MediaAction(rawValue: token) {
            MediaKeyPoster.post(media)
            return true
        }
        guard let action = BacklightAction(rawValue: token) else { return false }
        let current = backlight.currentLevel() ?? 0
        let next = BacklightLadder.next(
            current: current,
            direction: action.direction,
            subFloor: backlight.supportsSubFloor
        )
        log.info("key \(token, privacy: .public): \(current, privacy: .public) -> \(next, privacy: .public)")
        backlight.setLevel(next)
        refreshIcon()
        sliderView?.update(level: next)
        return true
    }

    // MARK: - Icon + menu

    /// All four meters share a `(fraction:color:)` signature, so the style is a
    /// pure swap — the suppressed/untrusted coloring below is unaffected.
    private static let keycap = IllustratedIcon.load(named: "lumen-keycap", in: .main)

    private func makeIcon(_ style: IconStyle, fraction: CGFloat, color: NSColor) -> NSImage {
        switch style {
        case .key:
            // Lumen's illustrated keycap ships in the bundle; if it is ever missing, the code-drawn key stands in.
            if let keycap = Self.keycap { return CharacterIcon.lumen(keycap: keycap, level: fraction, active: color == .black) }
            return CharacterIcon.key(level: fraction, active: color == .black)
        case .gauge: return MeterIcon.gauge(fraction: fraction, color: color)
        case .arc: return MeterIcon.arc(fraction: fraction, color: color)
        case .pie: return MeterIcon.pie(fraction: fraction, color: color)
        case .wedge: return MeterIcon.wedge(fraction: fraction, color: color)
        }
    }

    private func refreshIcon() {
        // Nothing to control, nothing on the bar: no backlight API on this Mac,
        // or the lid is shut (clamshell on an external display). Not the
        // backlight's own "suppressed" flag — that is also up during every idle
        // fade and in a bright room, and the icon would come and go with them.
        status.isSuppressed = !backlight.isAvailable || Clamshell.isClosed
        let level = BacklightLadder.displayFraction(backlight.currentLevel() ?? 0)
        let active = tap?.isRunning == true
        let icon: NSImage
        if active && !backlight.isSuppressed {
            // Match the default menu-bar glyph color. A template image is tinted
            // by the system — white in dark mode, black in light, and inverted
            // when the menu is open. Template tinting uses only the drawn alpha
            // (so the conventional black ink is fine); the level still reads from
            // the drawn geometry against the faint 28%-alpha track.
            icon = makeIcon(iconStyle, fraction: CGFloat(level), color: .black)
            litLevel = level > 0 ? CGFloat(level) : nil
            // The key is full colour (its lit rays are the level); the meters are templates.
            icon.isTemplate = iconStyle != .key
        } else {
            // KeyLight can't change the backlight right now: either the tap isn't
            // running (Accessibility not yet granted) or macOS is suppressing the
            // backlight (lid closed). A muted gray keeps that visually distinct;
            // the menu says which ("⚠ Grant Accessibility…" / "Backlight
            // suppressed (lid closed)").
            icon = makeIcon(iconStyle, fraction: CGFloat(level), color: .systemGray)
            litLevel = nil
        }
        // Mid-shimmer, the next frame picks up the new level; if Lumen went grey,
        // off or away, the shimmer stops and the icon says so at once.
        if shimmer.isRunning {
            guard litLevel == nil || iconStyle != .key else { return }
            shimmer.cancel()
        }
        status.setIcon(icon)
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        if !backlight.isAvailable {
            menu.addItem(InfoMenuItem.make("Backlight control unavailable"))
        } else if Clamshell.isClosed {
            // Only a shut lid. The daemon's own flag is also up while it
            // idle-dims, and then the slider has to stay: moving it relights.
            menu.addItem(InfoMenuItem.make("Backlight suppressed (lid closed)"))
        } else {
            // A slider row: drag to set the level; the hotkeys keep working too.
            let row = NSMenuItem()
            let view = BrightnessSliderView(level: backlight.currentLevel() ?? 0) { [weak self] level in
                guard let self else { return }
                self.backlight.setLevel(level)
                self.refreshIcon()
            }
            row.view = view
            sliderView = view
            menu.addItem(row)
        }

        if !(tap?.isTrusted ?? false) {
            menu.addItem(.separator())
            menu.addItem(actionItem("⚠ Grant Accessibility…", #selector(grantTrust)))
        }

        // No Settings submenu: the icon style, Function Keys on Other Keyboards,
        // Start at Login and the version live in the Preferences window. The
        // menu keeps the things you reach for: timeout, Preferences…, Quit.
        if menu.items.last?.isSeparatorItem == false { menu.addItem(.separator()) }

        // How long the keys stay lit with nobody typing. macOS owns the timer
        // and relights on the next keypress; this only sets the delay.
        let timeout = NSMenuItem(title: "Backlight Timeout", action: nil, keyEquivalent: "")
        timeout.submenu = buildTimeoutMenu()
        timeout.toolTip = "Turn the backlight off after this long without input; it comes back on the next keypress"
        menu.addItem(timeout)

        // Preferences… (⌘,) and Quit KeyLight (⌘Q), as every Menumon app ends.
        PreferencesMenu.addFooter(to: menu, appName: "KeyLight") { [weak self] in self?.preferences.show() }
        // Every option leaves the menu open (the timeouts); Quit and the "…"
        // items (Grant Accessibility…, Preferences…) close it.
        KeepOpenMenu.apply(to: menu.items)
    }

    /// One row per timeout. The checkmark reads the live value from macOS
    /// rather than our stored choice, so a change made in System Settings shows
    /// here too — and a value we don't offer (10 s, 30 s) checks nothing.
    /// A pick-one set: choosing one moves the tick and leaves the menu open.
    private func buildTimeoutMenu() -> NSMenu {
        let menu = NSMenu()
        // Validation would re-enable every row (their target answers the
        // action); without a backlight to time out they should draw grey.
        menu.autoenablesItems = false
        let live = backlight.idleDimTime().flatMap(BacklightTimeout.init(seconds:))
        var items: [NSMenuItem] = []
        for timeout in BacklightTimeout.allCases {
            let item = actionItem(timeout.label, #selector(selectTimeout(_:)))
            item.representedObject = timeout.seconds
            item.state = timeout == live ? .on : .off
            item.isEnabled = backlight.isAvailable
            if timeout == .never || timeout == .minutes1 { menu.addItem(.separator()) }
            menu.addItem(item)
            items.append(item)
        }
        KeepOpenMenu.pickOne(items)
        return menu
    }

    private func actionItem(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Menu selectors

    @objc private func grantTrust() {
        tap.requestTrust()
        startTapIfPossible()
    }

    @objc private func selectTimeout(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Double,
              let timeout = BacklightTimeout(seconds: seconds)
        else { return }
        backlight.setIdleDimTime(timeout.seconds)
        BacklightTimeoutStore.save(timeout, to: .standard)
    }

}

// MARK: - Entry point

// Handle `--login on|off|status` and exit before any UI exists. Start at Login is
// SMAppService.mainApp, which can only register the calling process's own bundle,
// so this is the only way an installer or script can turn it on.
LoginCLI.runIfRequested()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
