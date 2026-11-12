import AppKit

/// A slider in the menu, with its value under it. The view follows the
/// pointer itself: the slider's own tracking runs a nested event loop, which falls out of step with the menu's and
/// leaves the knob stuck now and then.
final class MenuSlider: NSView {
    var changed: ((Double) -> Void)?

    var value = 100.0 {
        didSet { show() }
    }
    private var sent = 100.0

    private let slider = NSSlider()
    private let caption = NSTextField(labelWithString: "")
    init(label: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        autoresizingMask = .width

        slider.minValue = 0
        slider.maxValue = 200
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(slide)
        slider.setAccessibilityLabel(label)

        caption.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        caption.textColor = .secondaryLabelColor
        caption.alignment = .center

        for view in [slider, caption] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        // The track starts under the section header text of a macOS 26 menu.
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            slider.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            caption.centerXAnchor.constraint(equalTo: slider.centerXAnchor),
            caption.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
            caption.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
        setFrameSize(NSSize(width: frame.width, height: fittingSize.height))
        show()
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) { follow(event) }

    override func mouseDragged(with event: NSEvent) { follow(event) }

    /// Moves the knob to the pointer, to the nearest step.
    private func follow(_ event: NSEvent) {
        let x = slider.convert(event.locationInWindow, from: nil).x
        let knob = (slider.cell as? NSSliderCell)?.knobThickness ?? 0
        let width = slider.bounds.width - knob
        let along = width > 0 ? min(max((x - knob / 2) / width, 0), 1) : 0
        set(slider.minValue + along * (slider.maxValue - slider.minValue))
    }

    /// Moved by accessibility.
    @objc private func slide() {
        set(slider.doubleValue)
    }

    private func set(_ value: Double) {
        let next = min(max(value.rounded(), slider.minValue), slider.maxValue)
        slider.doubleValue = next
        describe(next)
        guard next != sent else { return }
        sent = next
        changed?(next)
    }

    private func show() {
        slider.doubleValue = value
        sent = value
        describe(value)
    }

    private func describe(_ value: Double) {
        let text = "\(Int(value.rounded()))%"
        slider.setAccessibilityValueDescription(text)
        caption.stringValue = text
    }
}

