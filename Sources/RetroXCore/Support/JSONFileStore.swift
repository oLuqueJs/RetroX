import Foundation

/// Configurações pequenas do RetroX em JSON (plugins ativos, favoritos, histórico).
/// A biblioteca completa vai para o SwiftData na Fase 2 (ADR-0005); isto cobre o que precisa sobreviver até lá.
public struct JSONFileStore<Value: Codable>: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `nil` se o arquivo não existe ou não pôde ser lido; quem chama decide o valor padrão.
    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Value.self, from: data)
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}

public enum RetroXDirectories {
    public static var applicationSupport: URL {
        URL.applicationSupportDirectory.appending(path: "RetroX", directoryHint: .isDirectory)
    }
}
