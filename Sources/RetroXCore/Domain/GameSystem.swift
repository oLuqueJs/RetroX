import Foundation

/// Identificador estável de um sistema (console). O valor bruto é persistido: não mude slugs existentes.
public struct GameSystemID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let ps2 = GameSystemID(rawValue: "ps2")
}

public struct GameSystem: Hashable, Sendable, Identifiable {
    public let id: GameSystemID
    public let displayName: String
    public let shortName: String
    /// Extensões (minúsculas, sem ponto) que o RetroX indexa para este sistema.
    public let fileExtensions: Set<String>
}

/// Catálogo de sistemas definido em código e versionado com o app (PRD §12).
public enum SystemCatalog {
    public static let ps2 = GameSystem(
        id: .ps2,
        displayName: "PlayStation 2",
        shortName: "PS2",
        fileExtensions: ["iso", "chd", "cso", "zso"]
    )

    public static let all: [GameSystem] = [ps2]

    public static func system(_ id: GameSystemID) -> GameSystem? {
        all.first { $0.id == id }
    }
}
