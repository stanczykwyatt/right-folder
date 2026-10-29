import AppKit

/// The menu bar icon: a folder with an arrow going into it, with a dot when Accessibility is off.
enum StatusIcon {
    static func image(alert: Bool, paused: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.withAlphaComponent(paused ? 0.45 : 1).set()
            let shift: CGFloat = alert ? -1.2 : 0
            // The folder: a tab on the back, then the front.
            let folder = NSBezierPath()
            folder.move(to: NSPoint(x: 2 + shift, y: 3.5))
            folder.line(to: NSPoint(x: 2 + shift, y: 13.5))
            folder.line(to: NSPoint(x: 6.6 + shift, y: 13.5))
            folder.line(to: NSPoint(x: 8.1 + shift, y: 12))
            folder.line(to: NSPoint(x: 15 + shift, y: 12))
            folder.line(to: NSPoint(x: 15 + shift, y: 3.5))
            folder.close()
            folder.lineJoinStyle = .round
            folder.lineWidth = 1.4
            folder.stroke()
            // The arrow, pointing in.
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 5.2 + shift, y: 7.6))
            arrow.line(to: NSPoint(x: 11.2 + shift, y: 7.6))
            arrow.move(to: NSPoint(x: 8.9 + shift, y: 9.9))
            arrow.line(to: NSPoint(x: 11.4 + shift, y: 7.6))
            arrow.line(to: NSPoint(x: 8.9 + shift, y: 5.3))
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            arrow.lineWidth = 1.5
            arrow.stroke()
            if alert {
                NSBezierPath(ovalIn: NSRect(x: rect.maxX - 5, y: rect.maxY - 5.5, width: 5, height: 5)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = alert ? "Right Folder, needs Accessibility" : (paused ? "Right Folder, paused" : "Right Folder")
        return image
    }
}
