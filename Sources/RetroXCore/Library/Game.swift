import Foundation

public struct Game: Identifiable, Hashable, Sendable {
    /// Caminho padronizado da ROM. Estável enquanto o arquivo não muda de lugar; a Fase 2 troca por UUID
    /// persistido com detecção de arquivo movido (ADR-0004, ADR-0013).
    public let id: String
    public let title: String
    public let systemID: GameSystemID
    public let pluginID: EmulatorPluginID
    public let romURL: URL
    public let fileSize: Int64
    public let coverURL: URL?
    public let searchKey: String

    public init(romURL: URL, systemID: GameSystemID, pluginID: EmulatorPluginID, fileSize: Int64, coverURL: URL?) {
        let title = TitleParser.displayTitle(fromFilename: romURL.lastPathComponent)
        self.id = romURL.standardizedFileURL.path(percentEncoded: false)
        self.title = title
        self.systemID = systemID
        self.pluginID = pluginID
        self.romURL = romURL
        self.fileSize = fileSize
        self.coverURL = coverURL
        self.searchKey = TitleParser.searchKey(title)
    }

    public var fileExtension: String { romURL.pathExtension.uppercased() }
}

/// O que o usuário fez com um jogo: favorito e histórico de partidas.
public struct GameHistory: Codable, Sendable, Equatable {
    public var isFavorite: Bool
    public var lastPlayedAt: Date?
    public var playCount: Int

    public init(isFavorite: Bool = false, lastPlayedAt: Date? = nil, playCount: Int = 0) {
        self.isFavorite = isFavorite
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
    }
}
