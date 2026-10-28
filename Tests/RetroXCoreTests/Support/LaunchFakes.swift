import Foundation
@testable import RetroXCore

struct FakeRunningApplications: RunningApplicationsProviding {
    var running: Set<String> = []

    func isRunning(bundleIdentifier: String) -> Bool {
        running.contains(bundleIdentifier)
    }

    func activate(bundleIdentifier: String) -> Bool {
        running.contains(bundleIdentifier)
    }
}

/// Não executa nada: guarda os planos recebidos e devolve um processo que já terminou.
actor RecordingLauncher: ProcessLaunching {
    private(set) var plans: [LaunchPlan] = []
    let exit: ProcessExit

    init(exit: ProcessExit = ProcessExit(status: 0, endedAt: Date(timeIntervalSince1970: 60))) {
        self.exit = exit
    }

    func launch(_ plan: LaunchPlan) async throws(LaunchError) -> LaunchedProcess {
        plans.append(plan)
        let (exits, continuation) = AsyncStream.makeStream(of: ProcessExit.self)
        continuation.yield(exit)
        continuation.finish()
        return LaunchedProcess(pid: 4242, launchedAt: Date(timeIntervalSince1970: 0), plan: plan, exits: exits)
    }
}

/// Cenário padrão: PCSX2 x86_64 em Apple Silicon com Rosetta, e uma ROM legível.
struct LaunchScenario {
    var disk = FakeFileSystem()
    var host = HostEnvironment(architecture: .arm64, isRosettaInstalled: true)
    var running = FakeRunningApplications()
    var romPath = "/Volumes/Jogos Ação/Test Drive Unlimited (USA).iso"
    var appPath = "/Apps/PCSX2.app"
    var profile: EmulatorProfile

    init() {
        profile = EmulatorProfile(
            name: "PCSX2",
            adapterID: .pcsx2,
            appURL: URL(filePath: appPath),
            options: PCSX2Adapter().defaultOptions
        )
        disk.addAppBundle(at: appPath, executable: "PCSX2")
        disk[romPath] = .file()
    }

    var request: LaunchRequest {
        LaunchRequest(romURL: URL(filePath: romPath), systemID: .ps2, profile: profile)
    }

    func launcher(recording: RecordingLauncher = RecordingLauncher()) -> GameLauncher {
        GameLauncher(
            registry: .standard,
            fileSystem: disk,
            host: host,
            runningApplications: running,
            launchers: [.workspace: recording, .process: recording]
        )
    }
}
