// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RetroX",
    platforms: [.macOS(.v14)],
    targets: [
        // Regras de negócio, sem SwiftUI e sem SwiftData: compila e testa só com as Command Line Tools.
        .target(name: "RetroXCore"),
        .testTarget(name: "RetroXCoreTests", dependencies: ["RetroXCore"]),
    ]
)
