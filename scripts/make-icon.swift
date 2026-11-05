// Draws the app icon at every size macOS needs.
// Usage: swift scripts/make-icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

let output = URL(filePath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Draws on a 1024-point canvas (y up), scaled to `pixels`.
func render(pixels: Int) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    // Background tile on the standard macOS grid: 824 pt with ~22% corner radius, plus a soft shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.3))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0xFFF6EA))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.drawLinearGradient(
        CGGradient(colorsSpace: space, colors: [color(0xFFF8EE), color(0xF5E4CF)] as CFArray, locations: [0, 1])!,
        start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    let center = CGPoint(x: 512, y: 490)

    // Timer ring: a faint track and a teal arc, like the ring in the app.
    let ringRadius: CGFloat = 330
    ctx.setLineCap(.round)
    ctx.setLineWidth(40)
    ctx.setStrokeColor(color(0x16917F, 0.16))
    ctx.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    ctx.setStrokeColor(color(0x16917F))
    ctx.addArc(center: center, radius: ringRadius, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.5, clockwise: true)
    ctx.strokePath()

    // Tomato: slightly wide, with a radial gradient for depth.
    let body = CGRect(x: center.x - 245, y: center.y - 225, width: 490, height: 450)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: color(0x7A1E12, 0.35))
    ctx.addEllipse(in: body)
    ctx.setFillColor(color(0xE64D3D))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addEllipse(in: body)
    ctx.clip()
    ctx.drawRadialGradient(
        CGGradient(colorsSpace: space, colors: [color(0xF57A62), color(0xE64D3D), color(0xC2392B)] as CFArray,
                   locations: [0, 0.55, 1])!,
        startCenter: CGPoint(x: center.x - 90, y: center.y + 90), startRadius: 0,
        endCenter: center, endRadius: 270, options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    // Highlight.
    ctx.saveGState()
    ctx.translateBy(x: center.x - 120, y: center.y + 105)
    ctx.rotate(by: .pi / 5)
    ctx.addEllipse(in: CGRect(x: -70, y: -34, width: 140, height: 68))
    ctx.setFillColor(color(0xFFFFFF, 0.35))
    ctx.fillPath()
    ctx.restoreGState()

    // Leaves: five pointed leaves around the top of the tomato (one pointing down), then the stem.
    let top = CGPoint(x: center.x, y: center.y + 200)
    ctx.setFillColor(color(0x3F9142))
    for i in 0..<5 {
        let angle = -CGFloat.pi / 2 + CGFloat(i) * (2 * .pi / 5)
        ctx.saveGState()
        ctx.translateBy(x: top.x, y: top.y)
        ctx.scaleBy(x: 1, y: 0.62)  // flatten so the leaves lie on the tomato
        ctx.rotate(by: angle)
        let leaf = CGMutablePath()
        leaf.move(to: .zero)
        leaf.addQuadCurve(to: CGPoint(x: 150, y: 0), control: CGPoint(x: 70, y: 48))
        leaf.addQuadCurve(to: .zero, control: CGPoint(x: 70, y: -48))
        ctx.addPath(leaf)
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.addEllipse(in: CGRect(x: top.x - 34, y: top.y - 22, width: 68, height: 44))
    ctx.fillPath()
    let stem = CGPath(roundedRect: CGRect(x: top.x - 15, y: top.y, width: 30, height: 78),
                      cornerWidth: 15, cornerHeight: 15, transform: nil)
    ctx.addPath(stem)
    ctx.setFillColor(color(0x2F7434))
    ctx.fillPath()

    let image = ctx.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: points * scale).write(to: output.appending(path: name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appending(path: "Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")
