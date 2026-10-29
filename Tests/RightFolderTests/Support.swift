import AppKit
import Foundation
@testable import FolderCore
@testable import RightFolder

/// Settings in a suite of their own, so tests never touch the app's real ones.
func testPreferences() -> Preferences {
    let name = "RightFolderTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return Preferences(defaults: defaults)
}

@MainActor
final class FakeFinder: FinderSource {
    var open: [String]
    init(_ open: [String] = []) { self.open = open }
    func folders() -> [String] { open }
}

struct FakeChecker: FolderChecking {
    var folders: Set<String>
    func isFolder(_ path: String) -> Bool { folders.contains(path) }
}

/// A made-up Mac's folders and volumes. Bookmarks are just the path's bytes, and `moved` says
/// where a bookmark's folder went.
@MainActor
final class FakeSystem: FolderSystem {
    var folders: Set<String>
    var mounts: [Mount]
    var home: String
    var moved: [String: String] = [:]

    init(home: String = Gallery.home, folders: Set<String> = Gallery.folders, mounts: [Mount] = Gallery.mounts) {
        self.home = home
        self.folders = folders
        self.mounts = mounts
    }

    var checker: any FolderChecking { FakeChecker(folders: folders) }
    func context() -> PathContext { PathContext(home: home, mounts: mounts) }
    func bookmark(for path: String) -> Data? { Data(path.utf8) }
    func resolve(_ favorite: Favorite) -> (path: String, bookmark: Data?)? {
        guard let bookmark = favorite.bookmark, let original = String(data: bookmark, encoding: .utf8) else { return nil }
        guard let now = moved[original] else { return nil }
        return (now, Data(now.utf8))
    }
}

/// Records jumps instead of making them. Nothing real is ever sent a key in a test.
@MainActor
final class RecordedJumps {
    var paths: [String] = []
    var result: JumpResult = .done
    /// How long each jump takes, for testing what happens meanwhile.
    var delay: TimeInterval = 0

    func jump(_ path: String) async -> JumpResult {
        paths.append(path)
        if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
        return result
    }
}

/// A made-up Mac for the tests and the README screenshots: a student's thesis and lab folders, an
/// iCloud reading folder, a field drive and a lab server share, and a writing app called Inkpad.
/// Every name here is invented.
enum Gallery {
    static let home = "/Users/robin"
    static let iCloud = home + "/Library/Mobile Documents/com~apple~CloudDocs"

    static let mounts = [
        Mount(path: "/", name: "Macintosh HD", isLocal: true),
        Mount(path: "/Volumes/Field Drive", name: "Field Drive", isLocal: true),
        Mount(path: "/Volumes/lab-share", name: "lab-share", isLocal: false),
    ]

    static let folders: Set<String> = [
        home, home + "/Desktop", home + "/Documents", home + "/Downloads",
        home + "/Documents/Thesis", home + "/Documents/Thesis/Figures", home + "/Documents/Thesis/Drafts",
        home + "/Documents/Lab Notes", iCloud, iCloud + "/Reading",
        "/Volumes/Field Drive", "/Volumes/Field Drive/2026 Survey",
    ]

    static let finder = [home + "/Documents/Thesis/Drafts", home + "/Downloads"]
    static let favorites = [home + "/Documents/Lab Notes", iCloud + "/Reading", "/Volumes/Field Drive/2026 Survey", "/Volumes/lab-share/imaging"]
    static let recents = [home + "/Documents/Thesis/Figures", home + "/Desktop"]

    static let inkpad = FolderModel.Dialog(kind: .save, appName: "Inkpad", bundleID: "com.example.inkpad")

    @MainActor
    static func model(
        trusted: Bool = true, finder: [String] = finder, favorites: [String] = favorites, recents: [String] = recents,
        dialog: FolderModel.Dialog? = inkpad, system: FakeSystem = FakeSystem(), preferences: Preferences = testPreferences(),
        jumps: RecordedJumps = RecordedJumps()
    ) -> FolderModel {
        var stored = Favorites()
        for path in favorites { stored.add(Favorite(path: path, bookmark: Data(path.utf8))) }
        preferences.favorites = stored
        preferences.recents = RecentFolders(paths: recents)
        let model = FolderModel(preferences: preferences, finder: FakeFinder(finder), system: system, isTrusted: { trusted })
        model.jumper = { await jumps.jump($0) }
        if let dialog { model.dialogOpened(dialog) }
        return model
    }
}
