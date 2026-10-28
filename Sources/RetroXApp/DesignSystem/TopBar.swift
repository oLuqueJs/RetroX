import RetroXCore
import SwiftUI

/// Barra superior fixa: abas (o conteúdo desliza por baixo dela), estado, relógio e perfil.
struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Spacing.m) {
            // Tile (não círculo), para não ser confundido com a foto do perfil à direita.
            HStack(spacing: 10) {
                BrandMark(size: 30)
                    .accessibilityHidden(true)
                (Text("Retro").foregroundStyle(Theme.textPrimary) + Text("X").foregroundStyle(Theme.accent))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .tracking(-0.3)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("RetroX")
            ScreenTabs()
                .padding(.leading, Spacing.s)
            Spacer()
            if model.library.isScanning || model.plugins.entries.contains(where: \.isDiscovering) {
                HStack(spacing: Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Atualizando…")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .transition(.opacity)
            }
            if let controller = model.input.controllerName {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(Theme.textSecondary)
                    .help(controller)
                    .accessibilityLabel("Controle conectado: \(controller)")
            }
            if model.preferences.showsClock {
                TimelineView(.everyMinute) { context in
                    Text(context.date, format: .dateTime.hour().minute().locale(AppLocale.current))
                        .font(Typography.bodyEmphasis)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            ProfileMenu()
        }
        // Espaço para os botões da janela (a barra de título fica escondida).
        .padding(.leading, 88)
        .padding(.trailing, Spacing.xl)
        .padding(.top, Spacing.m)
        .frame(height: 72)
        .animation(Motion.fade, value: model.library.isScanning)
    }
}

/// As quatro abas, como pílulas; a selecionada desliza (LT/RT ou `[` `]` no teclado).
private struct ScreenTabs: View {
    @Environment(AppModel.self) private var model
    @Namespace private var selection

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            if model.input.showsControllerGlyphs, let glyph = model.input.glyphs[.previousTab] {
                Image(systemName: glyph).foregroundStyle(Theme.textSecondary).padding(.horizontal, Spacing.xs)
            }
            ForEach(AppModel.Screen.tabs, id: \.self) { screen in
                tab(screen)
            }
            if model.input.showsControllerGlyphs, let glyph = model.input.glyphs[.nextTab] {
                Image(systemName: glyph).foregroundStyle(Theme.textSecondary).padding(.horizontal, Spacing.xs)
            }
        }
        .padding(Spacing.xs)
        .background(Theme.raised, in: Capsule())
    }

    private func tab(_ screen: AppModel.Screen) -> some View {
        let isSelected = model.screen == screen
        return Button {
            model.navigate(to: screen)
        } label: {
            Label(screen.title, systemImage: screen.symbol)
                .font(Typography.caption)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(height: 32)
                .background {
                    if isSelected {
                        Capsule().fill(Theme.accent).matchedGeometryEffect(id: "tab", in: selection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ProfileMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let profile = model.profiles.current {
            Menu {
                Text(profile.name)
                Button("Editar perfil…") { model.edit(profile) }
                Button("Trocar de perfil") { model.showProfiles() }
                Divider()
                Button("Ajustes…") { model.navigate(to: .settings) }
            } label: {
                AvatarView(profile: profile, size: 36)
                    .overlay(Circle().strokeBorder(Theme.divider, lineWidth: 1))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(profile.name)
            .accessibilityLabel("Perfil: \(profile.name)")
        }
    }
}
