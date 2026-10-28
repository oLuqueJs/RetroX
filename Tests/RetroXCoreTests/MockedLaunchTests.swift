import Foundation
import Testing
@testable import RetroXCore

private actor FailingLauncher: ProcessLaunching {
    private(set) var plans: [LaunchPlan] = []
    let error: LaunchError

    init(_ error: LaunchError) { self.error = error }

    func launch(_ plan: LaunchPlan) async throws(LaunchError) -> LaunchedProcess {
        plans.append(plan)
        throw error
    }
}

struct MockedLaunchTests {
    @Test("Só chama o executor selecionado, uma vez", arguments: LaunchStrategy.allCases)
    func routesExactlyOnce(strategy: LaunchStrategy) async throws {
        var scenario = LaunchScenario()
        scenario.profile.strategy = strategy
        let workspace = RecordingLauncher()
        let process = RecordingLauncher()
        let launcher = GameLauncher(
            fileSystem: scenario.disk, host: scenario.host, runningApplications: scenario.running,
            launchers: [.workspace: workspace, .process: process]
        )
        let prepared = try launcher.prepare(scenario.request)
        #expect(await workspace.plans.isEmpty)
        #expect(await process.plans.isEmpty)
        _ = try await launcher.launch(prepared)
        #expect(await workspace.plans == (strategy == .workspace ? [prepared.plan] : []))
        #expect(await process.plans == (strategy == .process ? [prepared.plan] : []))
    }

    @Test("Falha do executor é propagada sem retry nem fallback")
    func propagatesFailure() async throws {
        let scenario = LaunchScenario()
        let expected = LaunchError.launchFailed("falha simulada")
        let failing = FailingLauncher(expected)
        let fallback = RecordingLauncher()
        let launcher = GameLauncher(
            fileSystem: scenario.disk, host: scenario.host, runningApplications: scenario.running,
            launchers: [.workspace: failing, .process: fallback]
        )
        let prepared = try launcher.prepare(scenario.request)
        await #expect(throws: expected) { try await launcher.launch(prepared) }
        #expect(await failing.plans == [prepared.plan])
        #expect(await fallback.plans.isEmpty)
    }

    @Test("Validação rejeitada não executa processos")
    func invalidRequestDoesNotLaunch() async {
        var scenario = LaunchScenario()
        scenario.disk[scenario.romPath] = nil
        let recording = RecordingLauncher()
        let launcher = scenario.launcher(recording: recording)
        await #expect(throws: LaunchError.romNotFound) {
            let prepared = try launcher.prepare(scenario.request)
            _ = try await launcher.launch(prepared)
        }
        #expect(await recording.plans.isEmpty)
    }
}
