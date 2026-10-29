import Foundation
import FolderCore

/// Settings, kept in the app's own preferences file. Favorites and recent folders are stored as
/// paths, plus a bookmark per favorite to find it again if it moves. Nothing else about your files.
struct Preferences {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let launchedBefore = "launchedBefore"
        static let paused = "paused"
        static let remembersRecents = "remembersRecents"
        static let excludedApps = "excludedApps"
        static let typesPaths = "typesPaths"
        static let favorites = "favorites"
        static let recents = "recents"
    }

    var launchedBefore: Bool {
        get { defaults.bool(forKey: Key.launchedBefore) }
        nonmutating set { defaults.set(newValue, forKey: Key.launchedBefore) }
    }

    /// Off: no panel beside dialogs and no shortcut, until you turn it back on.
    var paused: Bool {
        get { defaults.bool(forKey: Key.paused) }
        nonmutating set { defaults.set(newValue, forKey: Key.paused) }
    }

    /// On unless you turn it off.
    var remembersRecents: Bool {
        get { defaults.object(forKey: Key.remembersRecents) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.remembersRecents) }
    }

    /// Apps you've turned Right Folder off for, by bundle ID.
    var excludedApps: Set<String> {
        get { Set((defaults.array(forKey: Key.excludedApps) as? [String]) ?? []) }
        nonmutating set { defaults.set(newValue.sorted(), forKey: Key.excludedApps) }
    }

    /// Types each path into Go to Folder instead of setting it in the field, for dialogs that only
    /// notice typed text. Off unless set with `defaults write com.stanczykwyatt.RightFolder typesPaths -bool true`.
    var typesPaths: Bool {
        get { defaults.bool(forKey: Key.typesPaths) }
        nonmutating set { defaults.set(newValue, forKey: Key.typesPaths) }
    }

    var favorites: Favorites {
        get { decode(Favorites.self, Key.favorites) ?? Favorites() }
        nonmutating set { encode(newValue, Key.favorites) }
    }

    var recents: RecentFolders {
        get { decode(RecentFolders.self, Key.recents) ?? RecentFolders() }
        nonmutating set { encode(newValue, Key.recents) }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
