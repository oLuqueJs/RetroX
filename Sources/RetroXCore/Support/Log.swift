import os

/// Caminhos e argumentos são sempre registrados como `.private` (ADR-0009).
enum Log {
    static let subsystem = "local.retrox.RetroX"
    static let launch = Logger(subsystem: subsystem, category: "launch")
    /// Intervalo do North Star do PRD: do Play até o processo do emulador existir.
    static let launchSignposter = OSSignposter(subsystem: subsystem, category: "launch")
}
