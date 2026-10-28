import AppKit

/// Abre o emulador pelo LaunchServices. Os argumentos só chegam se o app ainda não estiver aberto
/// e se o RetroX não estiver em sandbox (doc de `NSWorkspace.OpenConfiguration.arguments`).
public struct WorkspaceLauncher: ProcessLaunching {
    public init() {}

    public func launch(_ plan: LaunchPlan) async throws(LaunchError) -> LaunchedProcess {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = plan.arguments
        configuration.activates = plan.activates
        configuration.createsNewApplicationInstance = plan.createsNewInstance
        configuration.addsToRecentItems = false

        let pid: pid_t
        do {
            pid = try await NSWorkspace.shared.openApplication(at: plan.appURL, configuration: configuration).processIdentifier
        } catch {
            throw .launchFailed(error.localizedDescription)
        }
        return LaunchedProcess(pid: pid, launchedAt: Date(), plan: plan, exits: ProcessExitMonitor.exits(of: pid))
    }
}
