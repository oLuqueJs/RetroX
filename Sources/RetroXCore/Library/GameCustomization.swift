import CryptoKit
import Foundation

/// O que o usuário mudou num jogo, compartilhado entre perfis: capa própria e informações buscadas.
public struct GameCustomization: Codable, Sendable, Equatable {
    /// Nome do arquivo da capa dentro de `Artwork/`.
    public var coverFile: String?
    public var metadata: GameMetadata?

    public init(coverFile: String? = nil, metadata: GameMetadata? = nil) {
        self.coverFile = coverFile
        self.metadata = metadata
    }
}

public struct ArtworkStorage: Sendable {
    public let root: URL

    public init(root: URL = RetroXDirectories.applicationSupport) {
        self.root = root
    }

    public var customizations: JSONFileStore<[String: GameCustomization]> {
        JSONFileStore(url: root.appending(path: "games.json"))
    }

    public var artworkDirectory: URL {
        root.appending(path: "Artwork", directoryHint: .isDirectory)
    }

    public func coverURL(for customization: GameCustomization?) -> URL? {
        customization?.coverFile.map { artworkDirectory.appending(path: $0) }
    }

    /// Nome estável e sem caracteres problemáticos para a capa de um jogo.
    public static func coverFileName(for gameID: String) -> String {
        let digest = SHA256.hash(data: Data(gameID.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return "\(digest).png"
    }

    /// Copia a imagem escolhida como capa do jogo e devolve o nome do arquivo.
    public func importCover(from source: URL, for gameID: String) throws -> String {
        let name = Self.coverFileName(for: gameID)
        try ImageImporter.importPNG(from: source, to: artworkDirectory.appending(path: name), maxPixelSize: 1200)
        return name
    }
}
