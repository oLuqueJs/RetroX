import Foundation

/// Ações de correção oferecidas junto com cada erro (RNF-06).
public enum RecoveryAction: Sendable, Hashable {
    case chooseEmulator
    case locateROM
    case retry
    case openSettings
    case bringEmulatorToFront
    case showRosettaHelp

    public var title: String {
        switch self {
        case .chooseEmulator: String(localized: "Escolher emulador")
        case .locateROM: String(localized: "Localizar arquivo")
        case .retry: String(localized: "Tentar novamente")
        case .openSettings: String(localized: "Abrir ajustes")
        case .bringEmulatorToFront: String(localized: "Trazer emulador para frente")
        case .showRosettaHelp: String(localized: "Como instalar o Rosetta")
        }
    }
}

public enum LaunchError: Error, Sendable, Equatable {
    case emulatorNotConfigured(GameSystemID)
    case emulatorDoesNotSupportSystem(GameSystemID)
    case emulatorNotFound
    case emulatorBundleInvalid
    case emulatorNotExecutable
    case architectureUnsupported(rosettaMissing: Bool)
    case romNotFound
    case romIsDirectory
    case romUnreadable
    case unsupportedFormat(String)
    case emulatorAlreadyRunning(bundleID: String)
    case invalidExtraArgument(String)
    case launchFailed(String)
    case exitedEarly(status: Int32?, after: Duration)

    public var message: String {
        switch self {
        case .emulatorNotConfigured(let system):
            String(localized: "Nenhum emulador configurado para \(Self.name(of: system)).")
        case .emulatorDoesNotSupportSystem(let system):
            String(localized: "O emulador escolhido não abre jogos de \(Self.name(of: system)).")
        case .emulatorNotFound:
            String(localized: "O emulador não foi encontrado no local configurado.")
        case .emulatorBundleInvalid:
            String(localized: "O item escolhido não parece ser um app de emulador válido.")
        case .emulatorNotExecutable:
            String(localized: "O macOS não permite executar o emulador escolhido.")
        case .architectureUnsupported(rosettaMissing: true):
            String(localized: "Este emulador foi feito para Mac com Intel e precisa do Rosetta, que não está instalado.")
        case .architectureUnsupported(rosettaMissing: false):
            String(localized: "Este emulador não roda na arquitetura deste Mac.")
        case .romNotFound:
            String(localized: "O arquivo do jogo não foi encontrado.")
        case .romIsDirectory:
            String(localized: "O item escolhido é uma pasta, não um arquivo de jogo.")
        case .romUnreadable:
            String(localized: "Sem permissão para ler o arquivo do jogo.")
        case .unsupportedFormat(let fileExtension):
            String(localized: "O formato “.\(fileExtension)” não é aberto por este emulador.")
        case .emulatorAlreadyRunning:
            String(localized: "O emulador já está aberto. Feche o jogo atual antes de abrir outro.")
        case .invalidExtraArgument(let argument):
            String(localized: "O argumento extra “\(argument)” não é permitido.")
        case .launchFailed(let reason):
            String(localized: "Não foi possível abrir o emulador: \(reason)")
        case .exitedEarly:
            String(localized: "O emulador fechou logo depois de abrir. Confira a BIOS e as configurações dele.")
        }
    }

    public var recoveryActions: [RecoveryAction] {
        switch self {
        case .emulatorNotConfigured, .emulatorDoesNotSupportSystem, .emulatorNotFound,
             .emulatorBundleInvalid, .emulatorNotExecutable, .architectureUnsupported(rosettaMissing: false):
            [.chooseEmulator]
        case .architectureUnsupported(rosettaMissing: true):
            [.showRosettaHelp, .chooseEmulator]
        case .romNotFound, .romIsDirectory, .romUnreadable:
            [.locateROM]
        case .unsupportedFormat:
            [.chooseEmulator, .locateROM]
        case .emulatorAlreadyRunning:
            [.bringEmulatorToFront]
        case .invalidExtraArgument:
            [.openSettings]
        case .launchFailed, .exitedEarly:
            [.retry, .openSettings]
        }
    }

    private static func name(of system: GameSystemID) -> String {
        SystemCatalog.system(system)?.shortName ?? system.rawValue
    }
}

extension LaunchError: LocalizedError {
    public var errorDescription: String? { message }
}
