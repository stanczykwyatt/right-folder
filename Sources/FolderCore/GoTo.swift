import Foundation

/// How a dialog is sent to a folder: the same way you'd do it by hand. Press ⇧⌘G for the dialog's
/// Go to Folder field, put the path in it, and press Return. The keys go only to the app showing
/// the dialog, and the path is set in the field directly rather than typed.
public enum GoTo {
    /// What goes in the Go to Folder field: the full path, ending in a slash so the dialog opens
    /// the folder rather than selecting it.
    public static func text(for path: String) -> String {
        path == "/" ? "/" : path + "/"
    }

    /// Whether the field now holding the keyboard is the Go to Folder field: a text field that
    /// wasn't focused before ⇧⌘G. A search field never is, and in a Save dialog the name field is
    /// already focused before, so it's ruled out by being the same field.
    public static func isGoToField(role: String?, subrole: String?, wasFocusedBefore: Bool) -> Bool {
        guard !wasFocusedBefore, let role else { return false }
        guard ["AXTextField", "AXComboBox"].contains(role) else { return false }
        return subrole != "AXSearchField" && subrole != "AXSecureTextField"
    }

    /// Whether the field took the path as it was set. Some fields tidy what's put in them, so a
    /// missing trailing slash or a `~` in place of the home folder still counts.
    public static func fieldHolds(_ value: String?, path: String, home: String) -> Bool {
        guard let value else { return false }
        let want = Paths.normalize(path)
        if let got = Paths.normalize(value), got == want { return true }
        if value.hasPrefix("~") {
            return Paths.normalize(home + value.dropFirst()) == want
        }
        return false
    }

    /// Text in pieces of up to `size` UTF-16 units for typing, each piece only whole characters,
    /// so an emoji or accented letter is never split across two key events.
    public static func chunks(_ text: String, size: Int = 16) -> [String] {
        var pieces: [String] = []
        var piece = ""
        for character in text {
            if !piece.isEmpty, piece.utf16.count + character.utf16.count > size {
                pieces.append(piece)
                piece = ""
            }
            piece.append(character)
        }
        if !piece.isEmpty { pieces.append(piece) }
        return pieces
    }

    /// How long to wait for the Go to Folder field to appear after ⇧⌘G, and how often to look.
    public static let fieldTimeout: TimeInterval = 1.5
    public static let pollInterval: TimeInterval = 0.05

    /// What can go wrong on the way, in words for the panel.
    public enum Failure: Error, Equatable, Sendable {
        /// The dialog closed, or another window came to the front, before it was done.
        case dialogGone
        /// The Go to Folder field never appeared.
        case noField
        /// Accessibility is off, so no keys can be sent.
        case notAllowed
        /// Go to Folder opened but didn't take the path.
        case pathRejected
        /// The folder isn't there any more.
        case unavailable

        public var message: String {
            switch self {
            case .dialogGone: "The dialog closed before it could get there."
            case .noField: "This dialog didn't open Go to Folder. Try pressing ⇧⌘G in it yourself."
            case .notAllowed: "Right Folder needs Accessibility to move the dialog."
            case .pathRejected: "Go to Folder didn't take the folder's path."
            case .unavailable: "That folder isn't available."
            }
        }
    }
}

/// Finding which key types a letter on the keyboard layout you use, since ⇧⌘G is the G key on
/// QWERTY but a different key on Dvorak.
public enum KeyLayout {
    /// The key codes of a US keyboard, used when the current layout has no key for a letter, like
    /// one that types another alphabet.
    public static let ansi: [Character: UInt16] = ["g": 5]

    /// The key that types `character` with no modifiers, from a table of what each key types. The
    /// lowest key code wins, since that's the main keyboard rather than a keypad.
    public static func keyCode(for character: Character, in table: [UInt16: String]) -> UInt16? {
        let wanted = String(character).lowercased()
        if let found = table.filter({ $0.value.lowercased() == wanted }).keys.min() {
            return found
        }
        return ansi[Character(wanted)]
    }

    public static let returnKey: UInt16 = 36
}
