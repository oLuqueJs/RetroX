import AppKit

public protocol RunningApplicationsProviding: Sendable {
    func isRunning(bundleIdentifier: String) -> Bool
    @discardableResult
    func activate(bundleIdentifier: String) -> Bool
}

public struct WorkspaceRunningApplications: RunningApplicationsProviding {
    public init() {}

    public func isRunning(bundleIdentifier: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).contains { !$0.isTerminated }
    }

    @discardableResult
    public func activate(bundleIdentifier: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { !$0.isTerminated })
        else { return false }
        return app.activate()
    }
}
