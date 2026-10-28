import AppKit
import RetroXCore
import SwiftUI

/// Ação principal: preenchida com a cor de tema.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyEmphasis)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, Spacing.l)
            .frame(minHeight: 44)
            .background(Theme.accent, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.45)
            .contentShape(Capsule())
            .animation(Motion.hover, value: configuration.isPressed)
    }
}

/// Ação secundária: superfície neutra, sem cor de tema.
struct SecondaryButtonStyle: ButtonStyle {
    var isCompact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? Typography.caption : Typography.bodyEmphasis)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, isCompact ? Spacing.s + Spacing.xs : Spacing.m)
            .frame(minHeight: isCompact ? 32 : 44)
            .background(Theme.raised, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(Capsule())
            .animation(Motion.hover, value: configuration.isPressed)
    }
}

/// Botão redondo só com ícone (favoritar, detalhes). Sempre com rótulo para VoiceOver.
struct IconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isActive ? Theme.onAccent : Theme.textPrimary)
            .frame(width: 44, height: 44)
            .background(isActive ? Theme.accent : Theme.raised, in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .contentShape(Circle())
            .animation(Motion.hover, value: configuration.isPressed)
    }
}

/// Chip de filtro: selecionado ganha a cor de tema.
struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.caption)
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
            .padding(.horizontal, Spacing.s + Spacing.xs)
            .frame(minHeight: 32)
            .background(isSelected ? Theme.accent : Theme.raised, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(Capsule())
            .animation(Motion.hover, value: isSelected)
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
                    .background(Theme.raised, in: RoundedRectangle.rx(6))
            }
            Text(label)
                .font(Typography.caption)
        }
        .foregroundStyle(Theme.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(glyphs == nil ? key : String(localized: "botão do controle"))")
    }
}

/// Linha de verificação: ícone de estado + texto.
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

    var body: some View {
        Label {
            Text(text)
                .font(Typography.body)
                .foregroundStyle(kind == .info ? Theme.textSecondary : Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind == .ok ? Theme.accent : Theme.textSecondary)
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
            .background(Theme.coverTone(system), in: RoundedRectangle.rx(Radius.m))
            .accessibilityHidden(true)
    }
}

/// Foto do perfil, ou as iniciais sobre a cor de tema quando não há foto.
struct AvatarView: View {
    let profile: Profile
    var size: CGFloat = 32
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if let url = model.profiles.avatarURL(for: profile),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Theme.accent
                Text(profile.initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.onAccent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .id(model.profiles.avatarRevision)
        .accessibilityHidden(true)
    }
}

/// Campo de busca arredondado, no lugar do campo padrão do sistema.
struct SearchField: View {
    @Binding var text: String
    var prompt: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
                .focused(isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: 40)
        .background(Theme.raised, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Theme.accent.opacity(isFocused.wrappedValue ? 1 : 0), lineWidth: 2)
        }
        .animation(Motion.hover, value: isFocused.wrappedValue)
    }
}
