import AppKit
import FolderCore
import ServiceManagement

/// What the menu's items do. The app delegate does them; tests record them.
@MainActor
protocol StatusMenuActions: AnyObject {
    func allowAccessibility()
    func pinFolder()
    func pinFinderFolder(_ path: String)
    func togglePaused()
    func toggleRemembersRecents()
    func clearRecents()
    func openWindow()
    func toggleOpenAtLogin()
    func showAbout()
}

/// Builds the menu bar menu fresh each time it opens.
@MainActor
final class StatusMenu: NSObject {
    private let model: FolderModel
    private weak var actions: StatusMenuActions?
    var opensAtLogin: () -> Bool = { SMAppService.mainApp.status == .enabled }

    /// Menus don't wrap, so long lines are broken by hand at about this many characters.
    static let lineLength = 52

    init(model: FolderModel, actions: StatusMenuActions) {
        self.model = model
        self.actions = actions
    }

    func build(into menu: NSMenu) {
        menu.removeAllItems()
        let status = model.status
        menu.addItem(disabled(Describe.headline(status)))
        menu.addItem(disabled(Describe.detail(status), wrapped: true))
        if status == .needsAccessibility {
            menu.addItem(item("Allow Accessibility…", #selector(allowAccessibility)))
        }

        menu.addItem(.separator())
        menu.addItem(item("Pin a Folder…", #selector(pinFolder)))
        if let front = model.frontFinderFolder, !model.favorites.contains(front) {
            let name = Describe.safe((front as NSString).lastPathComponent, limit: 40)
            let pin = item("Pin “\(name)” from Finder", #selector(pinFinderFolder(_:)))
            pin.representedObject = front
            menu.addItem(pin)
        }
        menu.addItem(item("Open Right Folder…", #selector(openWindow), key: "o"))

        menu.addItem(.separator())
        let show = item("Show Folders Beside Dialogs", #selector(togglePaused))
        show.state = model.paused ? .off : .on
        menu.addItem(show)
        let remember = item("Remember Recent Folders", #selector(toggleRemembersRecents))
        remember.state = model.remembersRecents ? .on : .off
        menu.addItem(remember)
        let clear = item("Clear Recent Folders", #selector(clearRecents))
        clear.isEnabled = !model.recents.paths.isEmpty
        menu.addItem(clear)
        let login = item("Open at Login", #selector(toggleOpenAtLogin))
        login.state = opensAtLogin() ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("About Right Folder", #selector(showAbout)))
        menu.addItem(NSMenuItem(title: "Quit Right Folder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // MARK: Items

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func disabled(_ title: String, wrapped: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: wrapped ? Self.wrap(title) : title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// Breaks text into lines of about `width` characters, between words.
    static func wrap(_ text: String, width: Int = lineLength) -> String {
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            if !line.isEmpty && line.count + 1 + word.count > width {
                lines.append(line)
                line = ""
            }
            line += line.isEmpty ? String(word) : " " + word
        }
        if !line.isEmpty { lines.append(line) }
        return lines.joined(separator: "\n")
    }

    // MARK: Actions

    @objc private func allowAccessibility() { actions?.allowAccessibility() }
    @objc private func pinFolder() { actions?.pinFolder() }
    @objc private func togglePaused() { actions?.togglePaused() }
    @objc private func toggleRemembersRecents() { actions?.toggleRemembersRecents() }
    @objc private func clearRecents() { actions?.clearRecents() }
    @objc private func openWindow() { actions?.openWindow() }
    @objc private func toggleOpenAtLogin() { actions?.toggleOpenAtLogin() }
    @objc private func showAbout() { actions?.showAbout() }

    @objc private func pinFinderFolder(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        actions?.pinFinderFolder(path)
    }
}
