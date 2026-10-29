import Foundation

/// Folder paths: cleaning up what Finder and the folder picker report, and keeping out anything a
/// dialog can't be sent to.
public enum Paths {
    /// The longest path it will offer. macOS's own limit is 1024 bytes.
    public static let maxLength = 1024

    /// An absolute path with its `.` and `..` parts worked out and no doubled or trailing slashes,
    /// or nil if it can't be used: relative, empty, too long, or holding a character a dialog's
    /// Go to Folder field can't take, like a line break.
    public static func normalize(_ raw: String) -> String? {
        guard raw.hasPrefix("/"), raw.utf8.count <= maxLength else { return nil }
        guard !raw.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else { return nil }
        var parts: [Substring] = []
        for part in raw.split(separator: "/", omittingEmptySubsequences: true) {
            switch part {
            case ".": continue
            case "..": if !parts.isEmpty { parts.removeLast() }
            default: parts.append(part)
            }
        }
        var path = "/" + parts.joined(separator: "/")
        // The Data volume's firmlinks name the same folders as the usual paths, so use the usual ones.
        let data = "/System/Volumes/Data"
        if path.hasPrefix(data + "/") {
            let rest = String(path.dropFirst(data.count))
            let first = rest.split(separator: "/").first.map(String.init) ?? ""
            if firmlinked.contains(first) { path = rest }
        }
        return path
    }

    /// Top-level folders that are firmlinks to the same folder on the Data volume.
    static let firmlinked: Set<String> = ["Users", "Applications", "Library", "Volumes", "private", "opt", "cores"]

    /// The folder a `file://` URL names, as Finder reports a window's folder, or nil for anything
    /// that isn't a local file URL.
    public static func fromFileURL(_ string: String) -> String? {
        guard let url = URL(string: string), url.scheme?.lowercased() == "file" else { return nil }
        if let host = url.host, !host.isEmpty, host.lowercased() != "localhost" { return nil }
        let path = url.path(percentEncoded: false)
        guard !path.isEmpty else { return nil }
        return normalize(path)
    }

    /// The path with your home folder shortened to `~`, the way Finder's Go to Folder shows it.
    public static func abbreviate(_ path: String, home: String) -> String {
        guard home != "/" else { return path }
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    /// Where a symbolic link at `link` points, from what the link says: a full path, or one
    /// relative to the folder the link is in.
    public static func linkTarget(_ destination: String, of link: String) -> String? {
        if destination.hasPrefix("/") { return normalize(destination) }
        let parent = (link as NSString).deletingLastPathComponent
        return normalize(parent + "/" + destination)
    }

    /// Folders macOS mounts servers into on demand. Looking inside one can wait on the network.
    public static func isAutomount(_ path: String) -> Bool {
        isInside(path, "/net") || isInside(path, "/Network") || isInside(path, "/System/Volumes/Data/net")
    }

    /// Whether `path` is `folder` or inside it.
    public static func isInside(_ path: String, _ folder: String) -> Bool {
        folder == "/" || path == folder || path.hasPrefix(folder + "/")
    }

    /// Whether a path is somewhere a dialog shouldn't be sent: a Trash folder, or inside an app or
    /// other package, which dialogs show as a single file.
    public static func isOffLimits(_ path: String, home: String) -> Bool {
        let parts = path.split(separator: "/")
        if isInside(path, home + "/.Trash") { return true }
        if parts.contains(where: { $0 == ".Trashes" }) { return true }
        // Only what's inside a package is off limits. The package itself can be picked in a dialog.
        return parts.dropLast().contains { part in
            packageExtensions.contains((part as NSString).pathExtension.lowercased())
        }
    }

    static let packageExtensions: Set<String> = ["app", "bundle", "framework", "photoslibrary", "musiclibrary", "tvlibrary", "plugin", "kext", "pkg", "rtfd", "xcodeproj", "xcworkspace", "playground", "sparsebundle", "photolibrary"]
}

/// A mounted volume, as the kernel's mount table lists it.
public struct Mount: Equatable, Hashable, Sendable {
    public var path: String
    public var name: String
    public var isLocal: Bool

    public init(path: String, name: String, isLocal: Bool) {
        self.path = path
        self.name = name
        self.isLocal = isLocal
    }

    /// The volume a path is on: the mount with the longest path containing it.
    public static func of(_ path: String, in mounts: [Mount]) -> Mount? {
        mounts.filter { Paths.isInside(path, $0.path) }.max { $0.path.count < $1.path.count }
    }
}

/// Where a folder is, in words, for its row in the panel.
public struct FolderInfo: Equatable, Sendable {
    public enum Place: Equatable, Sendable {
        case home
        case desktop
        case documents
        case downloads
        case iCloud
        case volume
        case network
        case folder
    }

    /// The folder's name, like "Projects", "iCloud Drive" or "Macintosh HD".
    public var name: String
    /// Where it is, like "~/Documents" or "iCloud Drive › Pages", without the name.
    public var location: String
    public var place: Place

    public init(name: String, location: String, place: Place) {
        self.name = name
        self.location = location
        self.place = place
    }
}

/// Everything about this Mac that naming a folder depends on.
public struct PathContext: Equatable, Sendable {
    public var home: String
    public var mounts: [Mount]
    /// The name of the startup disk, like "Macintosh HD".
    public var bootName: String

    public init(home: String, mounts: [Mount], bootName: String = "Macintosh HD") {
        self.home = home
        self.mounts = mounts
        self.bootName = bootName
    }

    var iCloudRoot: String { home + "/Library/Mobile Documents" }
    var iCloudDrive: String { iCloudRoot + "/com~apple~CloudDocs" }

    /// The volume a path is on, unless it's the startup disk.
    public func volume(of path: String) -> Mount? {
        guard let mount = Mount.of(path, in: mounts), mount.path != "/" else { return nil }
        return mount
    }

    /// A folder's name and where it is.
    public func describe(_ path: String) -> FolderInfo {
        let name = (path as NSString).lastPathComponent
        let parent = (path as NSString).deletingLastPathComponent

        if path == "/" { return FolderInfo(name: bootName, location: "Startup disk", place: .volume) }
        if path == home { return FolderInfo(name: name, location: "Home", place: .home) }
        for (folder, place) in [("Desktop", FolderInfo.Place.desktop), ("Documents", .documents), ("Downloads", .downloads)] where path == home + "/" + folder {
            return FolderInfo(name: name, location: "~", place: place)
        }

        // iCloud Drive, and the folders apps keep in it.
        if path == iCloudDrive { return FolderInfo(name: "iCloud Drive", location: "iCloud", place: .iCloud) }
        if Paths.isInside(path, iCloudDrive) {
            return FolderInfo(name: name, location: iCloudLocation(parent), place: .iCloud)
        }
        if Paths.isInside(path, iCloudRoot), path != iCloudRoot {
            let container = path.dropFirst(iCloudRoot.count + 1).split(separator: "/").first.map(String.init) ?? ""
            let app = Self.appName(container: container)
            // An app's folder shows in Finder by the app's name, and its Documents folder is that folder.
            let containerPath = iCloudRoot + "/" + container
            if path == containerPath || path == containerPath + "/Documents" {
                return FolderInfo(name: app, location: "iCloud Drive", place: .iCloud)
            }
            return FolderInfo(name: name, location: iCloudLocation(parent), place: .iCloud)
        }

        if let volume = volume(of: path) {
            let place: FolderInfo.Place = volume.isLocal ? .volume : .network
            if path == volume.path { return FolderInfo(name: volume.name, location: volume.isLocal ? "Disk" : "Network", place: place) }
            let inside = parent == volume.path ? "" : String(parent.dropFirst(volume.path.count))
            return FolderInfo(name: name, location: volume.name + inside.replacingOccurrences(of: "/", with: " › "), place: volume.isLocal ? .folder : .network)
        }
        return FolderInfo(name: name, location: Paths.abbreviate(parent, home: home), place: .folder)
    }

    /// Where something in iCloud is, the way Finder's path bar names it.
    private func iCloudLocation(_ folder: String) -> String {
        if folder == iCloudDrive { return "iCloud Drive" }
        if Paths.isInside(folder, iCloudDrive) {
            return "iCloud Drive" + folder.dropFirst(iCloudDrive.count).replacingOccurrences(of: "/", with: " › ")
        }
        let rest = folder.dropFirst(iCloudRoot.count + 1).split(separator: "/").map(String.init)
        guard let container = rest.first else { return "iCloud Drive" }
        var parts = ["iCloud Drive", Self.appName(container: container)]
        // The Documents folder is hidden in Finder, since it's the app's folder itself.
        parts += rest.dropFirst().enumerated().filter { !($0.offset == 0 && $0.element == "Documents") }.map(\.element)
        return parts.joined(separator: " › ")
    }

    /// The app an iCloud container belongs to: the last part of its name, like "Pages" for
    /// "com~apple~Pages" or "Notebook" for "iCloud~com~example~Notebook".
    static func appName(container: String) -> String {
        let last = container.split(separator: "~").last.map(String.init) ?? container
        return last.isEmpty ? container : last
    }
}
