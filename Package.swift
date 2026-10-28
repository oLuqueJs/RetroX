// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RetroX",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "rx-fake-emulator", targets: ["RXFakeEmulator"]),
    ],
    targets: [
        // Regras de negócio, sem SwiftUI e sem SwiftData: compila e testa só com as Command Line Tools.
        .target(name: "RetroXCore"),
        // Ferramentas de desenvolvimento; não fazem parte do app distribuído.
        .executableTarget(name: "RXFakeEmulator"),
        .testTarget(name: "RetroXCoreTests", dependencies: ["RetroXCore"]),
    ]
)
