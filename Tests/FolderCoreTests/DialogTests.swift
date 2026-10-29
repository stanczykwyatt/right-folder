import Foundation
import Testing
@testable import FolderCore

@Suite("Dialogs")
struct DialogTests {
    @Test func recognizesAppKitPanels() {
        #expect(Dialogs.kind(of: Recorded.savePanel) == .save)
        #expect(Dialogs.kind(of: Recorded.openPanel) == .open)
        #expect(Dialogs.kind(of: Recorded.saveSheet) == .save)
        #expect(Dialogs.kind(of: Recorded.openSheet) == .open)
    }

    @Test func ignoresOtherWindows() {
        for element in [Recorded.alert, Recorded.colorPanel, Recorded.fontPanel, Recorded.document(), Recorded.webPage] {
            #expect(Dialogs.kind(of: element) == nil)
            #expect(Dialogs.find(in: element) == nil)
        }
    }

    @Test func onlyWindowsAndSheetsCount() {
        // The identifier on a button or a group in a web page isn't a dialog.
        for role in ["AXGroup", "AXButton", "AXWebArea", "AXTextField", nil] as [String?] {
            #expect(Dialogs.kind(of: Element(role: role, identifier: "save-panel")) == nil)
            #expect(Dialogs.kind(of: Element(role: role, subrole: "AXOpenPanel")) == nil)
        }
        #expect(Dialogs.find(in: Recorded.webPage) == nil)
    }

    @Test func subrolesCountToo() {
        #expect(Dialogs.kind(of: Element(role: "AXWindow", subrole: "AXOpenPanel")) == .open)
        #expect(Dialogs.kind(of: Element(role: "AXSheet", subrole: "AXSavePanel")) == .save)
        #expect(Dialogs.kind(of: Element(role: "AXWindow", subrole: "AXDialog")) == nil)
    }

    @Test func identifiersMustMatchExactly() {
        for identifier in ["Save-Panel", "save-panel ", "savepanel", "save", "open-panel-2", ""] {
            #expect(Dialogs.kind(of: Element(role: "AXWindow", identifier: identifier)) == nil)
        }
    }

    @Test func findsTheWindowItself() {
        #expect(Dialogs.find(in: Recorded.savePanel) == DialogMatch(kind: .save, path: []))
        #expect(Dialogs.find(in: Recorded.openPanel) == DialogMatch(kind: .open, path: []))
    }

    @Test func findsASheetOnADocument() {
        let window = Recorded.document(sheets: [Recorded.saveSheet])
        #expect(Dialogs.find(in: window) == DialogMatch(kind: .save, path: [3]))
    }

    @Test func skipsSheetsThatArentDialogs() {
        let alert = Element(role: "AXSheet", subrole: nil, identifier: nil)
        let window = Recorded.document(sheets: [alert, Recorded.openSheet])
        #expect(Dialogs.find(in: window) == DialogMatch(kind: .open, path: [4]))
        #expect(Dialogs.find(in: Recorded.document(sheets: [alert])) == nil)
    }

    @Test func theDeepestDialogWins() {
        // An Open dialog opened from a sheet on a Save dialog, like "Choose…" in an export sheet.
        var save = Recorded.saveSheet
        save.children = [Element(role: "AXButton"), Recorded.openSheet]
        let window = Recorded.document(sheets: [save])
        #expect(Dialogs.find(in: window) == DialogMatch(kind: .open, path: [3, 1]))
        // A plain alert on a Save dialog, like "Replace existing file?", still finds the Save dialog.
        var withAlert = Recorded.saveSheet
        withAlert.children = [Element(role: "AXSheet")]
        #expect(Dialogs.find(in: Recorded.document(sheets: [withAlert])) == DialogMatch(kind: .save, path: [3]))
    }

    @Test func onlySheetsAreSearched() {
        // A panel's identifier deep inside a window's content isn't a dialog on it.
        let window = Element(role: "AXWindow", children: [Element(role: "AXGroup", children: [Recorded.saveSheet])])
        #expect(Dialogs.find(in: window) == nil)
    }

    @Test func searchDepthIsLimited() {
        var element = Recorded.saveSheet
        for _ in 0..<6 { element = Element(role: "AXSheet", children: [element]) }
        let window = Element(role: "AXWindow", children: [element])
        #expect(Dialogs.find(in: window) == nil)
        let shallow = Element(role: "AXWindow", children: [Element(role: "AXSheet", children: [Recorded.saveSheet])])
        #expect(Dialogs.find(in: shallow)?.path == [0, 0])
    }

    @Test func whereToOffer() {
        #expect(Dialogs.shouldOffer(appBundleID: "com.example.inkpad", ownBundleID: "com.stanczykwyatt.RightFolder", excluded: []))
        #expect(!Dialogs.shouldOffer(appBundleID: "com.stanczykwyatt.RightFolder", ownBundleID: "com.stanczykwyatt.RightFolder", excluded: []))
        #expect(!Dialogs.shouldOffer(appBundleID: "com.example.inkpad", ownBundleID: nil, excluded: ["com.example.inkpad"]))
        // An app without a bundle ID, like a command line tool's window, can't be turned off by ID.
        #expect(Dialogs.shouldOffer(appBundleID: nil, ownBundleID: "com.stanczykwyatt.RightFolder", excluded: ["com.example.inkpad"]))
    }

    @Test func elementsRoundTrip() throws {
        let window = Recorded.document(sheets: [Recorded.saveSheet])
        let data = try JSONEncoder().encode(window)
        #expect(try JSONDecoder().decode(Element.self, from: data) == window)
    }
}
