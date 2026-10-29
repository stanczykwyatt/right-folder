import CoreGraphics
import Foundation
import Testing
@testable import FolderCore

@Suite("Go to Folder")
struct GoToTests {
    @Test func textEndsInASlash() {
        #expect(GoTo.text(for: "/Users/robin/Documents") == "/Users/robin/Documents/")
        #expect(GoTo.text(for: "/") == "/")
        #expect(GoTo.text(for: "/Volumes/Field Drive") == "/Volumes/Field Drive/")
    }

    @Test func recognizesTheField() {
        #expect(GoTo.isGoToField(role: "AXTextField", subrole: nil, wasFocusedBefore: false))
        #expect(GoTo.isGoToField(role: "AXComboBox", subrole: nil, wasFocusedBefore: false))
        // The Save dialog's name field was already focused, and a search field is never it.
        #expect(!GoTo.isGoToField(role: "AXTextField", subrole: nil, wasFocusedBefore: true))
        #expect(!GoTo.isGoToField(role: "AXTextField", subrole: "AXSearchField", wasFocusedBefore: false))
        #expect(!GoTo.isGoToField(role: "AXTextField", subrole: "AXSecureTextField", wasFocusedBefore: false))
        for role in ["AXOutline", "AXList", "AXBrowser", "AXButton", "AXTextArea", nil] as [String?] {
            #expect(!GoTo.isGoToField(role: role, subrole: nil, wasFocusedBefore: false))
        }
    }

    @Test func checksTheFieldTookThePath() {
        let home = "/Users/robin"
        #expect(GoTo.fieldHolds("/Users/robin/Documents/", path: "/Users/robin/Documents", home: home))
        #expect(GoTo.fieldHolds("/Users/robin/Documents", path: "/Users/robin/Documents", home: home))
        #expect(GoTo.fieldHolds("~/Documents/", path: "/Users/robin/Documents", home: home))
        #expect(!GoTo.fieldHolds("/Users/robin/Desktop/", path: "/Users/robin/Documents", home: home))
        #expect(!GoTo.fieldHolds("", path: "/Users/robin/Documents", home: home))
        #expect(!GoTo.fieldHolds(nil, path: "/Users/robin/Documents", home: home))
        #expect(!GoTo.fieldHolds("/Users/robin/Docu", path: "/Users/robin/Documents", home: home))
    }

    @Test func failuresSayWhatToDo() {
        for failure in [GoTo.Failure.dialogGone, .noField, .notAllowed, .unavailable] {
            #expect(failure.message.hasSuffix("."))
        }
        #expect(GoTo.Failure.noField.message.contains("⇧⌘G"))
    }
}

@Suite("Keyboard layouts")
struct KeyLayoutTests {
    /// What the letter keys type on three layouts, by key code.
    static let qwerty: [UInt16: String] = [0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 34: "i", 36: "\r"]
    static let dvorak: [UInt16: String] = [0: "a", 1: "o", 2: "e", 3: "u", 4: "d", 5: "i", 34: "g", 36: "\r"]
    static let azerty: [UInt16: String] = [0: "q", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 12: "a"]

    @Test func findsGOnEachLayout() {
        #expect(KeyLayout.keyCode(for: "g", in: Self.qwerty) == 5)
        #expect(KeyLayout.keyCode(for: "g", in: Self.dvorak) == 34)
        #expect(KeyLayout.keyCode(for: "g", in: Self.azerty) == 5)
        #expect(KeyLayout.keyCode(for: "G", in: Self.dvorak) == 34)
    }

    @Test func fallsBackToUSKeys() {
        let greek: [UInt16: String] = [5: "γ", 0: "α"]
        #expect(KeyLayout.keyCode(for: "g", in: greek) == 5)
        #expect(KeyLayout.keyCode(for: "g", in: [:]) == 5)
        #expect(KeyLayout.keyCode(for: "q", in: [:]) == nil)
    }

    @Test func prefersTheMainKeyboard() {
        #expect(KeyLayout.keyCode(for: "g", in: [90: "g", 5: "g"]) == 5)
    }
}

@Suite("Placement")
struct PlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let size = CGSize(width: 260, height: 400)

    @Test func besideOnTheRight() {
        let dialog = CGRect(x: 400, y: 120, width: 640, height: 480)
        let frame = Placement.frame(beside: dialog, size: size, screens: [screen])
        #expect(frame == CGRect(x: 1048, y: 120, width: 260, height: 400))
    }

    @Test func leftWhenTheRightIsFull() {
        let dialog = CGRect(x: 700, y: 100, width: 640, height: 480)
        let frame = Placement.frame(beside: dialog, size: size, screens: [screen])
        #expect(frame.maxX == 692)
        #expect(frame.minY == 100)
    }

    @Test func insideWhenNeitherSideFits() {
        let dialog = CGRect(x: 40, y: 60, width: 1360, height: 700)
        let frame = Placement.frame(beside: dialog, size: size, screens: [screen])
        #expect(frame.maxX == dialog.maxX - Placement.gap)
        #expect(screen.contains(frame))
    }

    @Test func staysOnScreen() {
        let low = CGRect(x: 300, y: 700, width: 500, height: 180)
        let frame = Placement.frame(beside: low, size: size, screens: [screen])
        #expect(frame.maxY <= screen.maxY && frame.minY >= screen.minY)
        let huge = Placement.frame(beside: low, size: CGSize(width: 260, height: 2000), screens: [screen])
        #expect(huge.height == 900 && huge.minY == 0)
    }

    @Test func picksTheDialogsScreen() {
        let right = CGRect(x: 1440, y: -200, width: 1920, height: 1080)
        let dialog = CGRect(x: 1800, y: 0, width: 600, height: 400)
        let frame = Placement.frame(beside: dialog, size: size, screens: [screen, right])
        #expect(right.contains(frame))
        #expect(frame.minX == dialog.maxX + Placement.gap)
        // Mostly on the left screen, so it stays there, on its left side.
        let straddling = CGRect(x: 1000, y: 100, width: 600, height: 400)
        #expect(Placement.screen(for: straddling, in: [screen, right]) == screen)
        // Off every screen: the main one.
        #expect(Placement.screen(for: CGRect(x: -5000, y: 0, width: 10, height: 10), in: [screen, right]) == screen)
        #expect(Placement.screen(for: dialog, in: []).width > 0)
    }

    @Test func flipsCoordinates() {
        let ax = CGRect(x: 100, y: 50, width: 200, height: 100)
        let appKit = Placement.flip(ax, mainHeight: 900)
        #expect(appKit == CGRect(x: 100, y: 750, width: 200, height: 100))
        #expect(Placement.flip(appKit, mainHeight: 900) == ax)
    }
}

@Suite("Wording")
struct DescribeTests {
    @Test func statusLines() {
        #expect(Describe.headline(.waiting) == "Waiting for an Open or Save dialog")
        #expect(Describe.headline(.showing(.save, app: "Inkpad")) == "Save dialog in Inkpad")
        #expect(Describe.headline(.showing(.open, app: "Inkpad")) == "Open dialog in Inkpad")
        #expect(Describe.headline(.offInApp("Inkpad")) == "Off in Inkpad")
        for status in [Describe.Status.needsAccessibility, .paused, .waiting, .showing(.open, app: "A"), .offInApp("A")] {
            #expect(!Describe.headline(status).isEmpty)
            #expect(Describe.detail(status).hasSuffix("."))
        }
        #expect(Describe.detail(.waiting).contains(Describe.shortcut))
    }

    @Test func sectionsAndAvailability() {
        #expect(Describe.section(.finder) == "Open in Finder")
        #expect(Describe.section(.favorite) == "Favorites")
        #expect(Describe.section(.recent) == "Recent")
        #expect(Describe.availability(.ready) == nil)
        #expect(Describe.availability(.missing) == "Not found")
    }

    @Test func safeText() {
        #expect(Describe.safe("Inkpad") == "Inkpad")
        #expect(Describe.safe("Evil\u{202E}gpj.app") == "Evilgpj.app")
        #expect(Describe.safe("Two\nlines") == "Two lines")
        #expect(Describe.safe("  padded  ") == "padded")
        #expect(Describe.safe(String(repeating: "x", count: 100), limit: 10) == String(repeating: "x", count: 9) + "…")
        #expect(Describe.headline(.showing(.open, app: String(repeating: "y", count: 100))).count < 70)
    }
}
