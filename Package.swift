// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Jase",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Jase", path: "Sources/Jase")]
)
