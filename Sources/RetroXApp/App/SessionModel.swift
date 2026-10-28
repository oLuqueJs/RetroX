import AppKit
import Observation
import RetroXCore

/// Uma partida: abrir o emulador, acompanhar enquanto ele roda e voltar à frente quando ele fecha.
@MainActor
@Observable
final class SessionModel {
    enum Phase: Equatable {
        case idle
        case launching(Game)
        case running(Game, emulator: String)
        case ended(Game, after: Duration)
        case failed(Game, LaunchError)
    }

    private(set) var phase: Phase = .idle
    private(set) var warnings: [LaunchWarning] = []

    @ObservationIgnored var onLaunched: ((Game, Date) -> Void)?
    @ObservationIgnored private let launcher: GameLauncher
    @ObservationIgnored private let runningApplications: any RunningApplicationsProviding
    @ObservationIgnored private var runningBundleID: String?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    init(launcher: GameLauncher = GameLauncher(), runningApplications: any RunningApplicationsProviding = WorkspaceRunningApplications()) {
        self.launcher = launcher
        self.runningApplications = runningApplications
    }

    var isPresenting: Bool { phase != .idle }

    var isBusy: Bool {
        switch phase {
        case .launching, .running: true
        default: false
        }
    }

    /// O plano que seria usado, sem abrir nada (aparece nos detalhes do jogo).
    func plan(for game: Game, plugin: any EmulatorPlugin, app: AppBundleInfo) throws(LaunchError) -> PreparedLaunch {
        try launcher.prepare(request(for: game, plugin: plugin, app: app))
    }

    func play(_ game: Game, plugin: any EmulatorPlugin, app: AppBundleInfo?) async {
        guard !isBusy else { return }
        dismissTask?.cancel()
        guard let app else {
            phase = .failed(game, .emulatorNotConfigured(game.systemID))
            return
        }
        phase = .launching(game)
        do {
            let prepared = try launcher.prepare(request(for: game, plugin: plugin, app: app))
            warnings = prepared.warnings
            let launched = try await launcher.launch(prepared)
            runningBundleID = launched.plan.bundleIdentifier
            phase = .running(game, emulator: plugin.displayName)
            onLaunched?(game, launched.launchedAt)
            guard let exit = await launched.waitForExit() else { return }
            switch SessionOutcome.classify(launchedAt: launched.launchedAt, exit: exit) {
            case .ended(let after):
                phase = .ended(game, after: after)
                scheduleDismiss()
            case .exitedEarly(let status, let after):
                phase = .failed(game, .exitedEarly(status: status, after: after))
            }
            NSApplication.shared.activate()
        } catch {
            phase = .failed(game, error)
        }
    }

    func bringEmulatorToFront() {
        let bundleID: String? = switch phase {
        case .failed(_, .emulatorAlreadyRunning(let id)): id
        default: runningBundleID
        }
        if let bundleID { runningApplications.activate(bundleIdentifier: bundleID) }
    }

    func dismiss() {
        guard !isBusy else { return }
        dismissTask?.cancel()
        phase = .idle
    }

    private func scheduleDismiss() {
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func request(for game: Game, plugin: any EmulatorPlugin, app: AppBundleInfo) -> LaunchRequest {
        let profile = EmulatorProfile(
            name: plugin.displayName,
            adapterID: plugin.adapter.id,
            appURL: app.bundleURL,
            options: plugin.adapter.defaultOptions
        )
        return LaunchRequest(romURL: game.romURL, systemID: game.systemID, profile: profile)
    }
}
