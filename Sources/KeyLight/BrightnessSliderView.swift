import AppKit

/// The menu's first row: a "Backlight" label, a live percentage, and a slider
/// that sets the keyboard backlight as it is dragged. Lives in an NSMenuItem's
/// `view`, so it is rebuilt with the menu on every open.
final class BrightnessSliderView: NSView {
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let percent = NSTextField(labelWithString: "")
    private let onChange: (Double) -> Void

    init(level: Double, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 48))

        let title = NSTextField(labelWithString: "Backlight")
        title.font = .menuFont(ofSize: 0)
        percent.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
        percent.textColor = .secondaryLabelColor
        percent.alignment = .right

        slider.isContinuous = true
        slider.doubleValue = level
        slider.target = self
        slider.action = #selector(slid(_:))
        slider.controlSize = .small
        let bars = NSImage(systemSymbolName: "light.min", accessibilityDescription: nil)
        let bright = NSImage(systemSymbolName: "light.max", accessibilityDescription: nil)
        let low = NSImageView(image: bars ?? NSImage()); low.contentTintColor = .secondaryLabelColor
        let high = NSImageView(image: bright ?? NSImage()); high.contentTintColor = .secondaryLabelColor

        for v in [title, percent, slider, low, high] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            percent.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            percent.firstBaselineAnchor.constraint(equalTo: title.firstBaselineAnchor),
            low.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            low.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            low.widthAnchor.constraint(equalToConstant: 14),
            high.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            high.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            high.widthAnchor.constraint(equalToConstant: 14),
            slider.leadingAnchor.constraint(equalTo: low.trailingAnchor, constant: 6),
            slider.trailingAnchor.constraint(equalTo: high.leadingAnchor, constant: -6),
            slider.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            slider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
        show(level)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Reflect an external change (a hotkey press while the menu is open).
    func update(level: Double) {
        guard !slider.isHighlighted else { return }
        slider.doubleValue = level
        show(level)
    }

    private func show(_ level: Double) {
        percent.stringValue = "\(Int((level * 100).rounded()))%"
    }

    @objc private func slid(_ sender: NSSlider) {
        show(sender.doubleValue)
        onChange(sender.doubleValue)
    }
}
