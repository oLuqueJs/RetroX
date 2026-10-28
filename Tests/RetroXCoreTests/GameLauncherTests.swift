import Foundation
import Testing
@testable import RetroXCore

struct GameLauncherPrepareTests {
    @Test("Monta o plano do PCSX2 e avisa que roda via Rosetta")
    func preparesPlan() throws {
        let scenario = LaunchScenario()
        let prepared = try scenario.launcher().prepare(scenario.request)
        #expect(prepared.plan.arguments == ["-batch", "--", scenario.romPath])
        #expect(prepared.plan.executableURL.path(percentEncoded: false) == "/Apps/PCSX2.app/Contents/MacOS/PCSX2")
        #expect(prepared.plan.bundleIdentifier == "net.pcsx2.pcsx2")
        #expect(prepared.plan.strategy == .workspace)
        #expect(prepared.plan.activates)
        #expect(!prepared.plan.createsNewInstance)
        #expect(prepared.warnings == [.runsUnderRosetta])
    }

    @Test("Estratégia do perfil prevalece sobre a do adapter")
    func profileStrategyWins() throws {
        var scenario = LaunchScenario()
        scenario.profile.strategy = .process
        #expect(try scenario.launcher().prepare(scenario.request).plan.strategy == .process)
    }

    @Test("Extensão em maiúsculas é aceita")
    func uppercaseExtension() throws {
        var scenario = LaunchScenario()
        scenario.romPath = "/Jogos/GT4.ISO"
        scenario.disk[scenario.romPath] = .file()
        #expect(try scenario.launcher().prepare(scenario.request).plan.arguments.last == "/Jogos/GT4.ISO")
    }

    @Test("Universal nativo não gera aviso")
    func nativeUniversal() throws {
        var scenario = LaunchScenario()
        scenario.disk.addAppBundle(at: scenario.appPath, executable: "PCSX2", header: MachOSamples.universal)
        #expect(try scenario.launcher().prepare(scenario.request).warnings.isEmpty)
    }

    @Test("Bundle ID inesperado e arquitetura desconhecida viram avisos, não erros")
    func softWarnings() throws {
        var scenario = LaunchScenario()
        scenario.disk.addAppBundle(
            at: scenario.appPath, executable: "PCSX2", bundleIdentifier: "org.exemplo.outro", header: MachOSamples.shellScript
        )
        let warnings = try scenario.launcher().prepare(scenario.request).warnings
        #expect(warnings == [.unexpectedBundleIdentifier("org.exemplo.outro"), .unknownArchitecture])
    }

    @Test("Emulador já aberto: recusa por padrão")
    func refusesWhenRunning() {
        var scenario = LaunchScenario()
        scenario.running.running = ["net.pcsx2.pcsx2"]
        #expect(throws: LaunchError.emulatorAlreadyRunning(bundleID: "net.pcsx2.pcsx2")) {
            try scenario.launcher().prepare(scenario.request)
        }
    }

    @Test("Emulador já aberto: nova instância só se pedida")
    func newInstanceWhenAsked() throws {
        var scenario = LaunchScenario()
        scenario.running.running = ["net.pcsx2.pcsx2"]
        var request = scenario.request
        request.alreadyRunningPolicy = .launchNewInstance
        #expect(try scenario.launcher().prepare(request).plan.createsNewInstance)
    }

    @Test("Erros de ROM")
    func romErrors() {
        var scenario = LaunchScenario()
        scenario.disk[scenario.romPath] = nil
        #expect(throws: LaunchError.romNotFound) { try scenario.launcher().prepare(scenario.request) }

        scenario.disk[scenario.romPath] = .directory
        #expect(throws: LaunchError.romIsDirectory) { try scenario.launcher().prepare(scenario.request) }

        scenario.disk[scenario.romPath] = .file(readable: false)
        #expect(throws: LaunchError.romUnreadable) { try scenario.launcher().prepare(scenario.request) }

        scenario.romPath = "/Jogos/jogo.zip"
        scenario.disk[scenario.romPath] = .file()
        #expect(throws: LaunchError.unsupportedFormat("zip")) { try scenario.launcher().prepare(scenario.request) }
    }

    @Test("Erros de emulador")
    func emulatorErrors() {
        var scenario = LaunchScenario()
        scenario.profile.appURL = URL(filePath: "/Apps/Inexistente.app")
        #expect(throws: LaunchError.emulatorNotFound) { try scenario.launcher().prepare(scenario.request) }

        scenario = LaunchScenario()
        scenario.profile.adapterID = EmulatorAdapterID(rawValue: "desconhecido")
        #expect(throws: LaunchError.emulatorNotConfigured(.ps2)) { try scenario.launcher().prepare(scenario.request) }

        scenario = LaunchScenario()
        let wii = GameSystemID(rawValue: "wii")
        var request = scenario.request
        request.systemID = wii
        #expect(throws: LaunchError.emulatorDoesNotSupportSystem(wii)) { try scenario.launcher().prepare(request) }

        scenario = LaunchScenario()
        scenario.profile.extraArguments = ["-batch"]
        #expect(throws: LaunchError.invalidExtraArgument("-batch")) { try scenario.launcher().prepare(scenario.request) }
    }

    @Test("Arquitetura: sem Rosetta e Intel com app só arm64")
    func architectureErrors() {
        var scenario = LaunchScenario()
        scenario.host.isRosettaInstalled = false
        #expect(throws: LaunchError.architectureUnsupported(rosettaMissing: true)) {
            try scenario.launcher().prepare(scenario.request)
        }

        scenario = LaunchScenario()
        scenario.host = HostEnvironment(architecture: .x86_64, isRosettaInstalled: false)
        scenario.disk.addAppBundle(at: scenario.appPath, executable: "PCSX2", header: MachOSamples.thinARM64)
        #expect(throws: LaunchError.architectureUnsupported(rosettaMissing: false)) {
            try scenario.launcher().prepare(scenario.request)
        }
    }
}

struct GameLauncherLaunchTests {
    @Test("Entrega ao launcher exatamente o plano validado")
    func launchesPreparedPlan() async throws {
        let scenario = LaunchScenario()
        let recording = RecordingLauncher()
        let launcher = scenario.launcher(recording: recording)
        let prepared = try launcher.prepare(scenario.request)
        let launched = try await launcher.launch(prepared)
        #expect(launched.pid == 4242)
        #expect(await recording.plans == [prepared.plan])
        #expect(await launched.waitForExit()?.status == 0)
    }

    @Test("Estratégia sem launcher registrado falha com mensagem")
    func missingStrategy() async throws {
        let scenario = LaunchScenario()
        let launcher = GameLauncher(
            fileSystem: scenario.disk, host: scenario.host, runningApplications: scenario.running, launchers: [:]
        )
        let prepared = try launcher.prepare(scenario.request)
        await #expect(throws: LaunchError.self) { try await launcher.launch(prepared) }
    }
}

struct SessionOutcomeTests {
    let start = Date(timeIntervalSince1970: 1_000)

    @Test("Saída antes de 5 s é falha provável; depois é sessão normal")
    func classifies() {
        #expect(SessionOutcome.classify(launchedAt: start, exit: ProcessExit(status: 1, endedAt: start + 1.5))
            == .exitedEarly(status: 1, after: .milliseconds(1500)))
        #expect(SessionOutcome.classify(launchedAt: start, exit: ProcessExit(status: nil, endedAt: start + 600))
            == .ended(after: .seconds(600)))
        #expect(SessionOutcome.classify(launchedAt: start, exit: ProcessExit(status: 0, endedAt: start + 5))
            == .ended(after: .seconds(5)))
    }
}
