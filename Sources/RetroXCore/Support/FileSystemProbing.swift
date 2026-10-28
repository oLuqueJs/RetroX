import Foundation

public enum FileItemKind: Sendable, Equatable {
    case missing
    case regularFile
    case directory
}

/// Leituras de sistema de arquivos usadas na validação. Existe para os testes trocarem o disco por um fake.
public protocol FileSystemProbing: Sendable {
    /// Segue symlinks, como o emulador fará ao abrir o caminho.
    func kind(of url: URL) -> FileItemKind
    func isReadable(_ url: URL) -> Bool
    func isExecutable(_ url: URL) -> Bool
    func readPrefix(of url: URL, maxLength: Int) throws -> Data
}

public struct LocalFileSystem: FileSystemProbing {
    public init() {}

    public func kind(of url: URL) -> FileItemKind {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) else {
            return .missing
        }
        return isDirectory.boolValue ? .directory : .regularFile
    }

    public func isReadable(_ url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path(percentEncoded: false))
    }

    public func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path(percentEncoded: false))
    }

    public func readPrefix(of url: URL, maxLength: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: maxLength) ?? Data()
    }
}
