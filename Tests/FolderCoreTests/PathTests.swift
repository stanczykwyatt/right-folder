import Testing
@testable import FolderCore

@Suite("Paths")
struct PathTests {
    @Test func normalizes() {
        #expect(Paths.normalize("/Users/robin/Documents/") == "/Users/robin/Documents")
        #expect(Paths.normalize("/Users//robin///Documents") == "/Users/robin/Documents")
        #expect(Paths.normalize("/Users/robin/./Documents/../Desktop") == "/Users/robin/Desktop")
        #expect(Paths.normalize("/") == "/")
        #expect(Paths.normalize("//") == "/")
        #expect(Paths.normalize("/..") == "/")
        #expect(Paths.normalize("/../../etc") == "/etc")
    }

    @Test func refusesWhatADialogCantTake() {
        #expect(Paths.normalize("") == nil)
        #expect(Paths.normalize("Documents") == nil)
        #expect(Paths.normalize("~/Documents") == nil)
        #expect(Paths.normalize("/Users/robin/Line\nBreak") == nil)
        #expect(Paths.normalize("/Users/robin/Tab\there") == nil)
        #expect(Paths.normalize("/Users/robin/Null\u{0}") == nil)
        #expect(Paths.normalize("/Users/robin/Bell\u{7}") == nil)
        #expect(Paths.normalize("/" + String(repeating: "a", count: 1100)) == nil)
    }

    @Test func keepsUnusualButValidNames() {
        for name in ["Résumé drafts", "日本語", "100% done", "a:b", "#hash", "emoji 📁", "quotes \"and\" 'apostrophes'", " leading space", "trailing dot."] {
            #expect(Paths.normalize("/Users/robin/" + name) == "/Users/robin/" + name)
        }
    }

    @Test func mapsDataVolumeFirmlinks() {
        #expect(Paths.normalize("/System/Volumes/Data/Users/robin/Documents") == "/Users/robin/Documents")
        #expect(Paths.normalize("/System/Volumes/Data/Applications") == "/Applications")
        #expect(Paths.normalize("/System/Volumes/Data/private/tmp") == "/private/tmp")
        // Something only on the Data volume stays as it is.
        #expect(Paths.normalize("/System/Volumes/Data/.Spotlight-V100") == "/System/Volumes/Data/.Spotlight-V100")
        #expect(Paths.normalize("/System/Volumes/Data") == "/System/Volumes/Data")
    }

    @Test func readsFinderURLs() {
        #expect(Paths.fromFileURL("file:///Users/robin/Documents/") == "/Users/robin/Documents")
        #expect(Paths.fromFileURL("file:///Users/robin/Lab%20Notes/") == "/Users/robin/Lab Notes")
        #expect(Paths.fromFileURL("file:///Users/robin/R%C3%A9sum%C3%A9/") == "/Users/robin/Résumé")
        #expect(Paths.fromFileURL("file://localhost/Volumes/Field%20Drive/") == "/Volumes/Field Drive")
        #expect(Paths.fromFileURL("file:///") == "/")
        #expect(Paths.fromFileURL("FILE:///tmp/") == "/tmp")
        #expect(Paths.fromFileURL("file:///Users/robin/100%25/") == "/Users/robin/100%")
    }

    @Test func refusesOtherURLs() {
        for url in ["https://example.com/", "smb://lab-share/data/", "afp://server/", "file://server/share/", "x-finder:recents", "", "not a url", "/Users/robin", "file:///Users/robin/Bad%0ABreak/"] {
            #expect(Paths.fromFileURL(url) == nil, "\(url)")
        }
    }

    @Test func abbreviatesHome() {
        #expect(Paths.abbreviate("/Users/robin", home: "/Users/robin") == "~")
        #expect(Paths.abbreviate("/Users/robin/Documents", home: "/Users/robin") == "~/Documents")
        #expect(Paths.abbreviate("/Users/robinson/Documents", home: "/Users/robin") == "/Users/robinson/Documents")
        #expect(Paths.abbreviate("/Volumes/X", home: "/Users/robin") == "/Volumes/X")
        #expect(Paths.abbreviate("/tmp", home: "/") == "/tmp")
    }

    @Test func insideIsByWholeFolders() {
        #expect(Paths.isInside("/Users/robin/Documents", "/Users/robin"))
        #expect(Paths.isInside("/Users/robin", "/Users/robin"))
        #expect(!Paths.isInside("/Users/robinson", "/Users/robin"))
        #expect(Paths.isInside("/anything", "/"))
    }

    @Test func offLimits() {
        let home = Mac.home
        #expect(Paths.isOffLimits(home + "/.Trash", home: home))
        #expect(Paths.isOffLimits(home + "/.Trash/old", home: home))
        #expect(Paths.isOffLimits("/Volumes/Field Drive/.Trashes/501", home: home))
        #expect(Paths.isOffLimits("/Applications/Inkpad.app/Contents", home: home))
        #expect(Paths.isOffLimits(home + "/Pictures/Photos Library.photoslibrary/originals", home: home))
        // A package itself can be picked in a dialog; only going inside it is off limits.
        #expect(!Paths.isOffLimits("/Applications/Inkpad.app", home: home))
        #expect(!Paths.isOffLimits(home + "/Documents", home: home))
        #expect(!Paths.isOffLimits(home + "/.Trashy", home: home))
        #expect(!Paths.isOffLimits(home + "/Projects/my.app.notes", home: home))
    }

    @Test func followsLinks() {
        #expect(Paths.linkTarget("/Volumes/lab-share/data", of: "/Users/robin/data") == "/Volumes/lab-share/data")
        #expect(Paths.linkTarget("../Shared/data", of: "/Users/robin/Desktop/data") == "/Users/robin/Shared/data")
        #expect(Paths.linkTarget("Projects", of: "/Users/robin/p") == "/Users/robin/Projects")
        // A link whose target holds a line break can't be offered.
        #expect(Paths.linkTarget("bad\nlink", of: "/Users/robin/p") == nil)
        #expect(Paths.linkTarget("/x\u{0}", of: "/y") == nil)
    }

    @Test func automountFolders() {
        #expect(Paths.isAutomount("/net/fileserver/home"))
        #expect(Paths.isAutomount("/Network/Servers"))
        #expect(!Paths.isAutomount("/Users/robin/net"))
        #expect(!Paths.isAutomount("/network-notes"))
        #expect(FolderList.availability(of: "/net/fileserver/home", context: Mac.context, checker: FakeChecker(folders: [])) == .network)
    }

    @Test func findsTheVolume() {
        #expect(Mount.of("/Volumes/Field Drive/2026 Survey", in: Mac.mounts)?.name == "Field Drive")
        #expect(Mount.of("/Volumes/Field Drive Backup", in: Mac.mounts)?.path == "/")
        #expect(Mount.of("/Users/robin", in: Mac.mounts)?.path == "/")
        #expect(Mount.of("/Users/robin", in: [])?.path == nil)
    }
}

@Suite("Names")
struct NameTests {
    let context = Mac.context

    @Test func homeFolders() {
        #expect(context.describe(Mac.home) == FolderInfo(name: "robin", location: "Home", place: .home))
        #expect(context.describe(Mac.home + "/Desktop").place == .desktop)
        #expect(context.describe(Mac.home + "/Documents") == FolderInfo(name: "Documents", location: "~", place: .documents))
        #expect(context.describe(Mac.home + "/Downloads").place == .downloads)
        #expect(context.describe(Mac.home + "/Documents/Thesis/Figures") == FolderInfo(name: "Figures", location: "~/Documents/Thesis", place: .folder))
    }

    @Test func otherFolders() {
        #expect(context.describe("/Applications") == FolderInfo(name: "Applications", location: "/", place: .folder))
        #expect(context.describe("/") == FolderInfo(name: "Macintosh HD", location: "Startup disk", place: .volume))
        let renamed = PathContext(home: Mac.home, mounts: Mac.mounts, bootName: "Studio")
        #expect(renamed.describe("/").name == "Studio")
    }

    @Test func iCloudDrive() {
        let drive = Mac.home + "/Library/Mobile Documents/com~apple~CloudDocs"
        #expect(context.describe(drive) == FolderInfo(name: "iCloud Drive", location: "iCloud", place: .iCloud))
        #expect(context.describe(drive + "/Reading") == FolderInfo(name: "Reading", location: "iCloud Drive", place: .iCloud))
        #expect(context.describe(drive + "/Reading/2026") == FolderInfo(name: "2026", location: "iCloud Drive › Reading", place: .iCloud))
    }

    @Test func appFoldersInICloud() {
        let root = Mac.home + "/Library/Mobile Documents"
        #expect(context.describe(root + "/com~apple~Pages/Documents") == FolderInfo(name: "Pages", location: "iCloud Drive", place: .iCloud))
        #expect(context.describe(root + "/com~apple~Pages") == FolderInfo(name: "Pages", location: "iCloud Drive", place: .iCloud))
        #expect(context.describe(root + "/iCloud~com~example~Notebook/Documents/Ideas") == FolderInfo(name: "Ideas", location: "iCloud Drive › Notebook", place: .iCloud))
        #expect(context.describe(root + "/iCloud~com~example~Notebook/Documents/Ideas/Old") == FolderInfo(name: "Old", location: "iCloud Drive › Notebook › Ideas", place: .iCloud))
        #expect(context.describe(root + "/iCloud~com~example~Notebook/Data") == FolderInfo(name: "Data", location: "iCloud Drive › Notebook", place: .iCloud))
        #expect(PathContext.appName(container: "com~apple~Numbers") == "Numbers")
        #expect(PathContext.appName(container: "plain") == "plain")
        #expect(PathContext.appName(container: "trailing~") == "trailing")
    }

    @Test func volumes() {
        #expect(context.describe("/Volumes/Field Drive") == FolderInfo(name: "Field Drive", location: "Disk", place: .volume))
        #expect(context.describe("/Volumes/Field Drive/2026 Survey") == FolderInfo(name: "2026 Survey", location: "Field Drive", place: .folder))
        #expect(context.describe("/Volumes/Field Drive/2026 Survey/Plots") == FolderInfo(name: "Plots", location: "Field Drive › 2026 Survey", place: .folder))
        #expect(context.describe("/Volumes/lab-share") == FolderInfo(name: "lab-share", location: "Network", place: .network))
        #expect(context.describe("/Volumes/lab-share/data") == FolderInfo(name: "data", location: "lab-share", place: .network))
    }

    @Test func unmountedVolumesStillGetNames() {
        #expect(context.describe("/Volumes/Old Drive/Photos") == FolderInfo(name: "Photos", location: "/Volumes/Old Drive", place: .folder))
    }
}
