// Usage: swift scripts/make-snowcap-icon.swift Resources/SnowcapIcon.icns
import AppKit
import CoreGraphics

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let background = CGColor(srgbRed: 0.97, green: 0.98, blue: 1, alpha: 1)
let outline = CGColor(srgbRed: 0.84, green: 0.89, blue: 0.94, alpha: 1)
let blue = CGColor(srgbRed: 0.16, green: 0.41, blue: 0.68, alpha: 1)

func header(_ type: String, length: Int) -> Data {
    var size = UInt32(length).bigEndian
    return Data(type.utf8) + withUnsafeBytes(of: &size) { Data($0) }
}

// ICNS stores separate PNG entries for standard and Retina representations.
let representations = [("ic04", 16), ("ic05", 32), ("ic07", 128), ("ic08", 256), ("ic09", 512),
                       ("ic10", 1024), ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)]
var entries = Data()
for (type, size) in representations {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let factor = CGFloat(size) / 1024
    context.scaleBy(x: factor, y: factor)
    let tile = CGPath(roundedRect: CGRect(x: 88, y: 88, width: 848, height: 848),
                      cornerWidth: 196, cornerHeight: 196, transform: nil)
    context.addPath(tile)
    context.setFillColor(background)
    context.setStrokeColor(outline)
    context.setLineWidth(6)
    context.drawPath(using: .fillStroke)

    context.translateBy(x: 512, y: 512)
    context.setStrokeColor(blue)
    context.setLineWidth(44)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    for _ in 0..<6 {
        context.move(to: .zero)
        context.addLine(to: CGPoint(x: 0, y: 282))
        context.move(to: CGPoint(x: -78, y: 236))
        context.addLine(to: CGPoint(x: 0, y: 158))
        context.addLine(to: CGPoint(x: 78, y: 236))
        context.strokePath()
        context.rotate(by: .pi / 3)
    }

    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    let png = bitmap.representation(using: .png, properties: [:])!
    entries += header(type, length: 8 + png.count) + png
}
try (header("icns", length: 8 + entries.count) + entries).write(to: output)
