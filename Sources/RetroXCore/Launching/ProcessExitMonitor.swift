import Foundation

enum ProcessExitMonitor {
    /// Avisa quando um processo qualquer termina, mesmo que não seja filho do RetroX (kqueue via Dispatch).
    /// Não depende de run loop, então funciona também na CLI de diagnóstico.
    static func exits(of pid: pid_t) -> AsyncStream<ProcessExit> {
        AsyncStream { continuation in
            let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .global(qos: .utility))
            source.setEventHandler {
                continuation.yield(ProcessExit(status: nil, endedAt: Date()))
                continuation.finish()
            }
            continuation.onTermination = { _ in source.cancel() }
            source.resume()
            // Se o processo terminou antes de o monitor existir, o evento nunca chega.
            if kill(pid, 0) == -1, errno == ESRCH {
                continuation.yield(ProcessExit(status: nil, endedAt: Date()))
                continuation.finish()
            }
        }
    }
}
