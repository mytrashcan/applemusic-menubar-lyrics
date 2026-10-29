// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusicLyricsBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MusicLyricsBar", targets: ["MusicLyricsBar"]),
        .library(name: "LyricsCore", targets: ["LyricsCore"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "LyricsCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "MusicLyricsBar", dependencies: ["LyricsCore"]),
        .testTarget(name: "LyricsCoreTests", dependencies: ["LyricsCore", "CSQLite"]),
        .testTarget(name: "MusicLyricsBarTests", dependencies: ["MusicLyricsBar"])
    ]
)
