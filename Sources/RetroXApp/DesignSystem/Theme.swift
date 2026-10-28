import AppKit
import RetroXCore
import SwiftUI

extension Color {
    /// Cor que acompanha o modo claro/escuro, a partir de um token da paleta.
    init(_ tone: Tone) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let color = isDark ? tone.dark : tone.light
            return NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
        })
    }
}

/// Tokens da direção "Portátil quente" (docs/design/brand-spec.md).
enum Theme {
    static let background = Color(Palette.background)
    static let surface = Color(Palette.surface)
    static let raised = Color(Palette.raised)
    static let textPrimary = Color(Palette.textPrimary)
    static let textSecondary = Color(Palette.textSecondary)
    static let divider = Color(Palette.divider)
    static let onCover = Color(Palette.onCover)

    static func coverTone(_ system: GameSystemID) -> Color {
        Color(Palette.coverTone(for: system))
    }
}

/// Grade de 8 pt.
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
}

/// No máximo quatro tamanhos por tela: título, seção, corpo e legenda.
enum Typography {
    static let display = Font.system(size: 34, weight: .bold, design: .rounded)
    static let heading = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 15)
    static let bodyEmphasis = Font.system(size: 15, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .medium)
}

enum Motion {
    static let standard = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let fade = Animation.easeOut(duration: 0.15)

    /// Com Reduce Motion, só esmaece; nada se desloca ou cresce.
    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? fade : standard
    }
}

/// O português é o idioma da interface; datas e tamanhos seguem a mesma língua.
enum AppLocale {
    static let current = Locale(identifier: "pt_BR")
}

// MARK: Acento escolhido pelo usuário

private struct AccentKey: EnvironmentKey {
    static let defaultValue = Palette.Accent.coral
}

extension EnvironmentValues {
    var accent: Palette.Accent {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "Sistema")
        case .light: String(localized: "Claro")
        case .dark: String(localized: "Escuro")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
