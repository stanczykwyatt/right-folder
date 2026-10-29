import Foundation
import Testing
@testable import FolderCore
@testable import RightFolder

/// The real folder checks, on a throwaway folder of made-up folders and links.
@MainActor
@Suite("Folder checks")
struct FolderSystemTests {
    let root: String

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("RightFolderTests-\(UUID().uuidString)").path
        let files = FileManager.default
        try files.createDirectory(atPath: root + "/Thesis/Figures", withIntermediateDirectories: true)
        try Data().write(to: URL(fileURLWithPath: root + "/notes.md"))
        try files.createSymbolicLink(atPath: root + "/thesis-link", withDestinationPath: "Thesis")
        try files.createSymbolicLink(atPath: root + "/absolute-link", withDestinationPath: root + "/Thesis/Figures")
        try files.createSymbolicLink(atPath: root + "/file-link", withDestinationPath: "notes.md")
        try files.createSymbolicLink(atPath: root + "/dangling", withDestinationPath: "Nowhere")
        try files.createSymbolicLink(atPath: root + "/loop-a", withDestinationPath: "loop-b")
        try files.createSymbolicLink(atPath: root + "/loop-b", withDestinationPath: "loop-a")
        // Links onto a server: one into an automount folder, one onto a share that isn't mounted.
        try files.createSymbolicLink(atPath: root + "/lab-server", withDestinationPath: "/net/lab-server-that-does-not-exist/data")
        try files.createSymbolicLink(atPath: root + "/old-share", withDestinationPath: "/Volumes/RightFolderTests Share/data")
    }

    var checker: LiveChecker { LiveChecker(mounts: LiveFolderSystem.mounts()) }

    @Test func foldersAndFiles() {
        #expect(checker.isFolder(root))
        #expect(checker.isFolder(root + "/Thesis/Figures"))
        #expect(!checker.isFolder(root + "/notes.md"))
        #expect(!checker.isFolder(root + "/Missing"))
        #expect(checker.isFolder("/"))
    }

    @Test func followsLocalLinks() {
        #expect(checker.isFolder(root + "/thesis-link"))
        #expect(checker.isFolder(root + "/thesis-link/Figures"))
        #expect(checker.isFolder(root + "/absolute-link"))
        #expect(!checker.isFolder(root + "/file-link"))
        #expect(!checker.isFolder(root + "/dangling"))
        #expect(!checker.isFolder(root + "/loop-a"))
    }

    @Test func neverLooksThroughLinksOntoServers() {
        // Taken as there without asking, since asking a dead server would hang.
        #expect(checker.isFolder(root + "/lab-server"))
        #expect(checker.isFolder(root + "/lab-server/deeper"))
        #expect(checker.isFolder(root + "/old-share"))
    }

    @Test func mountsAndBookmarks() {
        let system = LiveFolderSystem()
        let mounts = LiveFolderSystem.mounts()
        #expect(mounts.contains { $0.path == "/" && $0.isLocal })
        #expect(system.bookmark(for: root + "/Thesis") != nil)
        // No bookmark is made for a folder on a server, or under /Volumes with nothing mounted.
        #expect(system.bookmark(for: "/net/lab-server-that-does-not-exist") == nil)
        #expect(system.bookmark(for: "/Volumes/RightFolderTests Share/data") == nil)
        // A bookmark follows its folder when it's renamed.
        let bookmark = system.bookmark(for: root + "/Thesis/Figures")
        try? FileManager.default.moveItem(atPath: root + "/Thesis/Figures", toPath: root + "/Thesis/Plots")
        let resolved = system.resolve(Favorite(path: root + "/Thesis/Figures", bookmark: bookmark))
        #expect(resolved.map { Paths.normalize($0.path) ?? "" }?.hasSuffix("/Thesis/Plots") == true)
    }
}
