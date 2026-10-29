import AppKit
import Testing
@testable import FolderCore
@testable import RightFolder

@MainActor
final class RecordedActions: StatusMenuActions {
    var calls: [String] = []
    func allowAccessibility() { calls.append("allow") }
    func pinFolder() { calls.append("pin") }
    func pinFinderFolder(_ path: String) { calls.append("pin " + path) }
    func togglePaused() { calls.append("pause") }
    func toggleRemembersRecents() { calls.append("recents") }
    func clearRecents() { calls.append("clear") }
    func openWindow() { calls.append("window") }
    func toggleOpenAtLogin() { calls.append("login") }
    func showAbout() { calls.append("about") }
}

@MainActor
@Suite("Menu")
struct StatusMenuTests {
    func build(_ model: FolderModel, actions: RecordedActions = RecordedActions()) -> (NSMenu, StatusMenu) {
        let menu = NSMenu()
        let status = StatusMenu(model: model, actions: actions)
        status.opensAtLogin = { true }
        status.build(into: menu)
        return (menu, status)
    }

    func titles(_ menu: NSMenu) -> [String] {
        menu.items.filter { !$0.isSeparatorItem }.map(\.title)
    }

    @Test func showsTheDialog() {
        let (menu, _) = build(Gallery.model())
        let titles = titles(menu)
        #expect(titles.first == "Save dialog in Inkpad")
        #expect(titles.contains("Pin “Drafts” from Finder"))
        #expect(titles.contains("Open Right Folder…"))
        #expect(!titles.contains("Allow Accessibility…"))
        #expect(menu.items.first { $0.title == "Show Folders Beside Dialogs" }?.state == .on)
        #expect(menu.items.first { $0.title == "Open at Login" }?.state == .on)
        #expect(menu.items.last?.title == "Quit Right Folder")
    }

    @Test func asksForAccessibility() {
        let (menu, _) = build(Gallery.model(trusted: false))
        #expect(titles(menu).prefix(3) == ["Accessibility is off", StatusMenu.wrap(Describe.detail(.needsAccessibility)), "Allow Accessibility…"])
        #expect(!titles(menu).contains { $0.hasPrefix("Pin “") })
    }

    @Test func noFinderPinWhenAlreadyAFavorite() {
        let model = Gallery.model(favorites: [Gallery.finder[0]])
        #expect(!titles(build(model).0).contains { $0.hasPrefix("Pin “") })
    }

    @Test func clearIsOffWithNothingToClear() {
        let model = Gallery.model(finder: [], recents: [])
        #expect(build(model).0.items.first { $0.title == "Clear Recent Folders" }?.isEnabled == false)
    }

    @Test func itemsCallTheirActions() {
        let actions = RecordedActions()
        let (menu, status) = build(Gallery.model(trusted: true), actions: actions)
        for item in menu.items where item.target === status {
            if let action = item.action { NSApp.sendAction(action, to: status, from: item) }
        }
        #expect(actions.calls == ["pin", "pin " + Gallery.finder[0], "window", "pause", "recents", "clear", "login", "about"])
    }

    @Test func wrapsLongLines() {
        let wrapped = StatusMenu.wrap(String(repeating: "word ", count: 30), width: 20)
        #expect(wrapped.split(separator: "\n").allSatisfy { $0.count <= 20 })
        #expect(StatusMenu.wrap("short") == "short")
    }
}
