import Foundation

/// Valida ROM e emulador, monta o plano e o executa (ADR-0003).
public struct GameLauncher: Sendable {
    private let registry: EmulatorRegistry
    private let fileSystem: any FileSystemProbing
    private let host: HostEnvironment
    private let runningApplications: any RunningApplicationsProviding
    private let launchers: [LaunchStrategy: any ProcessLaunching]

    public init(
        registry: EmulatorRegistry = .standard,
        fileSystem: any FileSystemProbing = LocalFileSystem(),
        host: HostEnvironment = .current(),
        runningApplications: any RunningApplicationsProviding = WorkspaceRunningApplications(),
        launchers: [LaunchStrategy: any ProcessLaunching] = [.workspace: WorkspaceLauncher(), .process: FoundationProcessLauncher()]
    ) {
        self.registry = registry
        self.fileSystem = fileSystem
        self.host = host
        self.runningApplications = runningApplications
        self.launchers = launchers
    }

    /// Valida tudo e monta o plano, sem executar nada. É também o que o modo simulado mostra.
    public func prepare(_ request: LaunchRequest) throws(LaunchError) -> PreparedLaunch {
        let profile = request.profile
        guard let adapter = registry.adapter(for: profile.adapterID) else {
            throw .emulatorNotConfigured(request.systemID)
        }
        guard adapter.supportedSystems.contains(request.systemID) else {
            throw .emulatorDoesNotSupportSystem(request.systemID)
        }
        try validateROM(request.romURL, supportedExtensions: adapter.supportedExtensions(for: request.systemID))

        let app = try AppBundleInspector(fileSystem: fileSystem).inspect(profile.appURL)
        var warnings: [LaunchWarning] = []
        if !(app.bundleIdentifier.map(adapter.expectedBundleIdentifiers.contains) ?? false) {
            warnings.append(.unexpectedBundleIdentifier(app.bundleIdentifier))
        }
        switch host.compatibility(with: app.architectures) {
        case .native: break
        case .rosetta: warnings.append(.runsUnderRosetta)
        case .unknown: warnings.append(.unknownArchitecture)
        case .incompatible(let rosettaMissing): throw .architectureUnsupported(rosettaMissing: rosettaMissing)
        }

        let createsNewInstance = request.alreadyRunningPolicy == .launchNewInstance
        if !createsNewInstance, let bundleID = app.bundleIdentifier, runningApplications.isRunning(bundleIdentifier: bundleID) {
            throw .emulatorAlreadyRunning(bundleID: bundleID)
        }

        let arguments = try adapter.arguments(
            romPath: request.romURL.path(percentEncoded: false),
            options: profile.options,
            extraArguments: profile.extraArguments
        )
        let plan = LaunchPlan(
            appURL: app.bundleURL,
            executableURL: app.executableURL,
            bundleIdentifier: app.bundleIdentifier,
            arguments: arguments,
            strategy: profile.strategy ?? adapter.defaultStrategy,
            activates: true,
            createsNewInstance: createsNewInstance
        )
        return PreparedLaunch(plan: plan, app: app, warnings: warnings)
    }

    public func launch(_ prepared: PreparedLaunch) async throws(LaunchError) -> LaunchedProcess {
        let plan = prepared.plan
        guard let launcher = launchers[plan.strategy] else {
            throw .launchFailed(String(localized: "estratégia “\(plan.strategy.rawValue)” indisponível"))
        }
        let interval = Log.launchSignposter.beginInterval("launch")
        defer { Log.launchSignposter.endInterval("launch", interval) }

        Log.launch.info("""
            Abrindo \(plan.bundleIdentifier ?? "?", privacy: .public) via \(plan.strategy.rawValue, privacy: .public) \
            com \(plan.arguments, privacy: .private)
            """)
        do {
            let launched = try await launcher.launch(plan)
            Log.launch.info("Emulador iniciado, pid \(launched.pid, privacy: .public)")
            return launched
        } catch {
            Log.launch.error("Falha ao abrir o emulador: \(error.message, privacy: .private)")
            throw error
        }
    }

    private func validateROM(_ url: URL, supportedExtensions: Set<String>) throws(LaunchError) {
        switch fileSystem.kind(of: url) {
        case .missing: throw .romNotFound
        case .directory: throw .romIsDirectory
        case .regularFile: break
        }
        guard fileSystem.isReadable(url) else { throw .romUnreadable }
        let fileExtension = url.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else { throw .unsupportedFormat(fileExtension) }
    }
}
