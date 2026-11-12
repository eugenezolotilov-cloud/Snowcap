import AppKit

/// A square direction pad. The arrow points down at zero and tilts toward the pointer.
final class MenuSnowDirection: NSView {
    private let limit = SnowTuning.directionLimit
    var changed: ((Int) -> Void)?
    var angle = 0 {
        didSet {
            setAccessibilityValue(angle)
            setAccessibilityValueDescription("\(angle)°")
            needsDisplay = true
        }
    }

    init(label: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 144))
        autoresizingMask = .width
        setAccessibilityElement(true)
        setAccessibilityRole(.slider)
        setAccessibilityLabel(label)
        setAccessibilityMinValue(-limit)
        setAccessibilityMaxValue(limit)
        setAccessibilityValue(angle)
        setAccessibilityValueDescription("0°")
    }

    required init?(coder: NSCoder) { nil }

    private var square: NSRect {
        NSRect(x: bounds.midX - 56, y: bounds.maxY - 118, width: 112, height: 112)
    }

    private var pivot: CGPoint {
        CGPoint(x: square.midX, y: square.midY + 13)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        square.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) { follow(event) }
    override func mouseDragged(with event: NSEvent) { follow(event) }

    private func follow(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let x = point.x - pivot.x
        let down = max(0, pivot.y - point.y)
        guard hypot(x, down) >= 5 else { return }
        select(Int((atan2(x, down) * 180 / .pi).rounded()))
    }

    override func accessibilityPerformIncrement() -> Bool { select(angle + 5) }
    override func accessibilityPerformDecrement() -> Bool { select(angle - 5) }

    @discardableResult
    private func select(_ requested: Int) -> Bool {
        let next = min(max(requested, -limit), limit)
        guard next != angle else { return false }
        angle = next
        changed?(next)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let plate = NSBezierPath(roundedRect: square, xRadius: 10, yRadius: 10)
        NSColor.controlBackgroundColor.withAlphaComponent(0.75).setFill()
        plate.fill()
        NSColor.separatorColor.setStroke()
        plate.lineWidth = 1
        plate.stroke()

        let guide = NSBezierPath()
        guide.appendArc(withCenter: pivot, radius: 41, startAngle: -90 - CGFloat(limit), endAngle: -90 + CGFloat(limit))
        guide.lineWidth = 1
        guide.stroke()
        for marker in [-limit, 0, limit] {
            let tick = NSBezierPath()
            tick.move(to: point(at: marker, distance: 38))
            tick.line(to: point(at: marker, distance: 44))
            tick.lineWidth = 1
            tick.stroke()
        }

        let tail = point(at: angle, distance: -14)
        let tip = point(at: angle, distance: 32)
        let head = point(at: angle, distance: 20)
        let radians = CGFloat(angle) * .pi / 180
        let wing = CGPoint(x: 9 * cos(radians), y: 9 * sin(radians))
        let shaft = NSBezierPath()
        shaft.move(to: tail)
        shaft.line(to: head)
        shaft.lineWidth = 5
        shaft.lineCapStyle = .round
        NSColor.controlAccentColor.setStroke()
        shaft.stroke()

        let arrow = NSBezierPath()
        arrow.move(to: tip)
        arrow.line(to: CGPoint(x: head.x + wing.x, y: head.y + wing.y))
        arrow.line(to: CGPoint(x: head.x - wing.x, y: head.y - wing.y))
        arrow.close()
        NSColor.controlAccentColor.setFill()
        arrow.fill()

        let caption = NSAttributedString(string: "\(angle)°", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        caption.draw(at: CGPoint(x: bounds.midX - caption.size().width / 2, y: 5))
    }

    private func point(at angle: Int, distance: CGFloat) -> CGPoint {
        let radians = CGFloat(angle) * .pi / 180
        return CGPoint(x: pivot.x + distance * sin(radians), y: pivot.y - distance * cos(radians))
    }
}
