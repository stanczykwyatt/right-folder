import AppKit
import ApplicationServices
import FolderCore

/// Where the folders open in Finder come from, so tests can make them up.
@MainActor
protocol FinderSource {
    func folders() -> [String]
}

/// Reads the folder each Finder window shows, front to back, from the window's Accessibility
/// "document": the same folder its title bar icon stands for. Only that is read: not the window's
/// title, what's selected, or what's in the folder.
struct FinderWindows: FinderSource {
    func folders() -> [String] {
        guard AXIsProcessTrusted(),
              let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return [] }
        let app = AX.app(finder.processIdentifier)
        guard let windows = AX.attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        return windows.compactMap { window in
            // The desktop is a window too, but it isn't a folder you'd want a dialog in.
            guard AX.role(window) == "AXWindow", let url = AX.string(window, kAXDocumentAttribute) else { return nil }
            return Paths.fromFileURL(url)
        }
    }
}
