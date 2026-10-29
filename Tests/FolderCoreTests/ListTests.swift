import Testing
@testable import FolderCore

@Suite("Folder list")
struct ListTests {
    let home = Mac.home

    func build(finder: [String] = [], favorites: [String] = [], recents: [String] = [], checker: FakeChecker = Mac.checker) -> FolderList {
        FolderList.build(finder: finder, favorites: favorites, recents: recents, context: Mac.context, checker: checker)
    }

    @Test func sectionsInOrder() {
        let list = build(
            finder: [home + "/Documents/Thesis", home + "/Downloads"],
            favorites: [home + "/Documents/Lab Notes"],
            recents: [home + "/Desktop"]
        )
        #expect(list.finder.map(\.path) == [home + "/Documents/Thesis", home + "/Downloads"])
        #expect(list.favorites.map(\.path) == [home + "/Documents/Lab Notes"])
        #expect(list.recents.map(\.path) == [home + "/Desktop"])
        #expect(list.cycle == [home + "/Documents/Thesis", home + "/Downloads", home + "/Documents/Lab Notes", home + "/Desktop"])
        #expect(list.finder.allSatisfy { $0.source == .finder })
        #expect(!list.isEmpty)
        #expect(build().isEmpty)
    }

    @Test func eachFolderOnce() {
        let thesis = home + "/Documents/Thesis"
        let list = build(finder: [thesis, thesis + "/", home + "/Downloads"], favorites: [thesis], recents: [thesis, home + "/Downloads", home + "/Desktop"])
        // The favorite stays with the favorites, marked as open in Finder.
        #expect(list.finder.map(\.path) == [home + "/Downloads"])
        #expect(list.favorites.map(\.path) == [thesis])
        #expect(list.favorites[0].isOpenInFinder)
        #expect(list.recents.map(\.path) == [home + "/Desktop"])
        #expect(Set(list.cycle).count == list.cycle.count)
    }

    @Test func goneFoldersAreLeftOutExceptFavorites() {
        let gone = home + "/Documents/Deleted"
        let list = build(finder: [gone], favorites: [gone, home + "/Documents"], recents: [gone])
        #expect(list.finder.isEmpty)
        #expect(list.recents.isEmpty)
        #expect(list.favorites.map(\.availability) == [.missing, .ready])
        #expect(list.cycle == [home + "/Documents"])
    }

    @Test func networkFoldersAreNeverChecked() {
        // Nothing on the share is in the checker, and it's still offered: looking could hang.
        let list = build(finder: ["/Volumes/lab-share/data"], favorites: ["/Volumes/lab-share"])
        #expect(list.finder.map(\.availability) == [.network])
        #expect(list.favorites.map(\.availability) == [.network])
        #expect(list.cycle.count == 2)
    }

    @Test func unpluggedDrivesAreDisconnected() {
        let list = build(finder: ["/Volumes/Old Drive/Photos"], favorites: ["/Volumes/Old Drive/Photos", "/Volumes/Field Drive/2026 Survey"])
        #expect(list.finder.isEmpty)
        #expect(list.favorites.map(\.availability) == [.disconnected, .ready])
        #expect(Describe.availability(.disconnected) == "Not connected")
    }

    @Test func availabilityRules() {
        let context = Mac.context
        let checker = Mac.checker
        #expect(FolderList.availability(of: home + "/Documents", context: context, checker: checker) == .ready)
        #expect(FolderList.availability(of: home + "/Nowhere", context: context, checker: checker) == .missing)
        #expect(FolderList.availability(of: home + "/.Trash", context: context, checker: checker) == .offLimits)
        #expect(FolderList.availability(of: "/Applications/Inkpad.app/Contents", context: context, checker: checker) == .offLimits)
        #expect(FolderList.availability(of: "/Volumes/lab-share/x", context: context, checker: checker) == .network)
        #expect(FolderList.availability(of: "/Volumes/Gone", context: context, checker: checker) == .disconnected)
        #expect(FolderList.availability(of: "/Volumes", context: context, checker: FakeChecker(folders: ["/Volumes"])) == .ready)
        // With no mount table at all, a local folder is still checked.
        let bare = PathContext(home: home, mounts: [])
        #expect(FolderList.availability(of: home + "/Documents", context: bare, checker: checker) == .ready)
        #expect(FolderList.availability(of: "/Volumes/Field Drive", context: bare, checker: checker) == .disconnected)
        #expect(Availability.network.canJump && Availability.ready.canJump)
        #expect(![Availability.missing, .disconnected, .offLimits].contains { $0.canJump })
    }

    @Test func limitsPerSection() {
        let many = (0..<20).map { home + "/Documents/F\($0)" }
        let checker = FakeChecker(folders: Set(many))
        let list = build(finder: many, recents: many.reversed(), checker: checker)
        #expect(list.finder.count == FolderList.finderLimit)
        #expect(list.recents.count == FolderList.recentLimit)
        #expect(Set(list.finder.map(\.path)).isDisjoint(with: list.recents.map(\.path)))
    }

    @Test func badPathsAreDropped() {
        let list = build(finder: ["relative", "/bad\npath", home + "/Documents"], favorites: [""], recents: ["~/Desktop"])
        #expect(list.all.map(\.path) == [home + "/Documents"])
    }

    @Test func findsEntries() {
        let list = build(finder: [home + "/Downloads"])
        #expect(list.entry(home + "/Downloads")?.info.place == .downloads)
        #expect(list.entry("/nope") == nil)
    }
}

@Suite("Cycling")
struct CyclerTests {
    let folders = ["/a", "/b", "/c"]

    @Test func stepsAndWraps() {
        var cycler = Cycler()
        #expect(cycler.next(in: folders) == "/a")
        #expect(cycler.next(in: folders) == "/b")
        #expect(cycler.next(in: folders) == "/c")
        #expect(cycler.next(in: folders) == "/a")
    }

    @Test func goesBack() {
        var cycler = Cycler()
        #expect(cycler.next(in: folders, backwards: true) == "/c")
        #expect(cycler.next(in: folders, backwards: true) == "/b")
        #expect(cycler.next(in: folders) == "/c")
    }

    @Test func carriesOnFromAClick() {
        var cycler = Cycler()
        cycler.picked("/b")
        #expect(cycler.next(in: folders) == "/c")
    }

    @Test func startsOverWhenTheListChanges() {
        var cycler = Cycler(current: "/gone")
        #expect(cycler.next(in: folders) == "/a")
        cycler.reset()
        #expect(cycler.current == nil)
        #expect(cycler.next(in: []) == nil)
        #expect(cycler.next(in: ["/only"]) == "/only")
        #expect(cycler.next(in: ["/only"]) == "/only")
    }
}
