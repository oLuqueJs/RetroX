import AppKit
import Observation
import RetroXCore

/// Raiz do estado do app: navegação, plugins, biblioteca, partida e entrada.
@MainActor
@Observable
final class AppModel {
    enum Screen {
        case home, emulators
    }

    var screen: Screen = .home
    var detailsGame: Game?

    let plugins = PluginsModel()
    let library = LibraryModel()
    let session = SessionModel()
    let covers = CoverImageStore()
    let input = InputCoordinator()

    init() {
        // Para revisão visual sem clicar: `open RetroX.app --args -RetroXInitialScreen emulators`.
        if UserDefaults.standard.string(forKey: "RetroXInitialScreen") == "emulators" {
            screen = .emulators
        }
        input.onAction = { [weak self] action in self?.handle(action) }
        session.onLaunched = { [weak self] game, date in self?.library.recordPlay(game, at: date) }
    }

    func start() async {
        await plugins.discoverAll()
        await reloadLibrary()
    }

    func reloadLibrary() async {
        await library.reload(from: plugins.readyPlugins)
    }

    // MARK: Plugins

    func setPlugin(_ id: EmulatorPluginID, enabled: Bool) async {
        await plugins.setEnabled(id, enabled)
        await reloadLibrary()
    }

    func chooseRoot(for id: EmulatorPluginID) async {
        await plugins.chooseRoot(for: id)
        await reloadLibrary()
    }

    func rediscover(_ id: EmulatorPluginID) async {
        await plugins.discover(id)
        await reloadLibrary()
    }

    // MARK: Jogos

    func play(_ game: Game) {
        detailsGame = nil
        guard let entry = plugins.entry(game.pluginID) else { return }
        Task { await session.play(game, plugin: entry.plugin, app: entry.discovery?.app) }
    }

    func plan(for game: Game) -> Result<PreparedLaunch, LaunchError> {
        guard let entry = plugins.entry(game.pluginID), let app = entry.discovery?.app else {
            return .failure(.emulatorNotConfigured(game.systemID))
        }
        do {
            return .success(try session.plan(for: game, plugin: entry.plugin, app: app))
        } catch {
            return .failure(error)
        }
    }

    func perform(_ action: RecoveryAction, for game: Game) {
        switch action {
        case .chooseEmulator, .openSettings:
            session.dismiss()
            screen = .emulators
        case .locateROM:
            session.dismiss()
            Task { await reloadLibrary() }
        case .retry:
            session.dismiss()
            play(game)
        case .bringEmulatorToFront:
            session.bringEmulatorToFront()
        case .showRosettaHelp:
            break
        }
    }

    // MARK: Entrada

    /// Um só roteador para teclado e controle: a mesma ação faz a mesma coisa em qualquer dispositivo.
    func handle(_ action: InputAction) {
        if session.isPresenting {
            handleSession(action)
        } else if let game = detailsGame {
            switch action {
            case .confirm: play(game)
            case .back, .details: detailsGame = nil
            case .favorite: library.toggleFavorite(game)
            default: break
            }
        } else if screen == .emulators {
            if action == .back || action == .menu { screen = .home }
        } else {
            handleHome(action)
        }
    }

    private func handleHome(_ action: InputAction) {
        switch action {
        case .left: library.moveFocus(by: -1)
        case .right: library.moveFocus(by: 1)
        case .up, .previousShelf: library.cycleShelf(by: -1)
        case .down, .nextShelf: library.cycleShelf(by: 1)
        case .confirm: library.focusedGame.map(play)
        case .details: detailsGame = library.focusedGame
        case .favorite: library.focusedGame.map(library.toggleFavorite)
        case .menu: screen = .emulators
        case .back: break
        }
    }

    private func handleSession(_ action: InputAction) {
        switch session.phase {
        case .running:
            if action == .confirm { session.bringEmulatorToFront() }
        case .failed(let game, let error):
            if action == .confirm, let first = error.recoveryActions.first { perform(first, for: game) }
            if action == .back { session.dismiss() }
        case .ended:
            if action == .back || action == .confirm { session.dismiss() }
        case .idle, .launching:
            break
        }
    }
}
