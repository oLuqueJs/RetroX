import Foundation
import Testing
@testable import RetroXCore

/// Abre de verdade um emulador falso, pelo LaunchServices e por exec direto, e confere o argv recebido.
/// Opt-in: `scripts/integration-launch.sh`. Não toca em emuladores nem em ROMs reais.
@Suite(.serialized, .enabled(if: FakeEmulatorBundle.binaryURL != nil))
struct LaunchIntegrationTests {
    /// Pasta com NFD, acentos, CJK e emoji; arquivo começando com hífen e com caracteres de shell.
    static let folder = "Jogos Ac\u{0327}a\u{0303}o ñ 日本 🎮"
    static let file = "-Teste $(echo x); 'q' \"a\" (USA).iso"

    @Test("argv chega byte a byte", arguments: LaunchStrategy.allCases)
    func argvArrivesIntact(strategy: LaunchStrategy) async throws {
        let fixture = try FakeEmulatorBundle()
        defer { fixture.remove() }
        let romURL = try fixture.makeROM(named: Self.file, inFolder: Self.folder)

        let launcher = GameLauncher()
        let prepared = try launcher.prepare(request(romURL: romURL, appURL: fixture.appURL, strategy: strategy))
        #expect(prepared.warnings == [.unexpectedBundleIdentifier(FakeEmulatorBundle.bundleIdentifier)])

        let launched = try await launcher.launch(prepared)
        let received = try await fixture.waitForArguments(pid: launched.pid)
        #expect(received.map { Array($0.utf8) } == prepared.plan.arguments.map { Array($0.utf8) })
        #expect(received.last.map { FileManager.default.fileExists(atPath: $0) } == true)

        let exit = await launched.waitForExit()
        #expect(exit != nil)
        if strategy == .process {
            #expect(exit?.status == 0)
        }
    }

    @Test("Com o app aberto, o LaunchServices reaproveita a instância e não entrega os novos argumentos")
    func workspaceReusesRunningInstance() async throws {
        let fixture = try FakeEmulatorBundle()
        defer { fixture.remove() }
        let firstROM = try fixture.makeROM(named: "Primeiro.iso", inFolder: "roms")
        let secondROM = try fixture.makeROM(named: "Segundo.iso", inFolder: "roms")

        let launcher = GameLauncher()
        let first = try await launcher.launch(launcher.prepare(request(romURL: firstROM, appURL: fixture.appURL)))
        _ = try await fixture.waitForArguments(pid: first.pid)

        // A validação já recusa o segundo launch...
        #expect(throws: LaunchError.emulatorAlreadyRunning(bundleID: FakeEmulatorBundle.bundleIdentifier)) {
            try launcher.prepare(request(romURL: secondROM, appURL: fixture.appURL))
        }

        // ...e este é o motivo: sem nova instância, o sistema só ativa o app que já está aberto.
        let firstPlan = first.plan
        let secondPlan = LaunchPlan(
            appURL: firstPlan.appURL,
            executableURL: firstPlan.executableURL,
            bundleIdentifier: firstPlan.bundleIdentifier,
            arguments: ["-batch", "--", secondROM.path(percentEncoded: false)],
            strategy: .workspace,
            activates: true,
            createsNewInstance: false
        )
        let second = try await WorkspaceLauncher().launch(secondPlan)
        #expect(second.pid == first.pid)
        try await Task.sleep(for: .seconds(1))
        #expect(try fixture.argumentFiles().count == 1)

        _ = await first.waitForExit()
    }

    private func request(romURL: URL, appURL: URL, strategy: LaunchStrategy = .workspace) -> LaunchRequest {
        let profile = EmulatorProfile(
            name: "Fake", adapterID: .pcsx2, appURL: appURL, options: PCSX2Adapter().defaultOptions, strategy: strategy
        )
        return LaunchRequest(romURL: romURL, systemID: .ps2, profile: profile)
    }
}
