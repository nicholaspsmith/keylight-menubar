// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import HotkeyKit
import KeyLightCore
import StatusItemKit
import SwiftUI

/// Drives a `TriggerRecorder` and exposes which token (if any) is currently
/// recording, so the SwiftUI view can update its button label.
final class RecorderModel: ObservableObject {
    @Published var recordingToken: String?
    private let recorder = TriggerRecorder()

    func record(token: String, apply: @escaping (Trigger) -> Void) {
        recordingToken = token
        recorder.start { [weak self] trigger in
            apply(trigger)
            self?.recordingToken = nil
        }
    }

    func cancel() {
        recorder.stop()
        recordingToken = nil
    }
}

/// The menu-bar icon style, shared by the status item and the Preferences
/// window. `preview` draws a style the way the bar would, at a fixed level.
final class IconChoice: ObservableObject {
    @Published var style: IconStyle {
        didSet { if style != oldValue { onChange(style) } }
    }
    let preview: (IconStyle) -> NSImage
    private let onChange: (IconStyle) -> Void

    init(style: IconStyle, preview: @escaping (IconStyle) -> NSImage, onChange: @escaping (IconStyle) -> Void) {
        self.style = style
        self.preview = preview
        self.onChange = onChange
    }
}

/// One tile per icon style, each previewing itself; the chosen one is outlined.
struct IconPicker: View {
    @ObservedObject var choice: IconChoice

    var body: some View {
        HStack(spacing: 8) {
            ForEach(IconStyle.allCases, id: \.self) { style in
                let selected = choice.style == style
                Button { choice.style = style } label: {
                    VStack(spacing: 6) {
                        preview(style)
                            .frame(height: 22)
                        Text(style.label)
                            .font(.caption)
                    }
                    .frame(width: 64, height: 52)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    /// Native size: scaling would re-run the drawing handler in another rect
    /// while MeterIcon's radii stay put. Lumen's keycap is in colour, as on the
    /// bar; the meters are templates, tinted to the text colour.
    private func preview(_ style: IconStyle) -> some View {
        let image = choice.preview(style)
        return Group {
            if style == .key {
                Image(nsImage: image)
            } else {
                Image(nsImage: image).renderingMode(.template).foregroundColor(.primary)
            }
        }
    }
}

/// One row per binding: action label, current trigger, Record + Reset. Generic
/// over `model.bindings`, so adding a mappable control later needs no UI change.
struct PreferencesView: View {
    @ObservedObject var model: BindingsModel
    let iconChoice: IconChoice
    @StateObject private var recorder = RecorderModel()
    @State private var startAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keyboard Backlight Shortcuts")
                .font(.headline)

            ForEach(model.bindings, id: \.token) { binding in
                HStack(spacing: 10) {
                    Text(label(for: binding.token))
                        .frame(width: 130, alignment: .leading)
                    Spacer()
                    Text(TriggerFormatter.string(binding.trigger))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 130, alignment: .trailing)
                    Button(recorder.recordingToken == binding.token ? "Press keys…" : "Record") {
                        recorder.record(token: binding.token) { trigger in
                            model.setOverride(token: binding.token, trigger: trigger)
                        }
                    }
                    Button("Reset") { model.reset(token: binding.token) }
                        .disabled(!model.isOverridden(binding.token))
                }
            }

            Divider()
            Text("Defaults match BetterTouchTool (Ctrl + brightness keys). "
                 + "Rebinding to a standard key combo is the most reliable.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            Text("Menu Bar Icon")
                .font(.headline)
            IconPicker(choice: iconChoice)

            Divider()
            Text("General")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Function Keys on Other Keyboards", isOn: $model.functionKeysOnOtherKeyboards)
                Text("F1/F2 brightness, F10/F11/F12 mute and volume on keyboards that aren't Apple's.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // macOS refuses when the app isn't in an Applications folder:
            // LoginItem.set shows why, and the box snaps back to the real state.
            Toggle("Start at Login", isOn: Binding(
                get: { startAtLogin },
                set: { on in
                    LoginItem.set(on)
                    startAtLogin = LoginItem.isEnabled
                }
            ))

            Divider()
            Text("Version \(AppVersion.string)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear { startAtLogin = LoginItem.isEnabled }
        .padding(20)
        .frame(width: 480)
    }

    private func label(for token: String) -> String {
        BacklightAction(rawValue: token)?.label ?? token
    }
}

/// Lazily creates and shows the preferences window.
final class PreferencesWindowController {
    private var window: NSWindow?
    private let model: BindingsModel
    private let iconChoice: IconChoice

    init(model: BindingsModel, iconChoice: IconChoice) {
        self.model = model
        self.iconChoice = iconChoice
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: PreferencesView(model: model, iconChoice: iconChoice))
            let win = NSWindow(contentViewController: host)
            win.title = "KeyLight Preferences"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
