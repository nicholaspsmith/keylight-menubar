import AppKit
import HotkeyKit
import KeyLightCore
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

/// One row per binding: action label, current trigger, Record + Reset. Generic
/// over `model.bindings`, so adding a mappable control later needs no UI change.
struct PreferencesView: View {
    @ObservedObject var model: BindingsModel
    @StateObject private var recorder = RecorderModel()

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
        }
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

    init(model: BindingsModel) { self.model = model }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: PreferencesView(model: model))
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
