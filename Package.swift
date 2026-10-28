// swift-tools-version: 6.0
import PackageDescription
import Foundation

// Algumas versões das Command Line Tools não informam ao compilador onde encontrar
// as macros de Swift Testing. Aplique o caminho apenas ao target de testes e somente
// quando as CLT estiverem selecionadas; o Xcode encontra seu próprio plugin.
var testSwiftSettings: [SwiftSetting] = []
#if os(macOS)
let selectedDeveloperDirectory = ProcessInfo.processInfo.environment["DEVELOPER_DIR"].flatMap { $0.isEmpty ? nil : $0 }
    ?? (try? FileManager.default.destinationOfSymbolicLink(atPath: "/var/db/xcode_select_link"))
if let developerDirectory = selectedDeveloperDirectory {
    let directory = URL(fileURLWithPath: developerDirectory).standardizedFileURL
    let pluginDirectory = directory.appendingPathComponent("usr/lib/swift/host/plugins/testing").path
    if directory.lastPathComponent == "CommandLineTools", FileManager.default.fileExists(atPath: pluginDirectory) {
        testSwiftSettings.append(.unsafeFlags(["-plugin-path", pluginDirectory]))
    }
}
#endif

let package = Package(
    name: "RetroX",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RetroX", targets: ["RetroXApp"]),
        .executable(name: "rx-launch-probe", targets: ["RXLaunchProbe"]),
        .executable(name: "rx-fake-emulator", targets: ["RXFakeEmulator"]),
    ],
    targets: [
        // Regras de negócio, sem SwiftUI e sem SwiftData: compila e testa só com as Command Line Tools.
        .target(name: "RetroXCore"),
        .executableTarget(name: "RetroXApp", dependencies: ["RetroXCore"], resources: [.copy("Resources")]),
        // Ferramentas de desenvolvimento; não fazem parte do app distribuído.
        .executableTarget(name: "RXLaunchProbe", dependencies: ["RetroXCore"]),
        .executableTarget(name: "RXFakeEmulator"),
        .testTarget(name: "RetroXCoreTests", dependencies: ["RetroXCore"], swiftSettings: testSwiftSettings),
    ]
)
