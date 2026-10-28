import RetroXCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettings()
                .tabItem { Label("Aparência", systemImage: "paintpalette") }
            ControllerSettings()
                .tabItem { Label("Controle", systemImage: "gamecontroller") }
        }
        .frame(width: 600)
    }
}

/// Tema e aparência do perfil atual. Cada perfil guarda os seus.
private struct AppearanceSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if let profile = model.profiles.current {
                HStack(spacing: Spacing.s) {
                    AvatarView(profile: profile, size: 28)
                    Text("Tema do perfil \(profile.name)")
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(Theme.textPrimary)
                }
                ThemeGallery(
                    selection: Binding(get: { profile.theme }, set: { model.setTheme($0) }),
                    accent: Binding(get: { profile.accent }, set: { model.setTheme(accent: $0) }),
                    columns: 4
                )
                Picker("Aparência", selection: Binding(get: { profile.appearance }, set: { model.setTheme(appearance: $0) })) {
                    ForEach(AppearancePreference.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            } else {
                Text("Escolha um perfil para mudar o tema.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text("O RetroX segue os ajustes de Reduzir Movimento, Reduzir Transparência e Aumentar Contraste do macOS.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
    }
}

/// Mini configurador: layout dos botões no RetroX e teste ao vivo. O mapeamento dentro do emulador
/// é mostrado em Emuladores e continua sendo mudado no próprio emulador (docs/spikes/0002).
private struct ControllerSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let input = model.input
        VStack(alignment: .leading, spacing: Spacing.l) {
            if let name = input.controllerName {
                StatusLine(kind: .ok, text: String(localized: "Controle conectado: \(name)"))
            } else {
                StatusLine(kind: .info, text: String(localized: "Nenhum controle conectado. Teclado e mouse funcionam em tudo."))
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Botão de confirmar")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                Picker("Botão de confirmar", selection: Binding(get: { input.swapsConfirmAndBack }, set: { input.setSwapsConfirmAndBack($0) })) {
                    Text("Botão de baixo (A / ×)").tag(false)
                    Text("Botão da direita (estilo Nintendo)").tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Teste")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: Spacing.m) {
                    Image(systemName: input.lastAction.flatMap { input.glyphs[$0] } ?? "gamecontroller")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(input.lastAction == nil ? Theme.textSecondary : Theme.accent)
                        .frame(width: 56, height: 56)
                        .background(Theme.raised, in: RoundedRectangle.rx(Radius.m))
                        .id(input.actionCount)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    Text(input.lastAction.map(Self.describe) ?? String(localized: "Aperte um botão do controle para ver a ação no RetroX."))
                        .font(Typography.body)
                        .foregroundStyle(Theme.textPrimary)
                }
                .animation(Motion.focus, value: input.actionCount)
            }

            Text("O mapeamento dos botões dentro do jogo é do emulador. Você pode conferir o do PCSX2 em Emuladores; para mudar, use Configurações > Controles no próprio PCSX2.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
    }

    static func describe(_ action: InputAction) -> String {
        switch action {
        case .up: String(localized: "Para cima")
        case .down: String(localized: "Para baixo")
        case .left: String(localized: "Para a esquerda")
        case .right: String(localized: "Para a direita")
        case .confirm: String(localized: "Confirmar (jogar)")
        case .back: String(localized: "Voltar")
        case .details: String(localized: "Detalhes")
        case .favorite: String(localized: "Favoritar")
        case .previousShelf: String(localized: "Prateleira anterior")
        case .nextShelf: String(localized: "Próxima prateleira")
        case .menu: String(localized: "Emuladores")
        }
    }
}
