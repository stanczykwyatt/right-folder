// Draws the app icon and writes it to Resources/AppIcon.icns, plus docs/icon.png for the website.
//
//   swift scripts/make-icon.swift
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns"

/// Draws the icon on a 1024-point canvas, scaled to `pixels`.
func icon(pixels: Int) -> NSBitmapImageRep {
    let image = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
    let scale = NSAffineTransform()
    scale.scale(by: CGFloat(pixels) / 1024)
    scale.concat()

    let slate = NSColor(srgbRed: 0.13, green: 0.17, blue: 0.27, alpha: 1)
    let ice = NSColor(srgbRed: 0.62, green: 0.82, blue: 1.0, alpha: 1)

    // The rounded tile, with the soft shadow macOS icons sit on. Same tile and light as Show Desktop.
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = .black.withAlphaComponent(0.3)
    tileShadow.shadowBlurRadius = 24
    tileShadow.shadowOffset = NSSize(width: 0, height: -12)
    tileShadow.set()
    slate.setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [
        NSColor(srgbRed: 0.80, green: 0.87, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.45, green: 0.57, blue: 0.75, alpha: 1),
        slate,
    ])!.draw(in: tile, angle: -90)

    /// A white shape with a soft shadow, like a sheet of paper on the tile.
    func paper(_ path: NSBezierPath, alpha: CGFloat = 0.96) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = 22
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set()
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    // The folder: its back with the tab, a little darker, then its front.
    let back = NSBezierPath()
    back.move(to: NSPoint(x: 214, y: 470))
    back.line(to: NSPoint(x: 214, y: 600))
    back.curve(to: NSPoint(x: 254, y: 640), controlPoint1: NSPoint(x: 214, y: 622), controlPoint2: NSPoint(x: 232, y: 640))
    back.line(to: NSPoint(x: 410, y: 640))
    back.curve(to: NSPoint(x: 452, y: 620), controlPoint1: NSPoint(x: 428, y: 640), controlPoint2: NSPoint(x: 440, y: 632))
    back.line(to: NSPoint(x: 482, y: 590))
    back.line(to: NSPoint(x: 770, y: 590))
    back.curve(to: NSPoint(x: 810, y: 550), controlPoint1: NSPoint(x: 792, y: 590), controlPoint2: NSPoint(x: 810, y: 572))
    back.line(to: NSPoint(x: 810, y: 470))
    back.close()
    paper(back, alpha: 0.78)
    paper(NSBezierPath(roundedRect: NSRect(x: 214, y: 196, width: 596, height: 356), xRadius: 46, yRadius: 46))

    // The jump: an ice-blue arrow coming over the top and down into the folder, glowing against the slate.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 300, y: 790))
    arrow.line(to: NSPoint(x: 560, y: 790))
    arrow.curve(to: NSPoint(x: 660, y: 690), controlPoint1: NSPoint(x: 615, y: 790), controlPoint2: NSPoint(x: 660, y: 745))
    arrow.line(to: NSPoint(x: 660, y: 520))
    arrow.lineWidth = 58
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 548, y: 520))
    head.line(to: NSPoint(x: 772, y: 520))
    head.line(to: NSPoint(x: 660, y: 384))
    head.close()
    head.lineWidth = 30
    head.lineJoinStyle = .round
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = ice.withAlphaComponent(0.8)
    glow.shadowBlurRadius = 36
    glow.set()
    ice.setStroke()
    ice.setFill()
    arrow.stroke()
    head.fill()
    head.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // A slate line on the folder's front, where the arrow lands, so it reads as going in.
    slate.withAlphaComponent(0.35).setFill()
    NSBezierPath(roundedRect: NSRect(x: 290, y: 270, width: 260, height: 34), xRadius: 17, yRadius: 17).fill()

    NSGraphicsContext.restoreGraphicsState()
    return image
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = icon(pixels: points * scale).representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent(name))
    }
}
try icon(pixels: 256).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", iconset.path, "--output", output]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
Swift.print("Wrote \(output) and docs/icon.png")
