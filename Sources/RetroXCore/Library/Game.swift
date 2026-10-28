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
    /// Serial do disco ("SLUS-21490"), quando o formato permite ler.
    public let serial: String?
    /// O que o banco de dados do emulador sabe pelo serial (nome oficial, região, compatibilidade).
    public let info: GameIndexEntry?
    public let coverURL: URL?
    public let searchKey: String

    public init(
        romURL: URL, systemID: GameSystemID, pluginID: EmulatorPluginID, fileSize: Int64,
        serial: String? = nil, info: GameIndexEntry? = nil, coverURL: URL?
    ) {
        let title = TitleParser.displayTitle(fromFilename: romURL.lastPathComponent)
        self.id = romURL.standardizedFileURL.path(percentEncoded: false)
        self.title = title
        self.systemID = systemID
        self.pluginID = pluginID
        self.romURL = romURL
        self.fileSize = fileSize
        self.serial = serial
        self.info = info
        self.coverURL = coverURL
        self.searchKey = TitleParser.searchKey(title)
    }

    public var fileExtension: String { romURL.pathExtension.uppercased() }

    /// O mesmo jogo com outra capa (por exemplo, a escolhida pelo usuário).
    public func withCover(_ url: URL?) -> Game {
        Game(romURL: romURL, systemID: systemID, pluginID: pluginID, fileSize: fileSize, serial: serial, info: info, coverURL: url)
    }

    /// Título para buscar informações: o nome oficial do emulador, se houver; senão, o do arquivo sem marcas.
    public var searchTitle: String {
        info?.name ?? TitleParser.searchTitle(title)
    }
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
