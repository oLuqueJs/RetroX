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
        .commands {
            // Os Ajustes ficam dentro da janela, navegáveis pelo controle.
            CommandGroup(replacing: .appSettings) {
                Button("Ajustes…") { model.navigate(to: .settings) }
                    .keyboardShortcut(",")
            }
            CommandMenu("Ir") {
                ForEach(Array(AppModel.Screen.tabs.enumerated()), id: \.element) { index, screen in
                    Button(screen.title) { model.navigate(to: screen) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                }
                Divider()
                Button("Trocar de perfil") { model.showProfiles() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            if model.screen == .home || model.screen == .library {
                AmbientBackdrop()
                    .transition(.opacity)
            }
            if model.screen == .profiles {
                ProfilePickerView()
                    .transition(.zoom)
            } else {
                VStack(spacing: 0) {
                    TopBar()
                    ZStack {
                        screenContent
                            .id(model.screen)
                            .transition(.screen(direction: model.navigationDirection))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .transition(.zoom)
            }
            if let game = model.detailsGame {
                ModalDim { model.showDetails(nil) }
                    .transition(.opacity)
                    .zIndex(10)
                GameDetailsView(game: game)
                    .modalCard()
                    .transition(.modalCard)
                    .zIndex(11)
            }
            if let draft = model.editingProfile {
                ModalDim { model.closeEditor() }
                    .transition(.opacity)
                    .zIndex(12)
                ProfileEditorView(draft: draft)
                    .modalCard()
                    .transition(.modalCard)
                    .zIndex(13)
            }
            if model.session.isPresenting {
                SessionOverlay()
                    .transition(.opacity)
                    .zIndex(20)
            }
            if model.splash != .done {
                SplashView()
                    .transition(.splashExit)
                    .zIndex(30)
            }
        }
        // Tema, fonte e animações formam a identidade da árvore: trocar redesenha tudo com os tokens novos.
        .id(model.styleIdentity)
        .tint(Theme.accent)
        .preferredColorScheme(model.appearance.colorScheme)
        .animation(Motion.screen, value: model.screen)
        .animation(Motion.screen, value: model.detailsGame?.id)
        .animation(Motion.screen, value: model.editingProfile?.id)
        .animation(Motion.fade, value: model.session.isPresenting)
        .alert(model.notice ?? "", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("OK", role: .cancel) { model.notice = nil }
        }
        .frame(minWidth: 1024, minHeight: 680)
        .task { await model.start() }
        .task { await model.runSplash() }
        .task { await DebugSnapshot.captureIfRequested() }
        .onChange(of: model.session.phase) { _, phase in
            announce(phase)
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch model.screen {
        case .profiles: EmptyView()
        case .home: HomeView()
        case .library: LibraryView()
        case .emulators: EmulatorsView()
        case .settings: SettingsScreen()
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
