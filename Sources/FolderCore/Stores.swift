import Foundation

/// Folders you've used lately, newest first: ones you jumped to, and ones that were open in Finder
/// while a dialog was up, so a folder is still offered after its Finder window is closed.
public struct RecentFolders: Codable, Equatable, Sendable {
    public static let limit = 12

    public private(set) var paths: [String]

    public init(paths: [String] = []) {
        self.paths = []
        for path in paths.reversed() { add(path) }
    }

    /// Puts a folder first, once. A path that can't be used is ignored.
    public mutating func add(_ raw: String) {
        guard let path = Paths.normalize(raw) else { return }
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        if paths.count > Self.limit { paths.removeLast(paths.count - Self.limit) }
    }

    public mutating func remove(_ path: String) {
        paths.removeAll { $0 == path }
    }

    public mutating func clear() {
        paths = []
    }

    // Saved settings are read as untrusted: anything that isn't a usable path is dropped.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(paths: (try? container.decode([String].self, forKey: .paths)) ?? [])
    }
}

/// A folder you pinned. The bookmark finds it again if it's renamed or moved.
public struct Favorite: Codable, Equatable, Sendable, Identifiable {
    public var path: String
    public var bookmark: Data?
    public var id: String { path }

    public init(path: String, bookmark: Data? = nil) {
        self.path = path
        self.bookmark = bookmark
    }
}

/// Your pinned folders, in the order you put them.
public struct Favorites: Codable, Equatable, Sendable {
    public static let limit = 30

    public private(set) var items: [Favorite]

    public init(items: [Favorite] = []) {
        self.items = []
        for item in items { add(item) }
    }

    public var paths: [String] { items.map(\.path) }

    public func contains(_ path: String) -> Bool {
        items.contains { $0.path == path }
    }

    /// Pins a folder at the end. Returns false if it can't be used, is already pinned, or there are
    /// too many.
    @discardableResult
    public mutating func add(_ favorite: Favorite) -> Bool {
        guard let path = Paths.normalize(favorite.path), !contains(path), items.count < Self.limit else { return false }
        items.append(Favorite(path: path, bookmark: favorite.bookmark))
        return true
    }

    public mutating func remove(_ path: String) {
        items.removeAll { $0.path == path }
    }

    /// Moves a favorite up or down the list.
    public mutating func move(_ path: String, by offset: Int) {
        guard let index = items.firstIndex(where: { $0.path == path }) else { return }
        let target = min(max(index + offset, 0), items.count - 1)
        guard target != index else { return }
        let item = items.remove(at: index)
        items.insert(item, at: target)
    }

    /// Follows favorites that moved: `resolve` gives each bookmark's folder now, and the new path
    /// replaces the old one. Returns whether anything changed. A move onto a folder that's already
    /// a favorite drops the duplicate.
    @discardableResult
    public mutating func follow(_ resolve: (Favorite) -> (path: String, bookmark: Data?)?) -> Bool {
        var changed = false
        var seen = Set<String>()
        var updated: [Favorite] = []
        for item in items {
            var item = item
            if let found = resolve(item), let path = Paths.normalize(found.path) {
                if path != item.path || (found.bookmark != nil && found.bookmark != item.bookmark) {
                    item = Favorite(path: path, bookmark: found.bookmark ?? item.bookmark)
                    changed = true
                }
            }
            if seen.insert(item.path).inserted {
                updated.append(item)
            } else {
                changed = true
            }
        }
        items = updated
        return changed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let items = (try? container.decode([Lenient].self, forKey: .items)) ?? []
        self.init(items: items.compactMap(\.favorite))
    }

    /// One saved favorite, or nothing if it's damaged, so one bad entry doesn't lose the rest.
    private struct Lenient: Decodable {
        var favorite: Favorite?
        init(from decoder: Decoder) throws {
            favorite = try? Favorite(from: decoder)
        }
    }
}
