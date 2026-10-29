import Foundation
@testable import FolderCore

/// Window data as Accessibility reports it. The panels' role, subrole and identifier were read on
/// macOS 15 from a real NSOpenPanel and NSSavePanel made in a test process and never shown; the
/// rest is shaped like what common apps report. Nothing here came from anyone's windows.
enum Recorded {
    static let savePanel = Element(role: "AXWindow", subrole: "AXStandardWindow", identifier: "save-panel")
    static let openPanel = Element(role: "AXWindow", subrole: "AXStandardWindow", identifier: "open-panel")
    static let alert = Element(role: "AXWindow", subrole: "AXDialog", identifier: "")
    static let colorPanel = Element(role: "AXWindow", subrole: "AXFloatingWindow", identifier: "")
    static let fontPanel = Element(role: "AXWindow", subrole: "AXFloatingWindow", identifier: "")

    /// A Save dialog as a sheet on a document window, the way most apps show one.
    static let saveSheet = Element(role: "AXSheet", subrole: nil, identifier: "save-panel")
    static let openSheet = Element(role: "AXSheet", subrole: nil, identifier: "open-panel")

    static func document(sheets: [Element] = []) -> Element {
        Element(role: "AXWindow", subrole: "AXStandardWindow", identifier: nil, children: [
            Element(role: "AXToolbar"),
            Element(role: "AXScrollArea", children: [Element(role: "AXTextArea")]),
            Element(role: "AXButton", subrole: "AXCloseButton"),
        ] + sheets)
    }

    /// A browser window whose page has an element with the same identifier. Not a dialog.
    static let webPage = Element(role: "AXWindow", subrole: "AXStandardWindow", children: [
        Element(role: "AXGroup", identifier: "save-panel", children: [Element(role: "AXButton", identifier: "open-panel")]),
    ])
}

/// A made-up Mac: a home folder, the startup disk, an external drive, a server share and a disk
/// image, and which folders exist on it.
struct FakeChecker: FolderChecking {
    var folders: Set<String>
    func isFolder(_ path: String) -> Bool { folders.contains(path) }
}

enum Mac {
    static let home = "/Users/robin"
    static let mounts = [
        Mount(path: "/", name: "Macintosh HD", isLocal: true),
        Mount(path: "/Volumes/Field Drive", name: "Field Drive", isLocal: true),
        Mount(path: "/Volumes/lab-share", name: "lab-share", isLocal: false),
        Mount(path: "/System/Volumes/Data", name: "Data", isLocal: true),
    ]
    static let context = PathContext(home: home, mounts: mounts)

    static let folders: Set<String> = [
        home, home + "/Desktop", home + "/Documents", home + "/Downloads",
        home + "/Documents/Thesis", home + "/Documents/Thesis/Figures", home + "/Documents/Lab Notes",
        home + "/Library/Mobile Documents/com~apple~CloudDocs",
        home + "/Library/Mobile Documents/com~apple~CloudDocs/Reading",
        home + "/Library/Mobile Documents/com~apple~Pages/Documents",
        "/Volumes/Field Drive", "/Volumes/Field Drive/2026 Survey",
        "/", "/Applications",
    ]
    static let checker = FakeChecker(folders: folders)
}
