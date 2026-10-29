import AppKit
import Foundation
import Testing
@testable import FolderCore
@testable import RightFolder

/// Real Open and Save panels, made in this test process and never shown, read through AppKit's
/// own accessibility methods: the same role, subrole and identifier another app sees.
@MainActor
@Suite("Real panels")
struct RealPanelTests {
    private func element(_ window: NSWindow) -> Element {
        Element(role: window.accessibilityRole()?.rawValue, subrole: window.accessibilitySubrole()?.rawValue, identifier: window.accessibilityIdentifier())
    }

    @Test func savePanel() {
        let panel = NSSavePanel()
        #expect(!panel.isVisible)
        #expect(Dialogs.kind(of: element(panel)) == .save)
    }

    @Test func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        #expect(!panel.isVisible)
        #expect(Dialogs.kind(of: element(panel)) == .open)
    }

    @Test func otherPanelsArentDialogs() {
        for window in [NSAlert().window, NSPanel(), NSWindow()] {
            #expect(Dialogs.kind(of: element(window)) == nil)
        }
    }

    @Test func aWindowShowingAFolderNamesIt() {
        // Finder's windows say which folder they show the same way: the window's represented URL.
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.representedURL = URL(fileURLWithPath: "/Users/robin/Documents", isDirectory: true)
        let document = window.accessibilityDocument()
        #expect(document.flatMap(Paths.fromFileURL) == "/Users/robin/Documents")
        #expect(!window.isVisible)
    }

    @Test func keyboardLayoutHasAG() {
        // Whatever layout this Mac uses, some key types g, or the US one is used.
        #expect(KeyLayout.keyCode(for: "g", in: Keyboard.table()) != nil)
        #expect(KeyLayout.keyCode(for: "j", in: Keyboard.table()) != nil || KeyLayout.ansi["j"] != nil)
    }
}

/// The app's bundle settings and signing, checked against what the docs promise.
@Suite("Bundle")
struct BundleTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func aMenuBarAppWithItsOwnID() throws {
        let info = try #require(NSDictionary(contentsOf: Self.root.appendingPathComponent("Resources/Info.plist")) as? [String: Any])
        #expect(info["CFBundleIdentifier"] as? String == "com.stanczykwyatt.RightFolder")
        #expect(info["LSUIElement"] as? Bool == true)
        #expect(info["CFBundleShortVersionString"] as? String == Describe.version)
        #expect(info["LSMinimumSystemVersion"] as? String == "14.0")
        // It never sends Apple Events, so it has no reason to ask to.
        #expect(info["NSAppleEventsUsageDescription"] == nil)
    }

    @Test func noEntitlementsAndTheDefaultSignature() throws {
        // Accessibility is the only permission, and it needs no entitlement. The build signs with
        // the hardened runtime and macOS's default requirement, never one that trusts the bundle ID alone.
        let resources = try FileManager.default.contentsOfDirectory(atPath: Self.root.appendingPathComponent("Resources").path)
        #expect(!resources.contains { $0.hasSuffix(".entitlements") })
        let script = try String(contentsOf: Self.root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
        #expect(script.contains("--options runtime"))
        #expect(!script.contains("--entitlements"))
        #expect(!script.contains("--requirements"))
        #expect(!script.contains("designated =>"))
    }
}
