import RetroXCore
import SwiftUI

/// Ação principal: preenchida com a cor de tema.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accent) private var accent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyEmphasis)
            .foregroundStyle(Color(accent.onFill))
            .padding(.horizontal, Spacing.l)
            .frame(minHeight: 44)
            .background(Color(accent.fill).opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
    }
}

/// Ação secundária: superfície neutra, sem cor de tema.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyEmphasis)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: 44)
            .background(Theme.raised.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
    }
}

/// Botão redondo só com ícone (favoritar, detalhes). Sempre com rótulo para VoiceOver.
struct IconButtonStyle: ButtonStyle {
    var isActive = false
    @Environment(\.accent) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isActive ? Color(accent.onFill) : Theme.textPrimary)
            .frame(width: 44, height: 44)
            .background(isActive ? Color(accent.fill) : Theme.raised, in: Circle())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Circle())
    }
}

/// Dica de comando na barra inferior: glifo do controle conectado ou tecla do teclado.
struct CommandHint: View {
    /// Símbolos SF do controle conectado; `nil` mostra a tecla.
    let glyphs: [String]?
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            if let glyphs {
                HStack(spacing: Spacing.xs) {
                    ForEach(glyphs, id: \.self) { glyph in
                        Image(systemName: glyph)
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            } else {
                Text(key)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, Spacing.s)
                    .frame(minWidth: 24, minHeight: 22)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text(label)
                .font(Typography.caption)
        }
        .foregroundStyle(Theme.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(glyphs == nil ? key : String(localized: "botão do controle"))")
    }
}

/// Linha de verificação na tela de emuladores: ícone de estado + texto.
struct StatusLine: View {
    enum Kind {
        case ok, warning, info

        var symbol: String {
            switch self {
            case .ok: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .info: "info.circle"
            }
        }
    }

    let kind: Kind
    let text: String
    @Environment(\.accent) private var accent

    var body: some View {
        Label {
            Text(text)
                .font(Typography.body)
                .foregroundStyle(kind == .info ? Theme.textSecondary : Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind == .ok ? Color(accent.fill) : Theme.textSecondary)
        }
    }
}

/// Selo quadrado com a sigla do sistema (no lugar de logotipos de terceiros).
struct SystemBadge: View {
    let system: GameSystemID
    var size: CGFloat = 48

    var body: some View {
        Text(SystemCatalog.system(system)?.shortName ?? system.rawValue.uppercased())
            .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.onCover)
            .frame(width: size, height: size)
            .background(Theme.coverTone(system), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .accessibilityHidden(true)
    }
}
