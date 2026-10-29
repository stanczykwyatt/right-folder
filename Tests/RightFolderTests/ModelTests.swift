import Foundation
import Testing
@testable import FolderCore
@testable import RightFolder

@MainActor
@Suite("Model")
struct ModelTests {
    let home = Gallery.home

    @Test func listsTheGallery() {
        let model = Gallery.model()
        #expect(model.list.finder.map(\.path) == Gallery.finder)
        #expect(model.list.favorites.map(\.path) == Gallery.favorites)
        #expect(model.list.favorites.last?.availability == .network)
        // The front Finder folder became a recent folder when the dialog opened, but it's listed under Finder.
        #expect(model.recents.paths.first == Gallery.finder[0])
        #expect(model.list.recents.map(\.path) == Gallery.recents)
        #expect(model.status == .showing(.save, app: "Inkpad"))
        #expect(model.showsPanel)
    }

    @Test func jumpsWhenClicked() async {
        let jumps = RecordedJumps()
        let model = Gallery.model(jumps: jumps)
        await model.jump(to: home + "/Documents/Lab Notes")
        #expect(jumps.paths == [home + "/Documents/Lab Notes"])
        #expect(model.recents.paths.first == home + "/Documents/Lab Notes")
        #expect(model.message == nil)
        #expect(model.jumping == nil)
    }

    @Test func remembersJumpsAcrossLaunches() async {
        let preferences = testPreferences()
        let model = Gallery.model(preferences: preferences)
        await model.jump(to: home + "/Desktop")
        #expect(preferences.recents.paths.first == home + "/Desktop")
    }

    @Test func saysWhatWentWrong() async {
        let jumps = RecordedJumps()
        jumps.result = .failed(.noField)
        let model = Gallery.model(jumps: jumps)
        await model.jump(to: home + "/Downloads")
        #expect(model.message == GoTo.Failure.noField.message)
        #expect(!model.recents.paths.contains(home + "/Downloads"))
        // The message goes when the dialog does.
        model.dialogClosed()
        #expect(model.message == nil)
    }

    @Test func neverJumpsSomewhereUnavailable() async {
        let jumps = RecordedJumps()
        let system = FakeSystem()
        system.folders.remove(home + "/Documents/Lab Notes")
        let model = Gallery.model(system: system, jumps: jumps)
        #expect(model.list.favorites.first?.availability == .missing)
        await model.jump(to: home + "/Documents/Lab Notes")
        await model.jump(to: "/Not/Listed")
        #expect(jumps.paths.isEmpty)
        #expect(model.message == GoTo.Failure.unavailable.message)
    }

    @Test func neverJumpsWithoutADialog() async {
        let jumps = RecordedJumps()
        let model = Gallery.model(dialog: nil, jumps: jumps)
        await model.jump(to: home + "/Downloads")
        await model.step(backwards: false)
        #expect(jumps.paths.isEmpty)
        #expect(model.status == .waiting)
        #expect(!model.showsPanel)
    }

    @Test func theShortcutStepsThroughInOrder() async {
        let jumps = RecordedJumps()
        let model = Gallery.model(jumps: jumps)
        for _ in 0..<3 { await model.step(backwards: false) }
        #expect(jumps.paths == Array(model.list.cycle.prefix(3)))
        await model.step(backwards: true)
        #expect(jumps.paths.last == model.list.cycle[1])
    }

    @Test func theShortcutSkipsWhatsUnavailable() async {
        let jumps = RecordedJumps()
        let model = Gallery.model(finder: [], favorites: ["/Volumes/Old Drive/Photos"], recents: [home + "/Desktop"], jumps: jumps)
        await model.step(backwards: false)
        await model.step(backwards: false)
        #expect(jumps.paths == [home + "/Desktop", home + "/Desktop"])
    }

    @Test func aNewDialogStartsTheShortcutOver() async {
        let jumps = RecordedJumps()
        let model = Gallery.model(jumps: jumps)
        await model.step(backwards: false)
        await model.step(backwards: false)
        model.dialogClosed()
        model.dialogOpened(FolderModel.Dialog(kind: .open, appName: "Inkpad", bundleID: "com.example.inkpad"))
        await model.step(backwards: false)
        #expect(jumps.paths.last == model.list.cycle[0])
    }

    @Test func aLateJumpDoesntTouchTheNextDialog() async {
        let jumps = RecordedJumps()
        jumps.result = .failed(.dialogGone)
        jumps.delay = 0.05
        let model = Gallery.model(jumps: jumps)
        let jump = Task { await model.jump(to: home + "/Downloads") }
        try? await Task.sleep(for: .seconds(0.01))
        model.dialogClosed()
        model.dialogOpened(FolderModel.Dialog(kind: .save, appName: "Inkpad", bundleID: "com.example.inkpad", id: 2))
        // While the first jump is still going, nothing else can start.
        await model.step(backwards: false)
        #expect(jumps.paths == [home + "/Downloads"])
        await jump.value
        #expect(model.message == nil)
        #expect(model.jumping == nil)
        await model.step(backwards: false)
        #expect(jumps.paths.count == 2)
    }

    @Test func theNextLookalikeDialogStartsOver() async {
        let jumps = RecordedJumps()
        let model = Gallery.model(jumps: jumps)
        await model.step(backwards: false)
        await model.step(backwards: false)
        // Another Save sheet in the same app looks the same, but it's a new dialog.
        model.dialogOpened(FolderModel.Dialog(kind: .save, appName: "Inkpad", bundleID: "com.example.inkpad", id: 7))
        await model.step(backwards: false)
        #expect(jumps.paths.last == model.list.cycle[0])
    }

    @Test func pinsAndUnpins() {
        let preferences = testPreferences()
        let model = Gallery.model(preferences: preferences)
        model.pin(home + "/Downloads")
        #expect(model.list.favorites.last?.path == home + "/Downloads")
        #expect(!model.list.finder.map(\.path).contains(home + "/Downloads"))
        #expect(model.list.favorites.last?.isOpenInFinder == true)
        #expect(preferences.favorites.items.last?.bookmark == Data((home + "/Downloads").utf8))
        model.unpin(home + "/Downloads")
        #expect(model.list.finder.map(\.path).contains(home + "/Downloads"))
        model.move(Gallery.favorites[1], by: -1)
        #expect(preferences.favorites.paths.first == Gallery.favorites[1])
    }

    @Test func favoritesFollowMovedFolders() {
        let system = FakeSystem()
        let renamed = home + "/Documents/Lab Notebook"
        system.folders.insert(renamed)
        system.moved[home + "/Documents/Lab Notes"] = renamed
        let preferences = testPreferences()
        let model = Gallery.model(system: system, preferences: preferences)
        #expect(model.list.favorites.first?.path == renamed)
        #expect(preferences.favorites.paths.first == renamed)
    }

    @Test func recentsCanBeTurnedOff() async {
        let preferences = testPreferences()
        let jumps = RecordedJumps()
        let model = Gallery.model(preferences: preferences, jumps: jumps)
        model.setRemembersRecents(false)
        #expect(model.recents.paths.isEmpty)
        #expect(preferences.recents.paths.isEmpty)
        #expect(!preferences.remembersRecents)
        await model.jump(to: home + "/Downloads")
        model.dialogClosed()
        model.dialogOpened(Gallery.inkpad)
        #expect(model.recents.paths.isEmpty)
        model.setRemembersRecents(true)
        model.forget("/nothing")
        model.clearRecents()
        #expect(model.list.recents.isEmpty)
    }

    @Test func pausedMeansNoPanel() async {
        let jumps = RecordedJumps()
        let model = Gallery.model(jumps: jumps)
        model.setPaused(true)
        #expect(model.status == .paused)
        #expect(!model.showsPanel)
        await model.step(backwards: false)
        #expect(jumps.paths.isEmpty)
        model.setPaused(false)
        #expect(model.showsPanel)
    }

    @Test func offInAnApp() {
        let preferences = testPreferences()
        let model = Gallery.model(preferences: preferences)
        model.setExcluded("com.example.inkpad", true)
        #expect(!model.showsPanel)
        #expect(model.status == .offInApp("Inkpad"))
        #expect(preferences.excludedApps == ["com.example.inkpad"])
        model.setExcluded("com.example.inkpad", false)
        #expect(model.showsPanel)
    }

    @Test func withoutAccessibility() {
        let model = Gallery.model(trusted: false)
        #expect(model.status == .needsAccessibility)
        #expect(!model.showsPanel)
        // Finder isn't asked about its windows without permission.
        #expect(model.list.finder.isEmpty)
        #expect(!model.list.favorites.isEmpty)
    }

    @Test func preferencesDefaults() {
        let preferences = testPreferences()
        #expect(preferences.remembersRecents)
        #expect(!preferences.paused)
        #expect(!preferences.typesPaths)
        #expect(preferences.excludedApps.isEmpty)
        #expect(preferences.favorites.items.isEmpty)
        // A damaged saved list is ignored rather than crashing.
        preferences.defaults.set(Data("not json".utf8), forKey: "favorites")
        #expect(preferences.favorites.items.isEmpty)
    }
}
