import AppKit

public protocol RunningApplicationsProviding: Sendable {
    func isRunning(bundleIdentifier: String) -> Bool
    @discardableResult
    func activate(bundleIdentifier: String) -> Bool
}

public struct WorkspaceRunningApplications: RunningApplicationsProviding {
    public init() {}

    public func isRunning(bundleIdentifier: String) -> Bool {
        Self.alive(bundleIdentifier).first != nil
    }

    @discardableResult
    public func activate(bundleIdentifier: String) -> Bool {
        Self.alive(bundleIdentifier).first?.activate() ?? false
    }

    /// Logo depois que um app fecha, o LaunchServices ainda o lista por um instante; o processo, não.
    /// Sem esse filtro, jogar de novo logo após fechar o emulador daria "já aberto".
    private static func alive(_ bundleIdentifier: String) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).filter {
            !$0.isTerminated && kill($0.processIdentifier, 0) == 0
        }
    }
}
