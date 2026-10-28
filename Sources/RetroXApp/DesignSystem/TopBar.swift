import RetroXCore
import SwiftUI

/// Barra superior compartilhada por Início e Biblioteca: abas, estado, relógio, emuladores e perfil.
struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text("RetroX")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
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
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute().locale(AppLocale.current))
                    .font(Typography.bodyEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            Button {
                model.screen = .emulators
            } label: {
                Image(systemName: "puzzlepiece.extension")
            }
            .buttonStyle(IconButtonStyle())
            .help("Emuladores")
            .accessibilityLabel("Emuladores")
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

/// Início | Biblioteca, como abas em pílula.
private struct ScreenTabs: View {
    @Environment(AppModel.self) private var model
    @Namespace private var selection

    var body: some View {
        HStack(spacing: Spacing.xs) {
            tab(.home, String(localized: "Início"), "house")
            tab(.library, String(localized: "Biblioteca"), "square.grid.2x2")
        }
        .padding(Spacing.xs)
        .background(Theme.raised, in: Capsule())
    }

    private func tab(_ screen: AppModel.Screen, _ title: String, _ symbol: String) -> some View {
        let isSelected = model.screen == screen
        return Button {
            withAnimation(Motion.focus) { model.screen = screen }
        } label: {
            Label(title, systemImage: symbol)
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
                SettingsLink { Text("Ajustes…") }
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
