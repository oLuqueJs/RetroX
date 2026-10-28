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

/// Como o controle está configurado no emulador (primeira porta).
public struct ControllerSummary: Sendable, Equatable {
    public struct Binding: Sendable, Equatable, Hashable {
        public let button: String
        public let input: String
    }

    public var type: String
    /// Dispositivo das associações, por exemplo "SDL-0".
    public var device: String?
    public var bindings: [Binding]
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
    public var controller: ControllerSummary?
    /// Banco de dados de jogos do emulador (no PCSX2, `GameIndex.yaml` dentro do app).
    public var gameIndexFile: URL?
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

/// Plugins que o RetroX oferece, e outros emuladores que ele reconhece (ainda sem plugin).
public enum PluginCatalog {
    /// Emulador conhecido sem plugin: aparece em Emuladores se estiver instalado (ou se o plugin estiver planejado).
    public struct KnownEmulator: Sendable, Identifiable {
        public let id: String
        public let name: String
        public let systems: String
        /// Bundle IDs para procurar o app instalado pelo LaunchServices.
        public let bundleIdentifiers: [String]
        /// Plugin no plano (PRD); aparece mesmo sem estar instalado.
        public let isPlanned: Bool
    }

    public static let available: [any EmulatorPlugin] = [PCSX2Plugin()]

    public static let known: [KnownEmulator] = [
        KnownEmulator(id: "dolphin", name: "Dolphin", systems: "GameCube · Wii", bundleIdentifiers: ["org.dolphin-emu.dolphin"], isPlanned: true),
        KnownEmulator(id: "ryujinx", name: "Ryujinx", systems: "Switch", bundleIdentifiers: ["org.ryujinx.Ryujinx"], isPlanned: false),
        KnownEmulator(id: "rpcs3", name: "RPCS3", systems: "PS3", bundleIdentifiers: ["net.rpcs3.rpcs3"], isPlanned: false),
        KnownEmulator(id: "ppsspp", name: "PPSSPP", systems: "PSP", bundleIdentifiers: ["org.ppsspp.ppsspp"], isPlanned: false),
        KnownEmulator(id: "duckstation", name: "DuckStation", systems: "PS1", bundleIdentifiers: ["com.github.stenzek.duckstation"], isPlanned: false),
        KnownEmulator(id: "melonds", name: "melonDS", systems: "NDS", bundleIdentifiers: ["net.kuribo64.melonDS"], isPlanned: false),
        KnownEmulator(id: "cemu", name: "Cemu", systems: "Wii U", bundleIdentifiers: ["info.cemu.Cemu"], isPlanned: false),
    ]
}
