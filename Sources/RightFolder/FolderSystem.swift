import AppKit
import FolderCore

/// What Right Folder asks the file system: whether a folder exists, which volumes are mounted, and
/// where a favorite's bookmark points now. It never lists a folder or opens a file.
@MainActor
protocol FolderSystem {
    var checker: any FolderChecking { get }
    func context() -> PathContext
    func bookmark(for path: String) -> Data?
    func resolve(_ favorite: Favorite) -> (path: String, bookmark: Data?)?
}

struct LiveChecker: FolderChecking {
    var mounts: [Mount]

    /// Looks at the folder's own entry, the way a dialog would get there. Its contents are never
    /// read. Each part of the path is looked at without following links, and a link that leads
    /// onto a network volume, or one that isn't mounted, is taken as there without looking
    /// further, since a server that's stopped answering would make the look wait.
    func isFolder(_ path: String) -> Bool {
        var parts = path.split(separator: "/").map(String.init)
        var current = ""
        var links = 0
        while !parts.isEmpty {
            current += "/" + parts.removeFirst()
            var info = stat()
            guard lstat(current, &info) == 0 else { return false }
            guard info.st_mode & S_IFMT == S_IFLNK else { continue }
            links += 1
            guard links <= 16, let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: current),
                  let target = Paths.linkTarget(destination, of: current) else { return false }
            if isRemote(target) { return true }
            // Carry on from the link's target, with the rest of the path after it.
            parts = target.split(separator: "/").map(String.init) + parts
            current = ""
        }
        var info = stat()
        return lstat(current.isEmpty ? "/" : current, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR
    }

    private func isRemote(_ path: String) -> Bool {
        if Paths.isAutomount(path) { return true }
        let mount = Mount.of(path, in: mounts)
        if path.hasPrefix("/Volumes/"), mount == nil || mount?.path == "/" { return true }
        return mount.map { !$0.isLocal } ?? false
    }
}

struct LiveFolderSystem: FolderSystem {
    var checker: any FolderChecking { LiveChecker(mounts: Self.mounts()) }

    func context() -> PathContext {
        PathContext(home: NSHomeDirectory(), mounts: Self.mounts(), bootName: Self.bootName())
    }

    /// The mounted volumes, from the kernel's table without asking any of them to answer, so a
    /// server that's stopped responding can't hold this up.
    static func mounts() -> [Mount] {
        let count = getfsstat(nil, 0, MNT_NOWAIT)
        guard count > 0 else { return [] }
        let capacity = Int(count) + 4
        let stats = UnsafeMutablePointer<statfs>.allocate(capacity: capacity)
        defer { stats.deallocate() }
        let filled = getfsstat(stats, Int32(capacity * MemoryLayout<statfs>.stride), MNT_NOWAIT)
        guard filled > 0 else { return [] }
        return UnsafeBufferPointer(start: stats, count: Int(filled)).map { stat in
            var stat = stat
            let path = withUnsafeBytes(of: &stat.f_mntonname) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            let local = stat.f_flags & UInt32(MNT_LOCAL) != 0
            return Mount(path: path, name: (path as NSString).lastPathComponent, isLocal: local)
        }
    }

    static func bootName() -> String {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeNameKey])
        return values?.volumeName ?? "Macintosh HD"
    }

    /// A bookmark for a folder on a local disk. None for one on a network volume, since making it
    /// would ask the server.
    func bookmark(for path: String) -> Data? {
        guard isLocal(path, in: Self.mounts()) else { return nil }
        return try? URL(fileURLWithPath: path, isDirectory: true).bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    private func isLocal(_ path: String, in mounts: [Mount]) -> Bool {
        guard !Paths.isAutomount(path), let mount = Mount.of(path, in: mounts), mount.isLocal else { return false }
        return !(path.hasPrefix("/Volumes/") && mount.path == "/")
    }

    /// An app's name from its bundle ID, for the list of apps it's turned off in.
    static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    /// Where a favorite's bookmark points now. Only for folders on local disks: resolving one on a
    /// network volume could wait on the server, and one on a disk that isn't connected must not
    /// ask to mount it.
    func resolve(_ favorite: Favorite) -> (path: String, bookmark: Data?)? {
        guard let data = favorite.bookmark else { return nil }
        let context = context()
        guard isLocal(favorite.path, in: context.mounts) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        let path = url.path(percentEncoded: false)
        // A bookmark follows a deleted folder into the Trash. Keep the old path, so it shows as gone.
        guard !Paths.isOffLimits(path, home: context.home) else { return nil }
        return (path, stale ? bookmark(for: path) : nil)
    }
}
