import Foundation

/// Como o processo do emulador é criado. A escolha por adapter é registrada no ADR-0011.
public enum LaunchStrategy: String, Codable, Sendable, CaseIterable {
    /// `NSWorkspace.openApplication`: LaunchServices, ativação e TCC por conta do emulador.
    case workspace
    /// `Process`: exec direto do binário; dá exit status, mas o emulador vira filho do RetroX.
    case process
}

/// Configuração de um emulador escolhida pelo usuário.
public struct EmulatorProfile: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var adapterID: EmulatorAdapterID
    public var appURL: URL
    public var options: EmulatorOptions
    public var extraArguments: [String]
    /// `nil` usa a estratégia padrão do adapter.
    public var strategy: LaunchStrategy?

    public init(
        id: UUID = UUID(),
        name: String,
        adapterID: EmulatorAdapterID,
        appURL: URL,
        options: EmulatorOptions,
        extraArguments: [String] = [],
        strategy: LaunchStrategy? = nil
    ) {
        self.id = id
        self.name = name
        self.adapterID = adapterID
        self.appURL = appURL
        self.options = options
        self.extraArguments = extraArguments
        self.strategy = strategy
    }
}

public enum AlreadyRunningPolicy: Sendable, Equatable {
    /// Padrão: não abre outra instância; o usuário decide (ADR-0003, emenda).
    case refuse
    case launchNewInstance
}

public struct LaunchRequest: Sendable, Equatable {
    public var romURL: URL
    public var systemID: GameSystemID
    public var profile: EmulatorProfile
    public var alreadyRunningPolicy: AlreadyRunningPolicy

    public init(romURL: URL, systemID: GameSystemID, profile: EmulatorProfile, alreadyRunningPolicy: AlreadyRunningPolicy = .refuse) {
        self.romURL = romURL
        self.systemID = systemID
        self.profile = profile
        self.alreadyRunningPolicy = alreadyRunningPolicy
    }
}

/// Tudo o que é preciso para abrir o emulador, já validado. Puro: é o que o modo simulado mostra.
public struct LaunchPlan: Sendable, Equatable {
    public let appURL: URL
    public let executableURL: URL
    public let bundleIdentifier: String?
    /// argv sem o executável.
    public let arguments: [String]
    public let strategy: LaunchStrategy
    public let activates: Bool
    public let createsNewInstance: Bool
}

public enum LaunchWarning: Sendable, Equatable {
    case unexpectedBundleIdentifier(String?)
    case runsUnderRosetta
    case unknownArchitecture

    public var message: String {
        switch self {
        case .unexpectedBundleIdentifier(let found):
            String(localized: "O app escolhido não se identifica como o emulador esperado (\(found ?? "sem identificador")).")
        case .runsUnderRosetta:
            String(localized: "Este emulador roda via Rosetta neste Mac.")
        case .unknownArchitecture:
            String(localized: "Não foi possível conferir a arquitetura do emulador.")
        }
    }
}

public struct PreparedLaunch: Sendable, Equatable {
    public let plan: LaunchPlan
    public let app: AppBundleInfo
    public let warnings: [LaunchWarning]
}

public struct ProcessExit: Sendable, Equatable {
    /// Só disponível quando o emulador é filho do RetroX (estratégia `process`).
    public let status: Int32?
    public let endedAt: Date

    public init(status: Int32?, endedAt: Date) {
        self.status = status
        self.endedAt = endedAt
    }
}

public struct LaunchedProcess: Sendable {
    public let pid: pid_t
    public let launchedAt: Date
    public let plan: LaunchPlan
    /// Entrega um único `ProcessExit` quando o processo termina. Tem um só consumidor.
    public let exits: AsyncStream<ProcessExit>

    public init(pid: pid_t, launchedAt: Date, plan: LaunchPlan, exits: AsyncStream<ProcessExit>) {
        self.pid = pid
        self.launchedAt = launchedAt
        self.plan = plan
        self.exits = exits
    }

    public func waitForExit() async -> ProcessExit? {
        for await exit in exits { return exit }
        return nil
    }
}

/// Como terminou uma sessão de jogo, do ponto de vista do RetroX.
public enum SessionOutcome: Sendable, Equatable {
    case ended(after: Duration)
    /// Fechou cedo demais para ter sido uma partida: provável falha (BIOS, formato, configuração).
    case exitedEarly(status: Int32?, after: Duration)

    public static let earlyExitWindow: Duration = .seconds(5)

    public static func classify(launchedAt: Date, exit: ProcessExit, earlyExitWindow: Duration = earlyExitWindow) -> SessionOutcome {
        let elapsed = Duration.milliseconds(Int64((exit.endedAt.timeIntervalSince(launchedAt) * 1000).rounded()))
        return elapsed < earlyExitWindow ? .exitedEarly(status: exit.status, after: elapsed) : .ended(after: elapsed)
    }
}

public protocol ProcessLaunching: Sendable {
    func launch(_ plan: LaunchPlan) async throws(LaunchError) -> LaunchedProcess
}
