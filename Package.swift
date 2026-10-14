// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LemiShelf",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "LemiShelf", path: "Sources/LemiShelf")
    ]
)
