import Foundation

/// The app's words, kept here so they're tested.
public enum Describe {
    public static let version = "0.1.0"

    /// The shortcut that steps through the folders while a dialog is open. Shift goes back.
    public static let shortcut = "⌃⌥J"
    public static let backShortcut = "⌃⌥⇧J"

    public enum Status: Equatable, Sendable {
        case needsAccessibility
        case paused
        case waiting
        case showing(DialogKind, app: String)
        case offInApp(String)
    }

    /// The first line of the menu.
    public static func headline(_ status: Status) -> String {
        switch status {
        case .needsAccessibility: "Accessibility is off"
        case .paused: "Paused"
        case .waiting: "Waiting for an Open or Save dialog"
        case let .showing(kind, app): "\(kind == .open ? "Open" : "Save") dialog in \(safe(app, limit: 40))"
        case let .offInApp(app): "Off in \(safe(app, limit: 40))"
        }
    }

    /// The line under it, saying what to do.
    public static func detail(_ status: Status) -> String {
        switch status {
        case .needsAccessibility: "Allow it in Privacy & Security to move dialogs."
        case .paused: "Turn it back on to see folders beside dialogs."
        case .waiting: "Folders show up beside it. Press \(shortcut) to step through them."
        case .showing: "Click a folder, or press \(shortcut) to step through them."
        case .offInApp: "You turned Right Folder off for this app."
        }
    }

    public static func availability(_ availability: Availability) -> String? {
        switch availability {
        case .ready: nil
        case .network: "On a network volume"
        case .disconnected: "Not connected"
        case .missing: "Not found"
        case .offLimits: "Can't open here"
        }
    }

    /// The panel's section titles.
    public static func section(_ source: FolderEntry.Source) -> String {
        switch source {
        case .finder: "Open in Finder"
        case .favorite: "Favorites"
        case .recent: "Recent"
        }
    }

    /// Text from outside, like an app or folder name, made safe to show: no control characters or
    /// invisible direction marks, and no longer than `limit`.
    public static func safe(_ text: String, limit: Int = 80) -> String {
        let hidden: Set<Unicode.Scalar> = ["\u{200E}", "\u{200F}", "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}", "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}", "\u{FEFF}"]
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if hidden.contains(scalar) { continue }
            scalars.append(scalar.properties.generalCategory == .control ? " " : scalar)
        }
        let clean = String(scalars).trimmingCharacters(in: .whitespaces)
        guard clean.count > limit else { return clean }
        return String(clean.prefix(limit - 1)) + "…"
    }
}
