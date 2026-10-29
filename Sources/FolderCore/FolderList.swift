import Foundation

/// Whether a dialog can be sent to a folder right now.
public enum Availability: Equatable, Sendable {
    case ready
    /// On a network volume. Never checked, since looking at a server that stopped answering can
    /// hang, so it's offered as long as the volume is mounted.
    case network
    /// Its volume isn't mounted, like a drive that's unplugged or a server you're not connected to.
    case disconnected
    /// Nothing is there, or it isn't a folder.
    case missing
    /// In the Trash, or inside an app or other package.
    case offLimits

    public var canJump: Bool { self == .ready || self == .network }
}

/// Looking at folders: whether one exists, without ever reading what's in it. A folder reached
/// through a link to a network volume counts as there, without looking.
public protocol FolderChecking: Sendable {
    func isFolder(_ path: String) -> Bool
}

public struct FolderEntry: Equatable, Sendable, Identifiable {
    public enum Source: Equatable, Sendable {
        case finder
        case favorite
        case recent
    }

    public var path: String
    public var source: Source
    public var info: FolderInfo
    public var availability: Availability
    /// A favorite that's also open in a Finder window right now.
    public var isOpenInFinder: Bool

    public var id: String { path }
}

/// What the panel lists: folders open in Finder, then your favorites, then recent folders. Each
/// folder shows once. A favorite stays with your favorites even while it's open in Finder.
public struct FolderList: Equatable, Sendable {
    public static let finderLimit = 8
    public static let recentLimit = 8

    public var finder: [FolderEntry]
    public var favorites: [FolderEntry]
    public var recents: [FolderEntry]

    public init(finder: [FolderEntry] = [], favorites: [FolderEntry] = [], recents: [FolderEntry] = []) {
        self.finder = finder
        self.favorites = favorites
        self.recents = recents
    }

    public var isEmpty: Bool { finder.isEmpty && favorites.isEmpty && recents.isEmpty }

    /// Everything, top to bottom.
    public var all: [FolderEntry] { finder + favorites + recents }

    /// The folders the shortcut steps through, in the order they're listed. Ones it can't go to
    /// are skipped.
    public var cycle: [String] { all.filter(\.availability.canJump).map(\.path) }

    public func entry(_ path: String) -> FolderEntry? {
        all.first { $0.path == path }
    }

    public static func build(
        finder: [String], favorites: [String], recents: [String], context: PathContext, checker: any FolderChecking
    ) -> FolderList {
        var seen = Set<String>()
        let favoritePaths = favorites.compactMap(Paths.normalize)
        let finderPaths = finder.compactMap(Paths.normalize)
        let open = Set(finderPaths)

        func entries(_ paths: [String], _ source: FolderEntry.Source, limit: Int, keepMissing: Bool, skip: Set<String> = []) -> [FolderEntry] {
            var result: [FolderEntry] = []
            for path in paths where result.count < limit && !skip.contains(path) && seen.insert(path).inserted {
                let availability = availability(of: path, context: context, checker: checker)
                // A favorite stays listed, greyed out, until you remove it. Anything else that's gone is left out.
                guard keepMissing || availability.canJump else { continue }
                result.append(FolderEntry(
                    path: path, source: source, info: context.describe(path), availability: availability,
                    isOpenInFinder: source == .favorite && open.contains(path)
                ))
            }
            return result
        }

        let finderEntries = entries(finderPaths, .finder, limit: finderLimit, keepMissing: false, skip: Set(favoritePaths))
        let favoriteEntries = entries(favoritePaths, .favorite, limit: Favorites.limit, keepMissing: true)
        let recentEntries = entries(recents.compactMap(Paths.normalize), .recent, limit: recentLimit, keepMissing: false)
        return FolderList(finder: finderEntries, favorites: favoriteEntries, recents: recentEntries)
    }

    /// Whether a dialog can go to a folder, checking a local disk but never a network one.
    public static func availability(of path: String, context: PathContext, checker: any FolderChecking) -> Availability {
        if Paths.isOffLimits(path, home: context.home) { return .offLimits }
        if Paths.isAutomount(path) { return .network }
        let mount = Mount.of(path, in: context.mounts)
        // Something under /Volumes with nothing mounted there is a disk or server that isn't connected.
        if path.hasPrefix("/Volumes/"), mount == nil || mount?.path == "/" {
            return .disconnected
        }
        if let mount, !mount.isLocal { return .network }
        return checker.isFolder(path) ? .ready : .missing
    }
}

/// Stepping through the folders with the shortcut: each press goes to the next one, and it starts
/// over at the top when a new dialog opens.
public struct Cycler: Equatable, Sendable {
    public private(set) var current: String?

    public init(current: String? = nil) {
        self.current = current
    }

    /// The folder after the one it last went to, or the first. Holding Shift goes back.
    public mutating func next(in folders: [String], backwards: Bool = false) -> String? {
        guard !folders.isEmpty else { return nil }
        let target: String
        if let current, let index = folders.firstIndex(of: current) {
            let step = backwards ? -1 : 1
            target = folders[(index + step + folders.count) % folders.count]
        } else {
            target = backwards ? folders[folders.count - 1] : folders[0]
        }
        current = target
        return target
    }

    /// Remembers a folder picked by clicking, so the shortcut carries on from there.
    public mutating func picked(_ path: String) {
        current = path
    }

    public mutating func reset() {
        current = nil
    }
}
