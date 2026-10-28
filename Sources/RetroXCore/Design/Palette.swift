import Foundation

/// Cor sRGB em hexadecimal ("F4F0EA"). Os tokens ficam aqui como dados, sem SwiftUI, para os testes
/// conferirem o contraste (docs/design/brand-spec.md).
public struct HexColor: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    /// Luminância relativa (WCAG 2.x).
    public var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    public static func contrast(_ first: HexColor, _ second: HexColor) -> Double {
        let (lighter, darker) = first.luminance >= second.luminance ? (first, second) : (second, first)
        return (lighter.luminance + 0.05) / (darker.luminance + 0.05)
    }
}

/// Par claro/escuro de um token.
public struct Tone: Sendable, Equatable {
    public let light: HexColor
    public let dark: HexColor

    public init(light: String, dark: String) {
        self.light = HexColor(light)
        self.dark = HexColor(dark)
    }
}

/// Paleta "Portátil quente": neutros quentes (papel de dia, grafite à noite) e um único acento.
public enum Palette {
    public static let background = Tone(light: "F4F0EA", dark: "1B1916")
    public static let surface = Tone(light: "FFFDF9", dark: "262320")
    public static let raised = Tone(light: "EAE4DB", dark: "312D29")
    public static let textPrimary = Tone(light: "1E1B18", dark: "F3EEE7")
    public static let textSecondary = Tone(light: "6A625A", dark: "ADA59B")
    public static let divider = Tone(light: "DDD5CA", dark: "3B3632")

    /// Cor de tema escolhida pelo usuário. Só uma por vez; nunca em texto pequeno, só em preenchimentos,
    /// anéis de foco e títulos grandes.
    public enum Accent: String, CaseIterable, Codable, Sendable {
        case coral, ambar, salvia, ardosia

        public var fill: Tone {
            switch self {
            case .coral: Tone(light: "C7472A", dark: "F07A57")
            case .ambar: Tone(light: "A85E12", dark: "E9A23B")
            case .salvia: Tone(light: "4F7A52", dark: "8DBB8F")
            case .ardosia: Tone(light: "44657F", dark: "8DB3CF")
            }
        }

        /// Texto e ícones sobre o preenchimento do acento.
        public var onFill: Tone { Tone(light: "FFFDF9", dark: "1B1916") }

        public var title: String {
            switch self {
            case .coral: String(localized: "Coral")
            case .ambar: String(localized: "Âmbar")
            case .salvia: String(localized: "Sálvia")
            case .ardosia: String(localized: "Ardósia")
            }
        }
    }

    /// Tom das capas geradas quando não há imagem, por sistema. Não usa cores de marca.
    public static func coverTone(for system: GameSystemID) -> Tone {
        let hex = coverTones[system] ?? "3A3530"
        return Tone(light: hex, dark: hex)
    }

    /// Tons escuros e dessaturados, um por sistema, para distinguir capas geradas sem imitar cores de marca.
    private static let coverTones: [GameSystemID: String] = [
        .ps1: "4A4440", .ps2: "2E3742", .ps3: "2A2D33", .psp: "3A3550", .gamecube: "3F3A5A", .wii: "4A5560",
        .nds: "3F4A45", .n3ds: "5A3A3A", .switchConsole: "5A3434", .gba: "3E3A5E", .snes: "46424F", .n64: "2F4A3F",
    ]

    public static let onCover = Tone(light: "F3EEE7", dark: "F3EEE7")
}
