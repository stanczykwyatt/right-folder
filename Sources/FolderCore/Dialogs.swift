import Foundation

/// What Accessibility says about one window or sheet: its role, subrole and identifier, and the
/// sheets attached to it. Only these three are ever read. Never a title, a value or any text.
public struct Element: Equatable, Hashable, Sendable, Codable {
    public var role: String?
    public var subrole: String?
    public var identifier: String?
    public var children: [Element]

    public init(role: String?, subrole: String? = nil, identifier: String? = nil, children: [Element] = []) {
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.children = children
    }
}

public enum DialogKind: String, Sendable, Codable, Equatable {
    case open
    case save
}

/// Where a dialog was found: its kind, and the child indexes leading from the window to it, so the
/// app can pick out the same element. Empty when the window is the dialog.
public struct DialogMatch: Equatable, Sendable {
    public var kind: DialogKind
    public var path: [Int]

    public init(kind: DialogKind, path: [Int]) {
        self.kind = kind
        self.path = path
    }
}

/// Telling an Open or Save dialog apart from every other window.
public enum Dialogs {
    /// AppKit names its Open and Save panels with these identifiers. Checked on macOS 15: an
    /// NSOpenPanel's `accessibilityIdentifier()` is "open-panel" and an NSSavePanel's "save-panel",
    /// while alerts, the color and font panels and plain panels have none.
    static let identifiers: [String: DialogKind] = ["open-panel": .open, "save-panel": .save]

    /// Subroles some apps' own file dialogs report. AppKit's don't, but they mean the same thing.
    static let subroles: [String: DialogKind] = ["AXOpenPanel": .open, "AXSavePanel": .save]

    /// A dialog is a window, or a sheet attached to one. An identifier on anything else, like a
    /// button or part of a web page, is ignored.
    static let roles: Set<String> = ["AXWindow", "AXSheet"]

    /// How deep to look for sheets: a dialog on a window, or on a sheet on a window.
    static let depth = 3

    /// The kind of dialog this window or sheet is, if it is one.
    public static func kind(of element: Element) -> DialogKind? {
        guard let role = element.role, roles.contains(role) else { return nil }
        if let identifier = element.identifier, let kind = identifiers[identifier] { return kind }
        if let subrole = element.subrole, let kind = subroles[subrole] { return kind }
        return nil
    }

    /// Finds the dialog in a focused window: the window itself, or a sheet on it. The deepest one
    /// wins, since a dialog opened from a sheet is the one in front.
    public static func find(in window: Element) -> DialogMatch? {
        func search(_ element: Element, path: [Int], level: Int) -> DialogMatch? {
            if level < depth {
                for (index, child) in element.children.enumerated() where child.role == "AXSheet" {
                    if let found = search(child, path: path + [index], level: level + 1) { return found }
                }
            }
            return kind(of: element).map { DialogMatch(kind: $0, path: path) }
        }
        return search(window, path: [], level: 0)
    }

    /// Whether to offer folders for a dialog in this app. Never for Right Folder's own dialogs,
    /// and never in apps you've turned it off for.
    public static func shouldOffer(appBundleID: String?, ownBundleID: String?, excluded: Set<String>) -> Bool {
        guard let appBundleID else { return true }
        if appBundleID == ownBundleID { return false }
        return !excluded.contains(appBundleID)
    }
}
