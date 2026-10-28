import AppKit

/// Executa o binário de dentro do `.app` diretamente, com argv em array (sem shell).
/// O emulador vira filho do RetroX: dá exit status, mas prompts de privacidade passam a ser atribuídos ao RetroX.
public struct FoundationProcessLauncher: ProcessLaunching {
    /// Destino de stdout/stderr do emulador. `nil` descarta: um pipe sem leitor travaria ou mataria o emulador.
    public var outputLogURL: URL?

    public init(outputLogURL: URL? = nil) {
        self.outputLogURL = outputLogURL
    }

    public func launch(_ plan: LaunchPlan) async throws(LaunchError) -> LaunchedProcess {
        let process = Process()
        process.executableURL = plan.executableURL
        process.arguments = plan.arguments
        process.standardInput = FileHandle.nullDevice
        let output = openOutput()
        process.standardOutput = output
        process.standardError = output

        let (exits, continuation) = AsyncStream.makeStream(of: ProcessExit.self)
        process.terminationHandler = { finished in
            continuation.yield(ProcessExit(status: finished.terminationStatus, endedAt: Date()))
            continuation.finish()
        }
        do {
            try process.run()
        } catch {
            throw .launchFailed(error.localizedDescription)
        }

        let pid = process.processIdentifier
        if plan.activates {
            await Self.activateWhenRegistered(pid: pid)
        }
        return LaunchedProcess(pid: pid, launchedAt: Date(), plan: plan, exits: exits)
    }

    private func openOutput() -> FileHandle {
        guard let outputLogURL else { return FileHandle.nullDevice }
        FileManager.default.createFile(atPath: outputLogURL.path(percentEncoded: false), contents: nil)
        return (try? FileHandle(forWritingTo: outputLogURL)) ?? FileHandle.nullDevice
    }

    /// Um processo iniciado por exec não é ativado pelo sistema; o app só aparece para o AppKit depois de registrar.
    private static func activateWhenRegistered(pid: pid_t) async {
        for _ in 0..<20 {
            if let app = NSRunningApplication(processIdentifier: pid) {
                if app.activationPolicy == .regular { app.activate() }
                return
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
    }
}
