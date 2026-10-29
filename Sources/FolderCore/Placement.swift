import CoreGraphics

/// Where the panel sits: beside the dialog, on the same screen, never off it.
///
/// Accessibility reports frames with the origin at the top left of the main display and y going
/// down, so everything here uses those coordinates. `flip` converts to and from AppKit's, which
/// start at the bottom left.
public enum Placement {
    public static let gap: CGFloat = 8

    /// The panel's frame beside `dialog`: to its right, top edges lined up, or to its left if
    /// there's no room, or over the dialog's right edge if there's no room on either side.
    public static func frame(beside dialog: CGRect, size: CGSize, screens: [CGRect]) -> CGRect {
        let screen = Self.screen(for: dialog, in: screens)
        let height = min(size.height, screen.height)
        let width = min(size.width, screen.width)

        var x: CGFloat
        if dialog.maxX + gap + width <= screen.maxX {
            x = dialog.maxX + gap
        } else if dialog.minX - gap - width >= screen.minX {
            x = dialog.minX - gap - width
        } else {
            // A dialog as wide as the screen: sit inside its right edge.
            x = min(dialog.maxX, screen.maxX) - gap - width
        }
        x = min(max(x, screen.minX), screen.maxX - width)

        // A sheet's top is under its window's title bar, which is where the panel lines up.
        var y = dialog.minY
        y = min(max(y, screen.minY), screen.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// The screen showing most of the dialog, or the main one if it's on none of them.
    public static func screen(for dialog: CGRect, in screens: [CGRect]) -> CGRect {
        let best = screens.max { area($0.intersection(dialog)) < area($1.intersection(dialog)) }
        if let best, area(best.intersection(dialog)) > 0 { return best }
        return screens.first ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    /// Converts a frame between Accessibility's coordinates and AppKit's. The same sum works both
    /// ways, given the main display's height.
    public static func flip(_ rect: CGRect, mainHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
