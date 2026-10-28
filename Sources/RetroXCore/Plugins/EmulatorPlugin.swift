import Foundation

/// Identificador estável de um plugin de emulador. O valor bruto é persistido na configuração.
public struct EmulatorPluginID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let pcsx2 = EmulatorPluginID(rawValue: "pcsx2")
}

/// Um emulador que o usuário ativa no RetroX (ADR-0013). O plugin sabe encontrar o emulador e os jogos
/// a partir de uma pasta raiz, e entrega um `EmulatorAdapter` para abrir cada jogo.
public protocol EmulatorPlugin: Sendable {
    var id: EmulatorPluginID { get }
    var displayName: String { get }
    var summary: String { get }
    var systems: [GameSystemID] { get }
    var adapter: any EmulatorAdapter { get }

    /// Inspeciona a pasta raiz escolhida pelo usuário. Só lê; pode demorar em discos lentos, então
    /// deve ser chamado fora da main thread.
    func discover(root: URL) -> PluginDiscovery
}

public struct ROMDirectory: Sendable, Equatable, Hashable {
    public enum Origin: Sendable, Equatable, Hashable {
        /// Pasta encontrada dentro da pasta raiz do emulador.
        case rootFolder
        /// Pasta que o próprio emulador já conhece pela configuração dele.
        case emulatorSettings
    }

    public let url: URL
    public let origin: Origin
    public let isRecursive: Bool

    public init(url: URL, origin: Origin, isRecursive: Bool) {
        self.url = url
        self.origin = origin
        self.isRecursive = isRecursive
    }
}

public enum PluginIssue: Sendable, Equatable {
    case rootNotFound
    case appNotFound
    case noROMDirectories
    case settingsFolderMissing(String)

    public var message: String {
        switch self {
        case .rootNotFound:
            String(localized: "A pasta escolhida não existe mais ou não pode ser lida.")
        case .appNotFound:
            String(localized: "Nenhum app do emulador foi encontrado nesta pasta.")
        case .noROMDirectories:
            String(localized: "Nenhuma pasta de jogos encontrada (por exemplo, “roms”).")
        case .settingsFolderMissing(let path):
            String(localized: "A configuração do emulador aponta para uma pasta que não existe: \(path)")
        }
    }
}

public struct PluginDiscovery: Sendable, Equatable {
    public enum BIOSStatus: Sendable, Equatable {
        case configured(String)
        case fileMissing(String)
        case notConfigured
        /// O emulador ainda não tem configuração (nunca foi aberto ou é outra instalação).
        case unknown
    }

    public var root: URL
    public var app: AppBundleInfo?
    public var romDirectories: [ROMDirectory] = []
    public var coverDirectories: [URL] = []
    public var settingsFile: URL?
    public var bios: BIOSStatus = .unknown
    public var issues: [PluginIssue] = []

    public init(root: URL) {
        self.root = root
    }

    public var isReady: Bool { app != nil && !romDirectories.isEmpty }
}

/// Configuração de um plugin escolhida pelo usuário, persistida entre sessões.
public struct PluginConfig: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var rootPath: String?

    public init(isEnabled: Bool = false, rootPath: String? = nil) {
        self.isEnabled = isEnabled
        self.rootPath = rootPath
    }
}

/// Plugins que o RetroX oferece. Os "em breve" aparecem na tela de emuladores, mas não podem ser ativados.
public enum PluginCatalog {
    public struct Upcoming: Sendable, Identifiable {
        public let id: String
        public let name: String
        public let systems: String
    }

    public static let available: [any EmulatorPlugin] = [PCSX2Plugin()]

    public static let upcoming: [Upcoming] = [
        Upcoming(id: "dolphin", name: "Dolphin", systems: "GameCube · Wii"),
    ]
}
