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
/// window. `preview` draws a style the way a dark bar would, at a fixed level.
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

/// KeyLight's Preferences window (menu ▸ Preferences…, ⌘,), on
/// StatusItemKit's shared `PreferencesPane`: Start at Login and the function
/// keys, the backlight shortcuts, then the menu-bar icon.
struct PreferencesView: View {
    @ObservedObject var model: BindingsModel
    @ObservedObject var iconChoice: IconChoice
    @ObservedObject var recorder: RecorderModel

    var body: some View {
        PreferencesForm {
            Section {
                StartAtLoginToggle()
                Toggle("Function Keys on Other Keyboards", isOn: $model.functionKeysOnOtherKeyboards)
            } header: {
                Text("General")
            } footer: {
                PreferencesNote("Function keys: F1/F2 brightness, F10/F11/F12 mute and volume on keyboards that aren't Apple's.")
            }

            // One row per binding: action, current trigger, Record + Reset.
            // Generic over `model.bindings`, so a new mappable control needs no UI change.
            Section {
                ForEach(model.bindings, id: \.token) { binding in
                    LabeledContent(label(for: binding.token)) {
                        HStack(spacing: 8) {
                            Text(TriggerFormatter.string(binding.trigger))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Button(recorder.recordingToken == binding.token ? "Press keys…" : "Record") {
                                recorder.record(token: binding.token) { trigger in
                                    model.setOverride(token: binding.token, trigger: trigger)
                                }
                            }
                            Button("Reset") { model.reset(token: binding.token) }
                                .disabled(!model.isOverridden(binding.token))
                        }
                    }
                }
            } header: {
                Text("Keyboard Backlight Shortcuts")
            } footer: {
                PreferencesNote("Defaults match BetterTouchTool (Ctrl + brightness keys). "
                                + "Rebinding to a standard key combo is the most reliable.")
            }

            Section("Menu Bar Icon") {
                IconTilePicker(IconStyle.allCases.map {
                    IconTilePicker.Choice(id: $0, title: $0.label, image: iconChoice.preview($0))
                }, selection: $iconChoice.style)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func label(for token: String) -> String {
        BacklightAction(rawValue: token)?.label ?? token
    }
}

/// The window, created on first use. A recording in progress is abandoned
/// when the window closes or is shown again, so the recorder's key monitor
/// never outlives it.
func makePreferences(model: BindingsModel, iconChoice: IconChoice) -> PreferencesPane {
    let recorder = RecorderModel()
    let pane = PreferencesPane(appName: "KeyLight") {
        PreferencesView(model: model, iconChoice: iconChoice, recorder: recorder)
    }
    pane.onShow = { recorder.cancel() }
    pane.onClose = { recorder.cancel() }
    return pane
}
