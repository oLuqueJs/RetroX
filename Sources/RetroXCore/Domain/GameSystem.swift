import Foundation

/// Identificador estável de um sistema (console). O valor bruto é persistido: não mude slugs existentes.
public struct GameSystemID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let ps1 = GameSystemID(rawValue: "ps1")
    public static let ps2 = GameSystemID(rawValue: "ps2")
    public static let ps3 = GameSystemID(rawValue: "ps3")
    public static let psp = GameSystemID(rawValue: "psp")
    public static let gamecube = GameSystemID(rawValue: "gamecube")
    public static let wii = GameSystemID(rawValue: "wii")
    public static let nds = GameSystemID(rawValue: "nds")
    public static let n3ds = GameSystemID(rawValue: "3ds")
    public static let gba = GameSystemID(rawValue: "gba")
    public static let snes = GameSystemID(rawValue: "snes")
    public static let n64 = GameSystemID(rawValue: "n64")
    public static let switchConsole = GameSystemID(rawValue: "switch")
}

public struct GameSystem: Hashable, Sendable, Identifiable {
    public let id: GameSystemID
    public let displayName: String
    public let shortName: String
    /// Formatos comuns do sistema (minúsculas, sem ponto). O que é indexado de fato depende do plugin ativo.
    public let fileExtensions: Set<String>
}

/// Catálogo de sistemas definido em código e versionado com o app (PRD §12). Estar no catálogo não
/// significa ter emulador: hoje só o PS2 tem plugin (PCSX2). Os outros aparecem no filtro de console.
public enum SystemCatalog {
    public static let ps2 = GameSystem(id: .ps2, displayName: "PlayStation 2", shortName: "PS2", fileExtensions: ["iso", "chd", "cso", "zso"])

    public static let all: [GameSystem] = [
        GameSystem(id: .ps1, displayName: "PlayStation", shortName: "PS1", fileExtensions: ["cue", "chd", "pbp", "m3u"]),
        ps2,
        GameSystem(id: .ps3, displayName: "PlayStation 3", shortName: "PS3", fileExtensions: ["iso", "pkg"]),
        GameSystem(id: .psp, displayName: "PSP", shortName: "PSP", fileExtensions: ["iso", "cso", "chd"]),
        GameSystem(id: .gamecube, displayName: "GameCube", shortName: "GC", fileExtensions: ["iso", "gcm", "rvz", "ciso", "gcz"]),
        GameSystem(id: .wii, displayName: "Wii", shortName: "Wii", fileExtensions: ["iso", "wbfs", "rvz", "wia"]),
        GameSystem(id: .nds, displayName: "Nintendo DS", shortName: "NDS", fileExtensions: ["nds"]),
        GameSystem(id: .n3ds, displayName: "Nintendo 3DS", shortName: "3DS", fileExtensions: ["3ds", "cci", "cia"]),
        GameSystem(id: .switchConsole, displayName: "Nintendo Switch", shortName: "Switch", fileExtensions: ["nsp", "xci"]),
        GameSystem(id: .gba, displayName: "Game Boy Advance", shortName: "GBA", fileExtensions: ["gba"]),
        GameSystem(id: .snes, displayName: "Super Nintendo", shortName: "SNES", fileExtensions: ["sfc", "smc"]),
        GameSystem(id: .n64, displayName: "Nintendo 64", shortName: "N64", fileExtensions: ["n64", "z64", "v64"]),
    ]

    public static func system(_ id: GameSystemID) -> GameSystem? {
        all.first { $0.id == id }
    }
}
