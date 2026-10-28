import Foundation

public struct PCSX2Options: Codable, Sendable, Equatable {
    public enum Fullscreen: String, Codable, Sendable, CaseIterable {
        /// Não passa flag: vale a configuração do próprio PCSX2.
        case emulatorDefault
        case on
        case off
    }

    public enum Boot: String, Codable, Sendable, CaseIterable {
        case emulatorDefault
        case fast
        case slow
    }

    /// `-batch`: o PCSX2 fecha quando o jogo para, e o RetroX volta à frente.
    public var batch: Bool
    public var fullscreen: Fullscreen
    public var bigPicture: Bool
    public var boot: Boot

    public init(batch: Bool = true, fullscreen: Fullscreen = .emulatorDefault, bigPicture: Bool = false, boot: Boot = .emulatorDefault) {
        self.batch = batch
        self.fullscreen = fullscreen
        self.bigPicture = bigPicture
        self.boot = boot
    }
}

/// Flags conferidas no texto de ajuda do binário macOS do PCSX2 2.9.144:
/// `Usage: {} [parameters] [--] [boot filename]` (ver docs/spikes/0001-launch-pcsx2-macos.md).
public struct PCSX2Adapter: EmulatorAdapter {
    public let id = EmulatorAdapterID.pcsx2
    public let displayName = "PCSX2"
    public let expectedBundleIdentifiers: Set<String> = ["net.pcsx2.pcsx2"]
    public let supportedSystems: Set<GameSystemID> = [.ps2]
    public let defaultStrategy = LaunchStrategy.workspace
    public var defaultOptions: EmulatorOptions { .pcsx2(PCSX2Options()) }

    /// Flags que o RetroX gera, que trocariam o que é iniciado, ou que fazem o PCSX2 sair na hora.
    static let managedFlags: Set<String> = [
        "--", "-batch", "-nogui", "-fullscreen", "-nofullscreen", "-bigpicture", "-fastboot", "-slowboot",
        "-elf", "-disc", "-bios", "-help", "-version", "-testconfig",
    ]

    public init() {}

    public func supportedExtensions(for system: GameSystemID) -> Set<String> {
        system == .ps2 ? ["iso", "chd", "cso", "zso"] : []
    }

    public func arguments(romPath: String, options: EmulatorOptions, extraArguments: [String]) throws(LaunchError) -> [String] {
        let pcsx2: PCSX2Options
        switch options {
        case .pcsx2(let given): pcsx2 = given
        }
        try ExtraArguments.validate(extraArguments, managedFlags: Self.managedFlags)

        var arguments: [String] = []
        if pcsx2.batch { arguments.append("-batch") }
        switch pcsx2.fullscreen {
        case .emulatorDefault: break
        case .on: arguments.append("-fullscreen")
        case .off: arguments.append("-nofullscreen")
        }
        if pcsx2.bigPicture { arguments.append("-bigpicture") }
        switch pcsx2.boot {
        case .emulatorDefault: break
        case .fast: arguments.append("-fastboot")
        case .slow: arguments.append("-slowboot")
        }
        arguments += extraArguments
        // `--` encerra as opções: nomes com espaços ou iniciados por hífen chegam inteiros.
        arguments += ["--", romPath]
        return arguments
    }
}
