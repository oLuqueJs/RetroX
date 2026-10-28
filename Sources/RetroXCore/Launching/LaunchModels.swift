import Foundation

/// Como o processo do emulador é criado. A escolha por adapter é registrada no ADR-0011.
public enum LaunchStrategy: String, Codable, Sendable, CaseIterable {
    /// `NSWorkspace.openApplication`: LaunchServices, ativação e TCC por conta do emulador.
    case workspace
    /// `Process`: exec direto do binário; dá exit status, mas o emulador vira filho do RetroX.
    case process
}
