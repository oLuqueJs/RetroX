import Foundation

public struct AppBundleInfo: Sendable, Equatable {
    public let bundleURL: URL
    public let executableURL: URL
    public let bundleIdentifier: String?
    public let version: String?
    public let architectures: Set<CPUArchitecture>
}

/// Lê o Info.plist e o cabeçalho do executável de um `.app` sem carregá-lo (`Bundle(url:)` guardaria cache de versões antigas).
public struct AppBundleInspector: Sendable {
    private let fileSystem: any FileSystemProbing

    public init(fileSystem: any FileSystemProbing = LocalFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func inspect(_ bundleURL: URL) throws(LaunchError) -> AppBundleInfo {
        switch fileSystem.kind(of: bundleURL) {
        case .missing: throw .emulatorNotFound
        case .regularFile: throw .emulatorBundleInvalid
        case .directory: break
        }

        let contentsURL = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
        let plistURL = contentsURL.appending(path: "Info.plist", directoryHint: .notDirectory)
        guard let plistData = try? fileSystem.readPrefix(of: plistURL, maxLength: 4 << 20),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let executableName = plist["CFBundleExecutable"] as? String,
              !executableName.isEmpty, !executableName.contains("/")
        else { throw .emulatorBundleInvalid }

        let executableURL = contentsURL
            .appending(path: "MacOS", directoryHint: .isDirectory)
            .appending(path: executableName, directoryHint: .notDirectory)
        guard fileSystem.kind(of: executableURL) == .regularFile else { throw .emulatorBundleInvalid }
        guard fileSystem.isExecutable(executableURL) else { throw .emulatorNotExecutable }

        let header = (try? fileSystem.readPrefix(of: executableURL, maxLength: 4096)) ?? Data()
        return AppBundleInfo(
            bundleURL: bundleURL,
            executableURL: executableURL,
            bundleIdentifier: plist["CFBundleIdentifier"] as? String,
            version: (plist["CFBundleShortVersionString"] ?? plist["CFBundleVersion"]) as? String,
            architectures: MachOHeader.architectures(in: header)
        )
    }
}
