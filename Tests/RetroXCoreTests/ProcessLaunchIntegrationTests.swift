import Foundation
import Testing
@testable import RetroXCore

/// Processo filho real e binário controlado, sem GUI, BIOS ou jogo.
@Suite(.timeLimit(.minutes(1)), .enabled(if: FakeEmulatorBundle.binaryURL != nil))
struct ProcessLaunchIntegrationTests {
    @Test("Preserva argv e observa término imediato, inclusive com erro", arguments: [Int32(0), 17])
    func immediateExit(status: Int32) async throws {
        let fixture = try FakeEmulatorBundle()
        defer { fixture.remove() }
        let rom = try fixture.makeROM(named: LaunchIntegrationTests.file, inFolder: LaunchIntegrationTests.folder)
        let arguments = ["--rx-headless-exit=\(status)", "--", rom.path(percentEncoded: false)]
        let plan = LaunchPlan(
            appURL: fixture.appURL,
            executableURL: fixture.appURL.appending(path: "Contents/MacOS/FakeEmulator"),
            bundleIdentifier: FakeEmulatorBundle.bundleIdentifier,
            arguments: arguments, strategy: .process, activates: false, createsNewInstance: true
        )
        let launched = try await FoundationProcessLauncher().launch(plan)
        let exit = try #require(await launched.waitForExit())
        #expect(exit.status == status)
        let received = try await fixture.waitForArguments(pid: launched.pid)
        #expect(received.map { Array($0.utf8) } == arguments.map { Array($0.utf8) })
        #expect(await launched.waitForExit() == nil)
        #expect(try Data(contentsOf: rom).isEmpty)
    }

    @Test("Executável removido entre validação e execução retorna erro de launch")
    func disappearedExecutable() async throws {
        let fixture = try FakeEmulatorBundle()
        defer { fixture.remove() }
        let executable = fixture.appURL.appending(path: "Contents/MacOS/FakeEmulator")
        try FileManager.default.removeItem(at: executable)
        let plan = LaunchPlan(
            appURL: fixture.appURL, executableURL: executable,
            bundleIdentifier: FakeEmulatorBundle.bundleIdentifier,
            arguments: [], strategy: .process, activates: false, createsNewInstance: true
        )
        do {
            _ = try await FoundationProcessLauncher().launch(plan)
            Issue.record("O executável ausente não deveria iniciar")
        } catch {
            guard case .launchFailed = error else { Issue.record("Erro inesperado: \(error)"); return }
        }
    }
}
