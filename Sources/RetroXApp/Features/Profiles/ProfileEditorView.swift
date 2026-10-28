import AppKit
import RetroXCore
import SwiftUI

struct ProfileEditorView: View {
    @Bindable var draft: ProfileDraft
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(draft.isNew ? "Novo perfil" : "Editar perfil")
                .font(Typography.heading)
                .foregroundStyle(Theme.textPrimary)

            HStack(alignment: .top, spacing: Spacing.l) {
                VStack(spacing: Spacing.s) {
                    DraftAvatar(draft: draft, size: 112)
                    Button("Escolher foto…") {
                        Task {
                            if let url = await FilePanel.chooseImage(message: String(localized: "Escolha uma foto para o perfil.")) {
                                draft.avatarSource = url
                                draft.removeAvatar = false
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(isCompact: true))
                    if draft.avatarSource != nil || (draft.profile.avatarFile != nil && !draft.removeAvatar) {
                        Button("Remover foto") {
                            draft.avatarSource = nil
                            draft.removeAvatar = true
                        }
                        .buttonStyle(SecondaryButtonStyle(isCompact: true))
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.m) {
                    field(String(localized: "Nome")) {
                        TextField("Jogador", text: $draft.profile.name)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Tema")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                ThemeGallery(
                    selection: $draft.profile.theme,
                    accent: $draft.profile.accent,
                    columns: 4
                )
                Picker("Aparência", selection: $draft.profile.appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                .padding(.top, Spacing.s)
            }

            HStack(spacing: Spacing.s) {
                if !draft.isNew, model.profiles.profiles.count > 1 {
                    Button("Excluir perfil", role: .destructive) { model.delete(draft) }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Spacer()
                Button("Cancelar") { model.editingProfile = nil }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(draft.isNew ? "Criar perfil" : "Salvar") { model.save(draft) }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 720)
        .background(Theme.surface)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}

/// Foto do perfil em edição: a nova escolhida, a atual, ou as iniciais.
private struct DraftAvatar: View {
    let draft: ProfileDraft
    let size: CGFloat
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Theme.accent
                Text(draft.profile.initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.onAccent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var image: NSImage? {
        if let source = draft.avatarSource { return NSImage(contentsOf: source) }
        if draft.removeAvatar { return nil }
        return model.profiles.avatarURL(for: draft.profile).flatMap(NSImage.init(contentsOf:))
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Galeria de temas: cada cartão mostra a variante clara e a escura lado a lado.
struct ThemeGallery: View {
    @Binding var selection: ThemeID
    @Binding var accent: Palette.Accent
    var columns = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: columns), spacing: Spacing.s) {
                ForEach(ThemeID.allCases) { theme in
                    ThemeCard(theme: theme, accent: accent, isSelected: theme == selection)
                        .onTapGesture { withAnimation(Motion.focus) { selection = theme } }
                }
            }
            if selection == .retrox {
                HStack(spacing: Spacing.m) {
                    Text("Acento")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(Palette.Accent.allCases, id: \.self) { option in
                        Button {
                            accent = option
                        } label: {
                            Circle()
                                .fill(Color(option.fill))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Circle().strokeBorder(Theme.textPrimary, lineWidth: 2).padding(-5)
                                        .opacity(option == accent ? 1 : 0)
                                }
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(option.title)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(option == accent ? .isSelected : [])
                    }
                }
            }
        }
    }
}

private struct ThemeCard: View {
    let theme: ThemeID
    let accent: Palette.Accent
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 0) {
                preview(dark: false)
                preview(dark: true)
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle.rx(Radius.s))
            .overlay {
                RoundedRectangle.rx(Radius.s + 4)
                    .strokeBorder(Theme.accent, lineWidth: 3)
                    .padding(-4)
                    .opacity(isSelected ? 1 : 0)
            }
            Text(theme.title)
                .font(Typography.caption)
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
        }
        .padding(Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tema \(theme.title)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Miniatura: fundo, um cartão com duas linhas de texto e o acento.
    private func preview(dark: Bool) -> some View {
        let palette = theme.palette(dark: dark, retroXAccent: accent)
        return ZStack(alignment: .topLeading) {
            Color(palette.background)
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(Color(palette.textPrimary)).frame(width: 26, height: 4)
                Capsule().fill(Color(palette.textSecondary)).frame(width: 18, height: 4)
                Capsule().fill(Color(palette.accent)).frame(width: 22, height: 8)
                    .padding(.top, 3)
            }
            .padding(6)
            .background(Color(palette.surface), in: RoundedRectangle.rx(5))
            .padding(6)
        }
    }
}

extension Color {
    /// Cor fixa (sem acompanhar o modo), para miniaturas que mostram claro e escuro ao mesmo tempo.
    init(_ hex: HexColor) {
        self.init(.sRGB, red: hex.red, green: hex.green, blue: hex.blue, opacity: 1)
    }
}
