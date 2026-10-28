import AppKit
import RetroXCore
import SwiftUI

@main
struct RetroXApp: App {
    // Constante em vez de `@State`: no SDK 27 `@State` é uma macro que as Command Line Tools não trazem (ADR-0010).
    private let model = AppModel()

    init() {
        // Rodando fora de um .app (swift run), o processo nasceria sem ícone no Dock nem foco.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("RetroX", id: "main") {
            RootView()
                .environment(model)
                .environment(model.covers)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 800)

        Settings {
            SettingsRoot()
                .environment(model)
                .environment(model.covers)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            Theme.background
                .ignoresSafeArea()
            Group {
                switch model.screen {
                case .profiles: ProfilePickerView()
                case .home: HomeView()
                case .library: LibraryView()
                case .emulators: EmulatorsView()
                }
            }
            .transition(.opacity)
            if model.session.isPresenting {
                SessionOverlay()
                    .transition(.opacity)
            }
        }
        // O tema é a identidade da árvore: trocar de tema redesenha tudo com as cores novas.
        .id(model.themeSelection)
        .tint(Theme.accent)
        .preferredColorScheme(model.appearance.colorScheme)
        .animation(Motion.fade, value: model.screen)
        .animation(Motion.fade, value: model.session.isPresenting)
        .sheet(item: $model.detailsGame) { game in
            GameDetailsView(game: game)
                .environment(model)
                .environment(model.covers)
        }
        .sheet(item: $model.editingProfile) { draft in
            ProfileEditorView(draft: draft)
                .environment(model)
                .environment(model.covers)
        }
        .alert(model.notice ?? "", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("OK", role: .cancel) { model.notice = nil }
        }
        .frame(minWidth: 1024, minHeight: 680)
        .task { await model.start() }
        .task { await DebugSnapshot.captureIfRequested() }
        .onChange(of: model.session.phase) { _, phase in
            announce(phase)
        }
    }

    private func announce(_ phase: SessionModel.Phase) {
        let message: String? = switch phase {
        case .running(let game, let emulator): String(localized: "\(game.title) aberto no \(emulator).")
        case .ended: String(localized: "Partida encerrada.")
        case .failed(_, let error): error.message
        default: nil
        }
        if let message {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

/// Janela de Ajustes, com o mesmo tema e aparência do perfil atual.
private struct SettingsRoot: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SettingsView()
            .id(model.themeSelection)
            .tint(Theme.accent)
            .preferredColorScheme(model.appearance.colorScheme)
    }
}
