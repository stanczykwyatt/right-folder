// Draws the README demo (docs/demo.gif) and the link preview image (docs/social.png).
// Everything is drawn here rather than recorded, so the art never shows anyone's real desktop or
// folders. The writing app, its Save dialog, the folders and the files are all made up.
//
//   swift scripts/make-art.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

let ink = NSColor(srgbRed: 0.05, green: 0.06, blue: 0.07, alpha: 1)
let ice = NSColor(srgbRed: 0.62, green: 0.82, blue: 1.0, alpha: 1)

func bitmap(_ width: Int, _ height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Cool silver light on a dark wallpaper, like Show Desktop's art.
func wallpaper(_ rect: NSRect) {
    NSGradient(starting: NSColor(srgbRed: 0.08, green: 0.09, blue: 0.13, alpha: 1), ending: ink)!.draw(in: rect, angle: -90)
    let glows: [(CGFloat, CGFloat, CGFloat, NSColor)] = [
        (0.18, 0.75, 0.42, NSColor(srgbRed: 0.84, green: 0.89, blue: 0.95, alpha: 0.45)),
        (0.85, 0.72, 0.38, NSColor(srgbRed: 0.59, green: 0.68, blue: 0.81, alpha: 0.40)),
        (0.70, 0.12, 0.46, NSColor(srgbRed: 0.75, green: 0.81, blue: 0.89, alpha: 0.32)),
        (0.22, 0.15, 0.30, NSColor(srgbRed: 0.44, green: 0.53, blue: 0.65, alpha: 0.32)),
    ]
    for (x, y, r, color) in glows {
        let center = NSPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        NSGradient(starting: color, ending: color.withAlphaComponent(0))!
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: rect.width * r, options: [])
    }
}

func symbol(_ name: String, size: CGFloat, colors: [NSColor], weight: NSFont.Weight = .regular) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight).applying(.init(paletteColors: colors))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
}

@discardableResult
func text(
    _ string: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .white,
    centered: Bool = false, mono: Bool = false
) -> CGFloat {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let width = (string as NSString).size(withAttributes: attributes).width
    (string as NSString).draw(at: NSPoint(x: centered ? point.x - width / 2 : point.x, y: point.y), withAttributes: attributes)
    return width
}

/// A dark app window with a title bar. Returns the content area.
@discardableResult
func window(_ frame: NSRect, title: String, alpha: CGFloat = 1, scale: CGFloat = 1, key: Bool) -> NSRect {
    let rect = NSRect(
        x: frame.midX - frame.width * scale / 2, y: frame.midY - frame.height * scale / 2,
        width: frame.width * scale, height: frame.height * scale
    )
    let body = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent((key ? 0.55 : 0.35) * alpha)
    shadow.shadowBlurRadius = key ? 30 : 18
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor(srgbRed: 0.15, green: 0.16, blue: 0.19, alpha: alpha).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.12 * alpha).setStroke()
    body.lineWidth = 1
    body.stroke()
    let colors: [NSColor] = key ? [.systemRed, .systemYellow, .systemGreen] : [.gray, .gray, .gray]
    for (index, color) in colors.enumerated() {
        color.withAlphaComponent(alpha * (key ? 1 : 0.5)).setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.minX + 14 + CGFloat(index) * 18, y: rect.maxY - 22, width: 11, height: 11)).fill()
    }
    text(title, at: NSPoint(x: rect.midX, y: rect.maxY - 24), size: 12, weight: .semibold, color: .white.withAlphaComponent((key ? 0.85 : 0.45) * alpha), centered: true)
    return NSRect(x: rect.minX + 18, y: rect.minY + 14, width: rect.width - 36, height: rect.height - 50)
}

func cursor(at point: NSPoint, pressed: Bool) {
    let arrow = NSBezierPath()
    let s: CGFloat = pressed ? 0.9 : 1
    arrow.move(to: point)
    arrow.line(to: NSPoint(x: point.x, y: point.y - 22 * s))
    arrow.line(to: NSPoint(x: point.x + 5.5 * s, y: point.y - 17 * s))
    arrow.line(to: NSPoint(x: point.x + 9.5 * s, y: point.y - 25.5 * s))
    arrow.line(to: NSPoint(x: point.x + 13 * s, y: point.y - 24 * s))
    arrow.line(to: NSPoint(x: point.x + 9 * s, y: point.y - 15.5 * s))
    arrow.line(to: NSPoint(x: point.x + 16 * s, y: point.y - 15.5 * s))
    arrow.close()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.4)
    shadow.shadowBlurRadius = 3
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    shadow.set()
    NSColor.black.setFill()
    arrow.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.setStroke()
    arrow.lineWidth = 1.5
    arrow.stroke()
}

func panel(_ rect: NSRect, alpha: CGFloat = 1) {
    let body = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.5 * alpha)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    NSColor(srgbRed: 0.17, green: 0.18, blue: 0.21, alpha: alpha).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.14 * alpha).setStroke()
    body.lineWidth = 1
    body.stroke()
}

func highlight(_ rect: NSRect, y: CGFloat, height: CGFloat, alpha: CGFloat = 0.85) {
    NSColor.systemBlue.withAlphaComponent(alpha).setFill()
    NSBezierPath(roundedRect: NSRect(x: rect.minX + 6, y: y, width: rect.width - 12, height: height), xRadius: 6, yRadius: 6).fill()
}

// MARK: Scene

let width: CGFloat = 720
let height: CGFloat = 450
let menuBarHeight: CGFloat = 26
let iconCenter = NSPoint(x: width - 168, y: height - menuBarHeight / 2)
let inkpadFrame = NSRect(x: 22, y: 34, width: 440, height: 360)
let finderFrame = NSRect(x: 540, y: 250, width: 166, height: 150)
let sheetRect = NSRect(x: 48, y: 150, width: 388, height: 210)
let panelRect = NSRect(x: 446, y: 64, width: 210, height: 296)

/// The folders the panel lists, top to bottom, with where each is.
let rows: [(section: String?, name: String, place: String, symbol: String)] = [
    ("Open in Finder", "Drafts", "~/Documents/Thesis", "folder"),
    (nil, "Downloads", "~", "arrow.down.circle"),
    ("Favorites", "Lab Notes", "~/Documents", "folder"),
    (nil, "Reading", "iCloud Drive", "icloud"),
    ("Recent", "Figures", "~/Documents/Thesis", "folder"),
]

/// What's in each folder, as the dialog lists it.
let contents: [String: [String]] = [
    "Documents": ["Lab Notes", "Thesis", "Reading list.md", "Week 5 field notes.md"],
    "Drafts": ["Chapter 3.md", "Methods.md", "Outline.md"],
    "Lab Notes": ["2026-10 Imaging", "Protocols", "Week 4 field notes.md", "Week 5 field notes.md"],
]

/// Each row's top edge in the panel.
func rowTop(_ index: Int) -> CGFloat {
    var y = panelRect.maxY - 36
    for (i, row) in rows.enumerated() {
        if row.section != nil { y -= 18 }
        if i == index { return y }
        y -= 32
    }
    return y
}

struct Moment {
    var sheet: CGFloat = 0
    var panelAlpha: CGFloat = 0
    var folder = "Documents"
    var hovering: Int?
    var saveHover = false
    var keycap: String?
    var cursorAt = NSPoint(x: 300, y: 120)
    var pressed = false
    var saved = false
}

/// A writing app with a note open. Plain and made up, not any real app.
func inkpad(_ m: Moment) {
    let title = m.saved ? "Field notes, week 6 — Lab Notes" : "Untitled — Inkpad"
    let content = window(inkpadFrame, title: title, key: true)
    let lines: [CGFloat] = [0.82, 0.95, 0.9, 0.6, 0, 0.88, 0.93, 0.74, 0.5]
    for (index, length) in lines.enumerated() where length > 0 {
        NSColor.white.withAlphaComponent(index == 0 ? 0.55 : 0.22).setFill()
        let y = content.maxY - 26 - CGFloat(index) * 22
        NSBezierPath(roundedRect: NSRect(x: content.minX + 10, y: y, width: (content.width - 20) * length, height: index == 0 ? 10 : 7), xRadius: 3, yRadius: 3).fill()
    }
}

/// A Finder window in the back, showing the Drafts folder.
func finder() {
    let content = window(finderFrame, title: "Drafts", key: false)
    for (index, name) in ["Chapter 3.md", "Methods.md", "Outline.md"].enumerated() {
        symbol("doc.text", size: 11, colors: [.white.withAlphaComponent(0.4)]).draw(at: NSPoint(x: content.minX, y: content.maxY - 20 - CGFloat(index) * 22), from: .zero, operation: .sourceOver, fraction: 1)
        text(name, at: NSPoint(x: content.minX + 18, y: content.maxY - 20 - CGFloat(index) * 22), size: 10.5, color: .white.withAlphaComponent(0.45))
    }
}

/// The Save sheet, sliding down from Inkpad's title bar as `m.sheet` goes from 0 to 1.
func sheet(_ m: Moment) {
    guard m.sheet > 0 else { return }
    let visible = sheetRect.height * m.sheet
    let rect = NSRect(x: sheetRect.minX, y: sheetRect.maxY - visible, width: sheetRect.width, height: visible)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: rect).setClip()
    let shift = sheetRect.height - visible
    let body = NSRect(x: sheetRect.minX, y: sheetRect.minY + shift, width: sheetRect.width, height: sheetRect.height)
    panel(body)
    let left = body.minX + 16
    text("Save As:", at: NSPoint(x: left, y: body.maxY - 30), size: 12, color: .white.withAlphaComponent(0.7))
    NSColor.white.withAlphaComponent(0.08).setFill()
    let field = NSRect(x: left + 62, y: body.maxY - 34, width: 240, height: 22)
    NSBezierPath(roundedRect: field, xRadius: 5, yRadius: 5).fill()
    NSColor.systemBlue.withAlphaComponent(0.8).setStroke()
    let ring = NSBezierPath(roundedRect: field.insetBy(dx: -1, dy: -1), xRadius: 6, yRadius: 6)
    ring.lineWidth = 2
    ring.stroke()
    text("Field notes, week 6", at: NSPoint(x: field.minX + 7, y: field.minY + 4), size: 12)
    text("Where:", at: NSPoint(x: left + 9, y: body.maxY - 62), size: 12, color: .white.withAlphaComponent(0.7))
    let popup = NSRect(x: left + 62, y: body.maxY - 66, width: 170, height: 22)
    NSColor.white.withAlphaComponent(0.1).setFill()
    NSBezierPath(roundedRect: popup, xRadius: 5, yRadius: 5).fill()
    symbol("folder.fill", size: 11, colors: [ice]).draw(at: NSPoint(x: popup.minX + 7, y: popup.minY + 5), from: .zero, operation: .sourceOver, fraction: 1)
    text(m.folder, at: NSPoint(x: popup.minX + 26, y: popup.minY + 4), size: 12, weight: .medium)
    symbol("chevron.up.chevron.down", size: 9, colors: [.white.withAlphaComponent(0.5)]).draw(at: NSPoint(x: popup.maxX - 16, y: popup.minY + 6), from: .zero, operation: .sourceOver, fraction: 1)
    let list = NSRect(x: left, y: body.minY + 46, width: body.width - 32, height: 90)
    NSColor.black.withAlphaComponent(0.18).setFill()
    NSBezierPath(roundedRect: list, xRadius: 7, yRadius: 7).fill()
    for (index, name) in (contents[m.folder] ?? []).prefix(4).enumerated() {
        let isFile = name.hasSuffix(".md")
        let y = list.maxY - 20 - CGFloat(index) * 19
        symbol(isFile ? "doc.text" : "folder.fill", size: 10.5, colors: [isFile ? .white.withAlphaComponent(0.4) : ice]).draw(at: NSPoint(x: list.minX + 10, y: y), from: .zero, operation: .sourceOver, fraction: 1)
        text(name, at: NSPoint(x: list.minX + 28, y: y), size: 11, color: .white.withAlphaComponent(isFile ? 0.45 : 0.85))
    }
    let save = NSRect(x: body.maxX - 80, y: body.minY + 12, width: 64, height: 24)
    let cancel = NSRect(x: save.minX - 76, y: save.minY, width: 68, height: 24)
    NSColor.white.withAlphaComponent(0.12).setFill()
    NSBezierPath(roundedRect: cancel, xRadius: 6, yRadius: 6).fill()
    text("Cancel", at: NSPoint(x: cancel.midX, y: cancel.minY + 5), size: 12, centered: true)
    (m.saveHover && m.pressed ? NSColor.systemBlue.blended(withFraction: 0.3, of: .black)! : NSColor.systemBlue).setFill()
    NSBezierPath(roundedRect: save, xRadius: 6, yRadius: 6).fill()
    text("Save", at: NSPoint(x: save.midX, y: save.minY + 5), size: 12, weight: .medium, centered: true)
    NSGraphicsContext.restoreGraphicsState()
}

let saveButton = NSRect(x: sheetRect.maxX - 80, y: sheetRect.minY + 12, width: 64, height: 24)

/// Right Folder's panel beside the sheet.
func jumpPanel(_ m: Moment) {
    guard m.panelAlpha > 0 else { return }
    let a = m.panelAlpha
    panel(panelRect, alpha: a)
    let left = panelRect.minX + 12
    symbol("arrowshape.turn.up.right", size: 11, colors: [.white.withAlphaComponent(0.55 * a)]).draw(at: NSPoint(x: left, y: panelRect.maxY - 23), from: .zero, operation: .sourceOver, fraction: 1)
    text("Save to…", at: NSPoint(x: left + 20, y: panelRect.maxY - 24), size: 12.5, weight: .bold, color: .white.withAlphaComponent(a))
    for (index, row) in rows.enumerated() {
        let top = rowTop(index)
        if let section = row.section {
            text(section, at: NSPoint(x: left, y: top + 3), size: 10, weight: .semibold, color: .white.withAlphaComponent(0.45 * a))
        }
        let current = row.name == m.folder
        if m.hovering == index { highlight(panelRect, y: top - 30, height: 29, alpha: 0.85 * a) }
        symbol(row.symbol, size: 12, colors: [ice.withAlphaComponent(a)]).draw(at: NSPoint(x: left, y: top - 21), from: .zero, operation: .sourceOver, fraction: 1)
        text(row.name, at: NSPoint(x: left + 24, y: top - 15), size: 12, weight: current ? .semibold : .regular, color: .white.withAlphaComponent(a))
        text(row.place, at: NSPoint(x: left + 24, y: top - 28), size: 9.5, color: .white.withAlphaComponent((m.hovering == index ? 0.75 : 0.45) * a))
        if current {
            symbol("checkmark", size: 10, colors: [.white.withAlphaComponent(0.7 * a)], weight: .semibold).draw(at: NSPoint(x: panelRect.maxX - 24, y: top - 20), from: .zero, operation: .sourceOver, fraction: 1)
        }
    }
    NSColor.white.withAlphaComponent(0.12 * a).setFill()
    NSRect(x: panelRect.minX + 10, y: panelRect.minY + 26, width: panelRect.width - 20, height: 1).fill()
    text("⌃⌥J next · add ⇧ to go back", at: NSPoint(x: left, y: panelRect.minY + 9), size: 10, color: .white.withAlphaComponent(0.45 * a))
}

/// The keys being pressed, shown as caps, since a recording can't show your hands.
func keycap(_ keys: String) {
    let size = (keys as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 22, weight: .semibold)])
    let rect = NSRect(x: width / 2 - size.width / 2 - 18, y: 52, width: size.width + 36, height: 44)
    panel(rect)
    text(keys, at: NSPoint(x: rect.midX, y: rect.minY + 11), size: 22, weight: .semibold, centered: true)
}

func scene(_ m: Moment) {
    wallpaper(NSRect(x: 0, y: 0, width: width, height: height))
    finder()
    inkpad(m)
    sheet(m)
    jumpPanel(m)

    // The menu bar.
    NSColor(srgbRed: 0.06, green: 0.07, blue: 0.09, alpha: 0.72).setFill()
    NSRect(x: 0, y: height - menuBarHeight, width: width, height: menuBarHeight).fill()
    text("Inkpad", at: NSPoint(x: 18, y: height - 19), size: 12.5, weight: .bold)
    for (index, word) in ["File", "Edit", "Format", "Window"].enumerated() {
        text(word, at: NSPoint(x: 80 + CGFloat(index) * 48, y: height - 19), size: 12.5)
    }
    statusIcon(at: iconCenter)
    for (index, name) in ["wifi", "magnifyingglass", "switch.2"].enumerated() {
        let image = symbol(name, size: 13, colors: [.white])
        image.draw(at: NSPoint(x: width - 128 + CGFloat(index) * 30, y: height - 20), from: .zero, operation: .sourceOver, fraction: 1)
    }
    text("9:41", at: NSPoint(x: width - 40, y: height - 19), size: 12.5, weight: .medium)

    if let keys = m.keycap { keycap(keys) }
    cursor(at: m.cursorAt, pressed: m.pressed)
}

/// The app's menu bar icon, drawn as in the app: a folder with an arrow going in.
func statusIcon(at center: NSPoint) {
    NSColor.white.set()
    let folder = NSBezierPath()
    folder.move(to: NSPoint(x: center.x - 7, y: center.y - 5.5))
    folder.line(to: NSPoint(x: center.x - 7, y: center.y + 4.5))
    folder.line(to: NSPoint(x: center.x - 2.4, y: center.y + 4.5))
    folder.line(to: NSPoint(x: center.x - 0.9, y: center.y + 3))
    folder.line(to: NSPoint(x: center.x + 6, y: center.y + 3))
    folder.line(to: NSPoint(x: center.x + 6, y: center.y - 5.5))
    folder.close()
    folder.lineJoinStyle = .round
    folder.lineWidth = 1.4
    folder.stroke()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: center.x - 3.8, y: center.y - 1.4))
    arrow.line(to: NSPoint(x: center.x + 2.2, y: center.y - 1.4))
    arrow.move(to: NSPoint(x: center.x - 0.1, y: center.y + 0.9))
    arrow.line(to: NSPoint(x: center.x + 2.4, y: center.y - 1.4))
    arrow.line(to: NSPoint(x: center.x - 0.1, y: center.y - 3.7))
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.lineWidth = 1.5
    arrow.stroke()
}

// MARK: Demo

func lerp(_ a: NSPoint, _ b: NSPoint, _ t: CGFloat) -> NSPoint {
    let e = t * t * (3 - 2 * t)
    return NSPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
}

var frames: [(NSBitmapImageRep, Double)] = []
func frame(_ m: Moment, hold: Double = 0.07) {
    // Drawn at 2x so the GIF looks sharp on Retina screens when shown at 720 points.
    let rep = bitmap(Int(width * 2), Int(height * 2)) {
        let transform = NSAffineTransform()
        transform.scale(by: 2)
        transform.concat()
        scene(m)
    }
    frames.append((rep, hold))
}

func move(_ m: inout Moment, to point: NSPoint, steps: Int) {
    let from = m.cursorAt
    for step in 1...steps {
        m.cursorAt = lerp(from, point, CGFloat(step) / CGFloat(steps))
        frame(m, hold: 0.04)
    }
}

var m = Moment()
m.cursorAt = NSPoint(x: 330, y: 230)
frame(m, hold: 1.0)
// ⌘S: the Save sheet opens in Documents, as usual.
m.keycap = "⌘S"
frame(m, hold: 0.5)
for step in 1...6 {
    m.sheet = CGFloat(step) / 6
    frame(m, hold: 0.04)
}
m.keycap = nil
// Right Folder's panel shows up beside it.
for alpha in stride(from: 0.25, through: 1, by: 0.25) {
    m.panelAlpha = CGFloat(alpha)
    frame(m, hold: 0.05)
}
frame(m, hold: 1.4)
// ⌃⌥J goes to the folder open in Finder.
m.keycap = "⌃⌥J"
frame(m, hold: 0.45)
m.folder = "Drafts"
frame(m, hold: 1.3)
m.keycap = nil
frame(m, hold: 0.3)
// Or click a favorite.
move(&m, to: NSPoint(x: panelRect.minX + 70, y: rowTop(2) - 12), steps: 12)
m.hovering = 2
frame(m, hold: 0.5)
m.pressed = true
frame(m, hold: 0.1)
m.pressed = false
m.folder = "Lab Notes"
frame(m, hold: 0.25)
m.hovering = nil
frame(m, hold: 1.2)
// Save, and it's in Lab Notes.
move(&m, to: NSPoint(x: saveButton.midX, y: saveButton.midY + 4), steps: 12)
m.saveHover = true
frame(m, hold: 0.4)
m.pressed = true
frame(m, hold: 0.12)
m.pressed = false
m.saveHover = false
for step in stride(from: 5, through: 0, by: -1) {
    m.sheet = CGFloat(step) / 6
    m.panelAlpha = CGFloat(step) / 6
    frame(m, hold: 0.04)
}
m.saved = true
frame(m, hold: 3.2)

let gifURL = URL(fileURLWithPath: "docs/demo.gif")
let destination = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (rep, hold) in frames {
    CGImageDestinationAddImage(destination, rep.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: hold]] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't write the GIF") }

// One frame on its own, for checking the art without playing the GIF.
if let preview = ProcessInfo.processInfo.environment["PREVIEW"] {
    let index = Int(ProcessInfo.processInfo.environment["PREVIEW_FRAME"] ?? "") ?? frames.count - 1
    try frames[min(index, frames.count - 1)].0.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: preview))
}

// MARK: Link preview

let social = bitmap(1280, 640) {
    let rect = NSRect(x: 0, y: 0, width: 1280, height: 640)
    wallpaper(rect)
    if let icon = NSImage(contentsOfFile: "docs/icon.png") {
        icon.draw(in: NSRect(x: 640 - 80, y: 380, width: 160, height: 160))
    }
    text("Right Folder", at: NSPoint(x: 640, y: 270), size: 84, weight: .semibold, centered: true)
    text("Open and Save dialogs, in the right folder.", at: NSPoint(x: 640, y: 205), size: 30, color: .white.withAlphaComponent(0.75), centered: true)
    text("free · open source · one click or ⌃⌥J · no internet access", at: NSPoint(x: 640, y: 120), size: 22, weight: .medium, color: .white.withAlphaComponent(0.5), centered: true)
}
try social.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/social.png"))
print("Wrote docs/demo.gif and docs/social.png")
