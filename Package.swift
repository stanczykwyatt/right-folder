// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RightFolder",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RightFolder", targets: ["RightFolder"]),
    ],
    targets: [
        // Telling an Open or Save dialog apart from other windows, turning what Finder reports into
        // folder paths, the recent and favorite folders, what the panel lists and in what order,
        // where it sits, and how a jump is carried out, with nothing tied to the screen, so it can
        // be tested with recorded window data and made-up folders.
        .target(name: "FolderCore"),
        .executableTarget(name: "RightFolder", dependencies: ["FolderCore"]),
        .testTarget(name: "FolderCoreTests", dependencies: ["FolderCore"]),
        // The app's glue, tested with made-up folders and dialogs, and windows that are never shown.
        .testTarget(name: "RightFolderTests", dependencies: ["RightFolder", "FolderCore"]),
    ]
)
