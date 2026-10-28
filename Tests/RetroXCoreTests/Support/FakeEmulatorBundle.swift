import Foundation

/// Monta `FakeEmulator.app` num diretório temporário a partir do binário `rx-fake-emulator`.
/// O caminho do binário vem de `RX_FAKE_EMULATOR_BIN` (definido por `scripts/integration-launch.sh`).
struct FakeEmulatorBundle {
    static let bundleIdentifier = "local.retrox.fake-emulator"

    static var binaryURL: URL? {
        ProcessInfo.processInfo.environment["RX_FAKE_EMULATOR_BIN"].map { URL(filePath: $0) }
    }

    let root: URL
    let appURL: URL

    init() throws {
        guard let binaryURL = Self.binaryURL else { throw CocoaError(.fileNoSuchFile) }
        root = FileManager.default.temporaryDirectory
            .appending(path: "RetroXIntegration-\(UUID().uuidString)", directoryHint: .isDirectory)
        appURL = root.appending(path: "FakeEmulator.app", directoryHint: .isDirectory)
        let macOSURL = appURL.appending(path: "Contents/MacOS", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: binaryURL, to: macOSURL.appending(path: "FakeEmulator"))
        let plist: [String: Any] = [
            "CFBundleExecutable": "FakeEmulator",
            "CFBundleIdentifier": Self.bundleIdentifier,
            "CFBundleName": "FakeEmulator",
            "CFBundlePackageType": "APPL",
            "LSUIElement": true,
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: appURL.appending(path: "Contents/Info.plist"))
    }

    /// Cria um arquivo vazio com a extensão certa: o emulador falso não lê o conteúdo.
    func makeROM(named name: String, inFolder folder: String) throws -> URL {
        let folderURL = root.appending(path: folder, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let romURL = folderURL.appending(path: name, directoryHint: .notDirectory)
        guard FileManager.default.createFile(atPath: romURL.path(percentEncoded: false), contents: Data()) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return romURL
    }

    func argumentFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("argv-") }
    }

    func waitForArguments(pid: pid_t, timeout: Duration = .seconds(15)) async throws -> [String] {
        let fileURL = root.appending(path: "argv-\(pid).json")
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let data = try? Data(contentsOf: fileURL) {
                return try JSONDecoder().decode([String].self, from: data)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CocoaError(.fileReadNoSuchFile)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
