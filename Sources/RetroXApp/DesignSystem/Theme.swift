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

/// Fonte e tamanho escolhidos no perfil.
struct TextSettings: Equatable, Hashable {
    var fontStyle: ProfilePreferences.FontStyle = .rounded
    var scale: Double = 1
}

/// No máximo quatro tamanhos por tela: título, seção, corpo e legenda. A fonte e o tamanho vêm do perfil;
/// trocar reconstrói a árvore de views (ver `AppModel.styleIdentity`).
@MainActor
enum Typography {
    static var settings = TextSettings()

    static var display: Font { title(34, .bold) }
    static var heading: Font { title(20, .semibold) }
    static var body: Font { text(15, .regular) }
    static var bodyEmphasis: Font { text(15, .semibold) }
    static var caption: Font { text(12, .medium) }

    /// Títulos usam o estilo escolhido.
    static func title(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size * settings.scale, weight: weight, design: design)
    }

    /// No estilo arredondado, o corpo continua na fonte padrão, que lê melhor em tamanhos pequenos.
    static func text(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size * settings.scale, weight: weight, design: settings.fontStyle == .rounded ? .default : design)
    }

    private static var design: Font.Design {
        switch settings.fontStyle {
        case .rounded: .rounded
        case .standard: .default
        case .serif: .serif
        case .mono: .monospaced
        }
    }
}

/// Nível e velocidade das animações escolhidos no perfil, somados ao Reduzir Movimento do macOS.
struct MotionSettings: Equatable, Hashable {
    var level: ProfilePreferences.AnimationLevel = .full
    var factor: Double = 1
}

@MainActor
enum Motion {
    static var settings = MotionSettings()

    private static var factor: Double { settings.factor }

    /// Foco e seleção: rápido, com um quique quase imperceptível.
    static var focus: Animation? {
        switch settings.level {
        case .full: .snappy(duration: 0.32 * factor, extraBounce: 0.05)
        case .reduced: .easeOut(duration: 0.15 * factor)
        case .off: nil
        }
    }

    /// Passar o mouse e apertar botões.
    static var hover: Animation? {
        switch settings.level {
        case .full: .smooth(duration: 0.24 * factor)
        case .reduced: .easeOut(duration: 0.12 * factor)
        case .off: nil
        }
    }

    static var fade: Animation? {
        settings.level == .off ? nil : .easeOut(duration: 0.2 * factor)
    }

    /// Troca de tela e cartões que surgem: mola longa e macia, sem quique.
    static var screen: Animation? {
        switch settings.level {
        case .full: .smooth(duration: 0.45 * factor)
        case .reduced: .easeOut(duration: 0.2 * factor)
        case .off: nil
        }
    }

    /// Fundo ambiente: troca lenta.
    static var ambient: Animation? {
        settings.level == .off ? nil : .easeInOut(duration: 0.7 * factor)
    }

    /// Com Reduzir Movimento do macOS, só esmaece.
    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? fade : focus
    }

    /// Escala, deslocamento e inclinação só com animações completas e sem Reduzir Movimento.
    static func allowsMovement(reduceMotion: Bool) -> Bool {
        !reduceMotion && settings.level == .full
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
