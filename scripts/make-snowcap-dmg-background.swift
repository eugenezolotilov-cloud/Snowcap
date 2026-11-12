// Usage: swift scripts/make-snowcap-dmg-background.swift <output.png> <scale>
import AppKit

let size = CGSize(width: 660, height: 410)
let scale = CGFloat(Double(CommandLine.arguments[2])!)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
                        bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.scaleBy(x: scale, y: scale)
context.translateBy(x: 0, y: size.height)
context.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor], from: CGFloat, to: CGFloat) {
    let ramp = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(ramp, start: CGPoint(x: 0, y: from), end: CGPoint(x: 0, y: to),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func ridge(_ points: [(CGFloat, CGFloat)], colors: [CGColor], top: CGFloat) {
    let shape = CGMutablePath()
    shape.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for (x, y) in points.dropFirst() { shape.addLine(to: CGPoint(x: x, y: y)) }
    shape.addLine(to: CGPoint(x: size.width, y: size.height))
    shape.addLine(to: CGPoint(x: 0, y: size.height))
    shape.closeSubpath()
    context.saveGState()
    context.addPath(shape)
    context.clip()
    gradient(colors, from: top, to: size.height)
    context.restoreGState()
}

func snowflake(at center: CGPoint, radius: CGFloat, opacity: CGFloat) {
    let shape = CGMutablePath()
    for i in 0..<6 {
        let theta = CGFloat(i) * .pi / 3
        let dx = cos(theta), dy = sin(theta)
        shape.move(to: center)
        shape.addLine(to: CGPoint(x: center.x + dx * radius, y: center.y + dy * radius))
        let joint = CGPoint(x: center.x + dx * radius * 0.60, y: center.y + dy * radius * 0.60)
        for side: CGFloat in [-1, 1] {
            shape.move(to: joint)
            shape.addLine(to: CGPoint(x: center.x + radius * (dx * 0.84 - dy * side * 0.22),
                                      y: center.y + radius * (dy * 0.84 + dx * side * 0.22)))
        }
    }
    context.setStrokeColor(color(0xe0f5ff, alpha: opacity))
    context.setLineWidth(max(0.7, radius * 0.065))
    context.setLineCap(.round)
    context.addPath(shape)
    context.strokePath()
}

gradient([color(0x101d36), color(0x263f5c), color(0x6f9eb3)], from: 0, to: 410)
let skyGlow = CGGradient(colorsSpace: space, colors: [color(0x88c3d7, alpha: 0.34),
                                                      color(0x9ad4e5, alpha: 0)] as CFArray, locations: nil)!
let glowCenter = CGPoint(x: 513, y: 146)
context.drawRadialGradient(skyGlow, startCenter: glowCenter, startRadius: 6, endCenter: glowCenter,
                           endRadius: 238, options: [])

ridge([(0, 219), (60, 174), (109, 198), (176, 136), (220, 167), (245, 159), (322, 231),
       (394, 179), (430, 192), (498, 122), (543, 170), (572, 153), (660, 229)],
      colors: [color(0xc3e2ec), color(0x7b9fb2), color(0x3f617f)], top: 118)
ridge([(0, 295), (89, 238), (135, 265), (226, 207), (301, 267), (355, 247), (434, 282),
       (519, 228), (558, 255), (618, 212), (660, 246)],
      colors: [color(0x8fb1c6), color(0x5b7c99), color(0x2e4c6a)], top: 201)

let drifts = CGMutablePath()
drifts.move(to: CGPoint(x: 0, y: 353))
drifts.addCurve(to: CGPoint(x: 342, y: 369), control1: CGPoint(x: 139, y: 321), control2: CGPoint(x: 249, y: 391))
drifts.addCurve(to: CGPoint(x: 660, y: 350), control1: CGPoint(x: 493, y: 337), control2: CGPoint(x: 572, y: 332))
drifts.addLine(to: CGPoint(x: 660, y: 410))
drifts.addLine(to: CGPoint(x: 0, y: 410))
drifts.closeSubpath()
context.addPath(drifts)
context.saveGState()
context.clip()
gradient([color(0xb7d5e1), color(0x6489a4)], from: 339, to: 410)
context.restoreGState()

for (x, y, r, opacity): (CGFloat, CGFloat, CGFloat, CGFloat) in [
    (82, 83, 20, 0.47), (126, 112, 6, 0.49), (42, 134, 8, 0.39),
    (576, 65, 28, 0.55), (620, 112, 9, 0.54), (543, 106, 7, 0.38),
    (32, 302, 12, 0.47), (624, 297, 16, 0.48), (100, 367, 9, 0.43),
] {
    snowflake(at: CGPoint(x: x, y: y), radius: r, opacity: opacity)
}
for i in 0..<100 {
    let x = CGFloat((i * 211 + 39) % 653)
    let y = CGFloat((i * 139 + 11) % 401)
    if (160...500).contains(x) && y < 131 { continue }
    let r = 0.5 + CGFloat((i * 7) % 10) * 0.12
    context.setFillColor(color(0xedfbff, alpha: 0.18 + CGFloat(i % 7) * 0.065))
    context.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
}

// Finder places the app and Applications at (174, 229) and (486, 229).
// The neutral blue keeps the system icon labels legible in both appearances.
let panel = CGPath(roundedRect: CGRect(x: 58, y: 158, width: 544, height: 173),
                   cornerWidth: 24, cornerHeight: 24, transform: nil)
context.addPath(panel)
context.saveGState()
context.clip()
gradient([color(0x7b91a1), color(0x6d7f90), color(0x637688)], from: 158, to: 331)
context.restoreGState()
context.addPath(panel)
context.setStrokeColor(color(0xe3f8ff, alpha: 0.48))
context.setLineWidth(1)
context.strokePath()

let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: 282, y: 229))
arrow.addLine(to: CGPoint(x: 378, y: 229))
arrow.move(to: CGPoint(x: 367, y: 218))
arrow.addLine(to: CGPoint(x: 378, y: 229))
arrow.addLine(to: CGPoint(x: 367, y: 240))
context.setStrokeColor(color(0xf0faff, alpha: 0.92))
context.setLineWidth(2.5)
context.setLineCap(.round)
context.setLineJoin(.round)
context.addPath(arrow)
context.strokePath()

NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
func centered(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
    let line = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    line.draw(at: CGPoint(x: (size.width - line.size().width) / 2, y: y))
}
centered("Snowcap", y: 19, font: .systemFont(ofSize: 42, weight: .semibold), color: .white)
let script = NSFont(name: "SnellRoundhand-Bold", size: 39)
    ?? NSFont(name: "Apple-Chancery", size: 39)
    ?? NSFontManager.shared.convert(.systemFont(ofSize: 39), toHaveTrait: .italicFontMask)
centered("Let it snow", y: 67, font: script,
         color: NSColor(srgbRed: 0.81, green: 0.94, blue: 1, alpha: 1))
centered("Перетащите Snowcap в «Программы»", y: 125, font: .systemFont(ofSize: 14, weight: .medium),
         color: NSColor(srgbRed: 0.86, green: 0.94, blue: 0.98, alpha: 1))
NSGraphicsContext.current = nil

let image = NSBitmapImageRep(cgImage: context.makeImage()!)
image.size = size
try image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
