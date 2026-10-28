import AppKit
import RetroXCore
import SwiftUI

extension Color {
    /// Cor que acompanha o modo claro/escuro, a partir de um par de cores.
    init(light: HexColor, dark: HexColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let color = isDark ? dark : light
            return NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
        })
    }

    init(_ tone: Tone) {
        self.init(light: tone.light, dark: tone.dark)
    }
}

/// Tema escolhido no perfil: esquema de cores e, no tema RetroX, o acento.
struct ThemeSelection: Equatable, Hashable {
    var theme: ThemeID = .retrox
    var accent: Palette.Accent = .coral
}

/// Tokens de cor do tema ativo (docs/design/brand-spec.md). Trocar de tema reconstrói a árvore de views
/// (`RootView` usa o tema como identidade), então ler daqui no `body` é seguro.
@MainActor
enum Theme {
    static var current = ThemeSelection()

    static var background: Color { color(\.background) }
    static var surface: Color { color(\.surface) }
    static var raised: Color { color(\.raised) }
    static var textPrimary: Color { color(\.textPrimary) }
    static var textSecondary: Color { color(\.textSecondary) }
    static var divider: Color { color(\.divider) }
    static var accent: Color { color(\.accent) }
    static var onAccent: Color { color(\.onAccent) }
    static let onCover = Color(Palette.onCover)

    static func coverTone(_ system: GameSystemID) -> Color {
        Color(Palette.coverTone(for: system))
    }

    private static func color(_ key: KeyPath<ThemePalette, HexColor>) -> Color {
        let selection = current
        return Color(
            light: selection.theme.palette(dark: false, retroXAccent: selection.accent)[keyPath: key],
            dark: selection.theme.palette(dark: true, retroXAccent: selection.accent)[keyPath: key]
        )
    }
}

/// Grade de 8 pt.
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Cantos sempre contínuos (`style: .continuous`), que leem mais suaves que arcos circulares.
enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
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
    /// Foco e seleção: rápido e sem quicar demais.
    static let focus = Animation.snappy(duration: 0.28, extraBounce: 0.04)
    /// Passar o mouse: um pouco mais suave que o foco.
    static let hover = Animation.smooth(duration: 0.22)
    static let fade = Animation.easeOut(duration: 0.18)

    /// Com Reduce Motion, só esmaece; nada se desloca ou cresce.
    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? fade : focus
    }
}

/// O português é o idioma da interface; datas e tamanhos seguem a mesma língua.
enum AppLocale {
    static let current = Locale(identifier: "pt_BR")
}

extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension RoundedRectangle {
    /// Retângulo arredondado com cantos contínuos, o padrão do RetroX.
    static func rx(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
