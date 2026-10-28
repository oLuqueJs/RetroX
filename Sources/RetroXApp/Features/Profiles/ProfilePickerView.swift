import RetroXCore
import SwiftUI

/// "Quem vai jogar?": a primeira tela, como num console. Cada perfil tem seus favoritos, recentes e tema.
struct ProfilePickerView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: Spacing.s) {
                Text("Quem vai jogar?")
                    .font(Typography.display)
                    .foregroundStyle(Theme.textPrimary)
                Text("Cada perfil tem os próprios favoritos, recentes e tema.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, Spacing.xxl)
            HStack(alignment: .top, spacing: Spacing.xl) {
                ForEach(Array(model.profiles.profiles.enumerated()), id: \.element.id) { index, profile in
                    ProfileTile(profile: profile, index: index)
                }
                AddProfileTile(index: model.profiles.profiles.count)
            }
            .padding(.horizontal, Spacing.xxl)
            Spacer()
            HintBar(items: [
                .init(actions: [.left, .right], key: "←  →", label: String(localized: "Escolher")),
                .init(action: .confirm, key: "↩", label: String(localized: "Entrar")),
                .init(action: .details, key: "Espaço", label: String(localized: "Editar perfil")),
            ], showsMenu: false)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onChange(of: model.editingProfile == nil) { _, closed in
            if closed { isFocused = true }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard !press.modifiers.contains(.command), let action = KeyMapping.action(for: press) else { return .ignored }
            model.handle(action)
            return .handled
        }
    }
}

private struct ProfileTile: View {
    let profile: Profile
    let index: Int
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let avatarSize: CGFloat = 128

    var body: some View {
        let isFocused = model.profilePickerIndex == index
        VStack(spacing: Spacing.m) {
            AvatarView(profile: profile, size: Self.avatarSize)
                .overlay {
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: 4)
                        .padding(-8)
                        .opacity(isFocused ? 1 : 0)
                }
                .shadow(color: isFocused ? Theme.accent.opacity(0.4) : .black.opacity(0.12), radius: isFocused ? 24 : 8, y: isFocused ? 10 : 4)
                .scaleEffect(isFocused && Motion.allowsMovement(reduceMotion: reduceMotion) ? 1.08 : 1)
            Text(profile.name)
                .font(Typography.heading)
                .foregroundStyle(isFocused ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: Self.avatarSize + Spacing.l)
        }
        .padding(Spacing.s)
        .contentShape(Rectangle())
        .animation(Motion.animation(reduceMotion: reduceMotion), value: isFocused)
        .onHover { inside in
            if inside { model.profilePickerIndex = index }
        }
        .onTapGesture { model.enter(profile) }
        .contextMenu {
            Button("Entrar") { model.enter(profile) }
            Button("Editar perfil…") { model.edit(profile) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(profile.name)
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.enter(profile) }
        .accessibilityAction(named: "Editar perfil") { model.edit(profile) }
    }
}

private struct AddProfileTile: View {
    let index: Int
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isFocused = model.profilePickerIndex == index
        VStack(spacing: Spacing.m) {
            Image(systemName: "plus")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(isFocused ? Theme.textPrimary : Theme.textSecondary)
                .frame(width: ProfileTile.avatarSize, height: ProfileTile.avatarSize)
                .background(Theme.raised, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: 4)
                        .padding(-8)
                        .opacity(isFocused ? 1 : 0)
                }
                .scaleEffect(isFocused && Motion.allowsMovement(reduceMotion: reduceMotion) ? 1.08 : 1)
            Text("Adicionar")
                .font(Typography.heading)
                .foregroundStyle(isFocused ? Theme.textPrimary : Theme.textSecondary)
        }
        .padding(Spacing.s)
        .contentShape(Rectangle())
        .animation(Motion.animation(reduceMotion: reduceMotion), value: isFocused)
        .onHover { inside in
            if inside { model.profilePickerIndex = index }
        }
        .onTapGesture { model.newProfile() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adicionar perfil")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.newProfile() }
    }
}
