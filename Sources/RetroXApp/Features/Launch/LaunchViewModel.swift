import AppKit
import RetroXCore

/// Estado da tela de prova técnica: um emulador, uma ROM e o botão Jogar.
/// Sem persistência de biblioteca nesta fase; só lembra os dois últimos caminhos.
@MainActor
@Observable
final class LaunchViewModel {
    enum Status: Equatable {
        case idle
        /// Modo simulado: o plano validado, sem abrir nada.
        case planned(LaunchPlan)
        case launching
        case running(bundleIdentifier: String?)
        case ended(after: Duration)
        case failed(LaunchError)
    }

    enum Importer {
        case emulator, rom
    }

    private(set) var emulatorURL: URL?
    private(set) var emulatorInfo: AppBundleInfo?
    private(set) var emulatorError: LaunchError?
    private(set) var romURL: URL?
    private(set) var warnings: [LaunchWarning] = []
    private(set) var status: Status = .idle
    var isDryRun = false
    /// Qual seletor de arquivo está aberto. Fica aqui, e não em `@State`, porque no SDK 27 `@State`
    /// é uma macro que as Command Line Tools não trazem (ADR-0010).
    var importer: Importer?

    let adapter = PCSX2Adapter()

    private let launcher: GameLauncher
    private let inspector: AppBundleInspector
    private let runningApplications: any RunningApplicationsProviding
    private let defaults: UserDefaults
    private let bringSelfToFront: @MainActor () -> Void

    private enum DefaultsKey {
        static let emulatorPath = "launch.emulatorPath"
        static let romPath = "launch.romPath"
    }

    init(
        launcher: GameLauncher = GameLauncher(),
        inspector: AppBundleInspector = AppBundleInspector(),
        runningApplications: any RunningApplicationsProviding = WorkspaceRunningApplications(),
        defaults: UserDefaults = .standard,
        bringSelfToFront: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }
    ) {
        self.launcher = launcher
        self.inspector = inspector
        self.runningApplications = runningApplications
        self.defaults = defaults
        self.bringSelfToFront = bringSelfToFront
        if let path = defaults.string(forKey: DefaultsKey.emulatorPath) {
            selectEmulator(URL(filePath: path))
        }
        romURL = defaults.string(forKey: DefaultsKey.romPath).map { URL(filePath: $0) }
    }

    var isBusy: Bool {
        switch status {
        case .launching, .running: true
        default: false
        }
    }

    var canPlay: Bool { emulatorURL != nil && romURL != nil && !isBusy }

    func selectEmulator(_ url: URL) {
        emulatorURL = url
        defaults.set(url.path(percentEncoded: false), forKey: DefaultsKey.emulatorPath)
        do {
            emulatorInfo = try inspector.inspect(url)
            emulatorError = nil
        } catch {
            emulatorInfo = nil
            emulatorError = error
        }
        if !isBusy { status = .idle }
    }

    func selectROM(_ url: URL) {
        romURL = url
        defaults.set(url.path(percentEncoded: false), forKey: DefaultsKey.romPath)
        if !isBusy { status = .idle }
    }

    func play() async {
        guard let emulatorURL, let romURL, !isBusy else { return }
        let profile = EmulatorProfile(
            name: adapter.displayName,
            adapterID: adapter.id,
            appURL: emulatorURL,
            options: adapter.defaultOptions
        )
        let request = LaunchRequest(romURL: romURL, systemID: .ps2, profile: profile)
        do {
            let prepared = try launcher.prepare(request)
            warnings = prepared.warnings
            if isDryRun {
                status = .planned(prepared.plan)
                return
            }
            status = .launching
            let launched = try await launcher.launch(prepared)
            status = .running(bundleIdentifier: launched.plan.bundleIdentifier)
            guard let exit = await launched.waitForExit() else { return }
            switch SessionOutcome.classify(launchedAt: launched.launchedAt, exit: exit) {
            case .ended(let after): status = .ended(after: after)
            case .exitedEarly(let code, let after): status = .failed(.exitedEarly(status: code, after: after))
            }
            bringSelfToFront()
        } catch {
            status = .failed(error)
        }
    }

    func bringEmulatorToFront() {
        let bundleID: String? = switch status {
        case .running(let id): id
        case .failed(.emulatorAlreadyRunning(let id)): id
        default: emulatorInfo?.bundleIdentifier
        }
        if let bundleID {
            runningApplications.activate(bundleIdentifier: bundleID)
        }
    }
}
