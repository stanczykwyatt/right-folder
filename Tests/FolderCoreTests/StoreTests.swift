import Foundation
import Testing
@testable import FolderCore

@Suite("Recent folders")
struct RecentTests {
    @Test func newestFirstAndOnce() {
        var recents = RecentFolders()
        recents.add("/a")
        recents.add("/b")
        recents.add("/a/")
        #expect(recents.paths == ["/a", "/b"])
    }

    @Test func keepsOnlyTheLatest() {
        var recents = RecentFolders()
        for index in 0..<30 { recents.add("/folder\(index)") }
        #expect(recents.paths.count == RecentFolders.limit)
        #expect(recents.paths.first == "/folder29")
        #expect(recents.paths.last == "/folder18")
    }

    @Test func ignoresUnusablePaths() {
        var recents = RecentFolders()
        recents.add("relative")
        recents.add("/bad\npath")
        recents.add("")
        #expect(recents.paths.isEmpty)
    }

    @Test func removeAndClear() {
        var recents = RecentFolders(paths: ["/a", "/b", "/c"])
        recents.remove("/b")
        #expect(recents.paths == ["/a", "/c"])
        recents.clear()
        #expect(recents.paths.isEmpty)
    }

    @Test func savedListsAreCleanedOnLoad() throws {
        let json = #"{"paths": ["/a", "/a", "relative", "/b\n", "/c/", "/d"]}"#
        let recents = try JSONDecoder().decode(RecentFolders.self, from: Data(json.utf8))
        #expect(recents.paths == ["/a", "/c", "/d"])
        let damaged = try JSONDecoder().decode(RecentFolders.self, from: Data(#"{"paths": 7}"#.utf8))
        #expect(damaged.paths.isEmpty)
        let initialized = RecentFolders(paths: (0..<20).map { "/f\($0)" })
        #expect(initialized.paths.first == "/f0" && initialized.paths.count == RecentFolders.limit)
    }

    @Test func roundTrips() throws {
        let recents = RecentFolders(paths: ["/Users/robin/Documents", "/Volumes/Field Drive"])
        let data = try JSONEncoder().encode(recents)
        #expect(try JSONDecoder().decode(RecentFolders.self, from: data) == recents)
    }
}

@Suite("Favorites")
struct FavoriteTests {
    @Test func addsOnceInOrder() {
        var favorites = Favorites()
        let added = [
            favorites.add(Favorite(path: "/b")), favorites.add(Favorite(path: "/a/")),
            favorites.add(Favorite(path: "/a")), favorites.add(Favorite(path: "not/absolute")),
        ]
        #expect(added == [true, true, false, false])
        #expect(favorites.paths == ["/b", "/a"])
    }

    @Test func hasALimit() {
        var favorites = Favorites()
        for index in 0..<Favorites.limit { favorites.add(Favorite(path: "/f\(index)")) }
        let added = favorites.add(Favorite(path: "/one-more"))
        #expect(!added)
        #expect(favorites.items.count == Favorites.limit)
    }

    @Test func movesAndRemoves() {
        var favorites = Favorites(items: ["/a", "/b", "/c"].map { Favorite(path: $0) })
        favorites.move("/c", by: -1)
        #expect(favorites.paths == ["/a", "/c", "/b"])
        favorites.move("/a", by: -5)
        #expect(favorites.paths == ["/a", "/c", "/b"])
        favorites.move("/a", by: 10)
        #expect(favorites.paths == ["/c", "/b", "/a"])
        favorites.move("/missing", by: 1)
        favorites.remove("/b")
        #expect(favorites.paths == ["/c", "/a"])
    }

    @Test func followsRenamedFolders() {
        var favorites = Favorites(items: [Favorite(path: "/Users/robin/Thesis", bookmark: Data([1])), Favorite(path: "/Users/robin/Notes", bookmark: Data([2]))])
        let changed = favorites.follow { item in
            item.bookmark == Data([1]) ? ("/Users/robin/Documents/Thesis (final)", Data([9])) : (item.path, nil)
        }
        #expect(changed)
        #expect(favorites.paths == ["/Users/robin/Documents/Thesis (final)", "/Users/robin/Notes"])
        #expect(favorites.items[0].bookmark == Data([9]))
        #expect(favorites.items[1].bookmark == Data([2]))
        // Nothing moved: nothing changes.
        let again = favorites.follow { ($0.path, nil) }
        #expect(!again)
    }

    @Test func aMoveOntoAnotherFavoriteDropsTheDuplicate() {
        var favorites = Favorites(items: [Favorite(path: "/a", bookmark: Data([1])), Favorite(path: "/b", bookmark: Data([2]))])
        let changed = favorites.follow { $0.path == "/b" ? ("/a", nil) : nil }
        #expect(changed)
        #expect(favorites.paths == ["/a"])
    }

    @Test func unresolvedBookmarksKeepTheirPath() {
        var favorites = Favorites(items: [Favorite(path: "/Volumes/Old Drive/Photos", bookmark: Data([3]))])
        let unresolved = favorites.follow { _ in nil }
        #expect(!unresolved)
        #expect(favorites.paths == ["/Volumes/Old Drive/Photos"])
        // A bookmark that resolves somewhere unusable is ignored too.
        let unusable = favorites.follow { _ in ("relative/path", nil) }
        #expect(!unusable)
    }

    @Test func savedListsSurviveDamage() throws {
        let json = #"{"items": [{"path": "/a"}, {"nope": 1}, {"path": "/a"}, {"path": "relative"}, {"path": "/b", "bookmark": "AQI="}]}"#
        let favorites = try JSONDecoder().decode(Favorites.self, from: Data(json.utf8))
        #expect(favorites.paths == ["/a", "/b"])
        #expect(favorites.items[1].bookmark == Data([1, 2]))
        #expect(try JSONDecoder().decode(Favorites.self, from: Data("{}".utf8)).items.isEmpty)
    }

    @Test func roundTrips() throws {
        let favorites = Favorites(items: [Favorite(path: "/a", bookmark: Data([1, 2, 3])), Favorite(path: "/b")])
        let data = try JSONEncoder().encode(favorites)
        #expect(try JSONDecoder().decode(Favorites.self, from: data) == favorites)
    }
}
