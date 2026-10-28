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
    /// Itens visíveis de uma pasta, em ordem de nome. Vazio se a pasta não existe ou não pode ser lida.
    func contentsOfDirectory(at url: URL) -> [URL]
}

extension FileSystemProbing {
    func readText(of url: URL, maxLength: Int = 1 << 20) -> String? {
        (try? readPrefix(of: url, maxLength: maxLength)).map { String(decoding: $0, as: UTF8.self) }
    }
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

    public func contentsOfDirectory(at url: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return items.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
