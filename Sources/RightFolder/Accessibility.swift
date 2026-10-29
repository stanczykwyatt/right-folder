import AppKit
import ApplicationServices

/// Asking for Accessibility, and noticing when it's turned on or off.
@MainActor
enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows macOS's own prompt, which adds Right Folder to the list in Privacy & Security.
    static func ask() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// The one page Right Folder ever opens: Privacy & Security → Accessibility.
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }

    /// Calls `changed` when Accessibility might have been turned on or off for any app.
    static func observe(_ changed: @escaping @MainActor () -> Void) {
        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main) { _ in
            // The setting takes a moment to apply after the notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MainActor.assumeIsolated { changed() }
            }
        }
    }
}
