import Foundation

/// Identificador estável de um adapter. O valor bruto é persistido nos perfis.
public struct EmulatorAdapterID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let pcsx2 = EmulatorAdapterID(rawValue: "pcsx2")
}

/// Opções tipadas por emulador. Um caso por adapter, para o compilador cobrar cada novo emulador.
public enum EmulatorOptions: Codable, Sendable, Equatable {
    case pcsx2(PCSX2Options)
}

/// Conhecimento específico de um emulador: o que ele abre e como montar seus argumentos.
/// O adapter não executa nada; o `GameLauncher` valida e lança (ADR-0003).
public protocol EmulatorAdapter: Sendable {
    var id: EmulatorAdapterID { get }
    var displayName: String { get }
    var expectedBundleIdentifiers: Set<String> { get }
    var supportedSystems: Set<GameSystemID> { get }
    var defaultStrategy: LaunchStrategy { get }
    var defaultOptions: EmulatorOptions { get }

    /// Extensões (minúsculas, sem ponto) que este emulador abre para o sistema.
    func supportedExtensions(for system: GameSystemID) -> Set<String>

    /// argv sem o executável. O caminho da ROM é sempre um único elemento: nada passa por shell.
    func arguments(romPath: String, options: EmulatorOptions, extraArguments: [String]) throws(LaunchError) -> [String]
}

public struct EmulatorRegistry: Sendable {
    private let adapters: [EmulatorAdapterID: any EmulatorAdapter]

    public init(_ adapters: [any EmulatorAdapter]) {
        self.adapters = Dictionary(adapters.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public static let standard = EmulatorRegistry([PCSX2Adapter()])

    public func adapter(for id: EmulatorAdapterID) -> (any EmulatorAdapter)? {
        adapters[id]
    }

    public func adapters(for system: GameSystemID) -> [any EmulatorAdapter] {
        adapters.values.filter { $0.supportedSystems.contains(system) }.sorted { $0.displayName < $1.displayName }
    }
}

enum ExtraArguments {
    /// Recusa argumentos vazios, com NUL, ou que colidem com as flags controladas pelo adapter
    /// (incluindo a forma `--flag=valor`).
    static func validate(_ arguments: [String], managedFlags: Set<String>) throws(LaunchError) {
        for argument in arguments {
            let flag = argument.split(separator: "=", maxSplits: 1).first.map(String.init) ?? argument
            if argument.isEmpty || argument.contains("\0") || managedFlags.contains(flag) {
                throw .invalidExtraArgument(argument)
            }
        }
    }
}
