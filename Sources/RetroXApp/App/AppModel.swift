import AppKit
import Observation
import RetroXCore

/// Raiz do estado do app: navegação, perfis, plugins, biblioteca, partida e entrada.
@MainActor
@Observable
final class AppModel {
    enum Screen: Hashable {
        case profiles, home, library, emulators
    }

    var screen: Screen = .profiles
    var detailsGame: Game?
    var editingProfile: ProfileDraft?
    /// Na tela de perfis: índice do perfil em foco (o último é "Adicionar perfil").
    var profilePickerIndex = 0
    /// Mensagem de erro curta para ações pontuais (importar imagem, por exemplo).
    var notice: String?

    /// Tema e aparência do perfil atual. O tema serve de identidade da árvore de views.
    private(set) var themeSelection = ThemeSelection()
    private(set) var appearance: AppearancePreference = .system

    let profiles = ProfilesModel()
    let plugins = PluginsModel()
    let library = LibraryModel()
    let browser: LibraryBrowser
    let session = SessionModel()
    let covers = CoverImageStore()
    let input = InputCoordinator()
    let metadata = MetadataSearchModel()

    init() {
        browser = LibraryBrowser(library: library)
        profilePickerIndex = profiles.profiles.firstIndex { $0.id == profiles.lastUsed?.id } ?? 0
        applyTheme(of: profiles.lastUsed)
        // Para revisão visual sem clicar: `RetroX -RetroXInitialScreen home|library|emulators`.
        if let initial = UserDefaults.standard.string(forKey: "RetroXInitialScreen"), initial != "profiles",
           let profile = profiles.lastUsed {
            enter(profile)
            screen = switch initial {
            case "library": .library
            case "emulators": .emulators
            default: .home
            }
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

    // MARK: Perfis

    func enter(_ profile: Profile) {
        profiles.select(profile)
        library.use(profile, storage: profiles.storage)
        browser.clearFilters()
        applyTheme(of: profile)
        screen = .home
    }

    func showProfiles() {
        detailsGame = nil
        profilePickerIndex = profiles.profiles.firstIndex { $0.id == profiles.current?.id } ?? 0
        screen = .profiles
    }

    func newProfile() {
        editingProfile = ProfileDraft(profile: Profile(name: ""), isNew: true)
    }

    func edit(_ profile: Profile) {
        editingProfile = ProfileDraft(profile: profile, isNew: false)
    }

    func save(_ draft: ProfileDraft) {
        var profile = draft.profile
        profile.name = profile.name.trimmingCharacters(in: .whitespaces)
        if profile.name.isEmpty { profile.name = String(localized: "Jogador \(profiles.profiles.count + (draft.isNew ? 1 : 0))") }
        if draft.isNew {
            let created = profiles.create(name: profile.name)
            profile.id = created.id
        }
        profiles.update(profile)
        if draft.removeAvatar { profiles.removeAvatar(for: profile) }
        if let source = draft.avatarSource, let saved = profiles.profiles.first(where: { $0.id == profile.id }) {
            do {
                try profiles.setAvatar(for: saved, from: source)
            } catch {
                notice = String(localized: "Não foi possível usar essa imagem como foto.")
            }
        }
        if profiles.current?.id == profile.id { applyTheme(of: profiles.current) }
        if draft.isNew { profilePickerIndex = profiles.profiles.count - 1 }
        editingProfile = nil
    }

    func delete(_ draft: ProfileDraft) {
        profiles.delete(draft.profile)
        editingProfile = nil
        profilePickerIndex = min(profilePickerIndex, profiles.profiles.count - 1)
        if profiles.current == nil { showProfiles() }
    }

    /// Muda o tema do perfil atual (Ajustes), aplicando na hora.
    func setTheme(_ theme: ThemeID? = nil, accent: Palette.Accent? = nil, appearance: AppearancePreference? = nil) {
        guard var profile = profiles.current else { return }
        if let theme { profile.theme = theme }
        if let accent { profile.accent = accent }
        if let appearance { profile.appearance = appearance }
        profiles.update(profile)
        applyTheme(of: profile)
    }

    private func applyTheme(of profile: Profile?) {
        var selection = ThemeSelection(theme: profile?.theme ?? .retrox, accent: profile?.accent ?? .coral)
        var appearance = profile?.appearance ?? .system
        // Só para revisão visual, sem gravar no perfil: `-RetroXTheme gruvbox -RetroXAppearance light`.
        let defaults = UserDefaults.standard
        if let theme = defaults.string(forKey: "RetroXTheme").flatMap(ThemeID.init(rawValue:)) { selection.theme = theme }
        if let forced = defaults.string(forKey: "RetroXAppearance").flatMap(AppearancePreference.init(rawValue:)) { appearance = forced }
        Theme.current = selection
        themeSelection = selection
        self.appearance = appearance
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

    func showDetails(_ game: Game?) {
        metadata.cancel()
        detailsGame = game
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

    func chooseCustomCover(for game: Game) async {
        let message = String(localized: "Escolha uma imagem para a capa de \(game.title). Uma cópia reduzida é guardada no RetroX.")
        guard let source = await FilePanel.chooseImage(message: message) else { return }
        do {
            let cover = try library.setCustomCover(for: game, from: source)
            covers.invalidate(cover)
            detailsGame = library.game(withID: game.id)
        } catch {
            notice = String(localized: "Não foi possível usar essa imagem como capa.")
        }
    }

    func restoreOriginalCover(for game: Game) {
        if let cover = game.coverURL { covers.invalidate(cover) }
        library.removeCustomCover(for: game)
        detailsGame = library.game(withID: game.id)
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
        if editingProfile != nil { return }
        if session.isPresenting {
            handleSession(action)
        } else if let game = detailsGame {
            switch action {
            case .confirm: play(game)
            case .back, .details: showDetails(nil)
            case .favorite: library.toggleFavorite(game)
            default: break
            }
        } else {
            switch screen {
            case .profiles: handleProfiles(action)
            case .home: handleHome(action)
            case .library: handleLibrary(action)
            case .emulators: if action == .back || action == .menu { screen = .home }
            }
        }
    }

    private func handleProfiles(_ action: InputAction) {
        let count = profiles.profiles.count
        switch action {
        case .left: profilePickerIndex = max(profilePickerIndex - 1, 0)
        case .right: profilePickerIndex = min(profilePickerIndex + 1, count)
        case .confirm:
            if profilePickerIndex < count { enter(profiles.profiles[profilePickerIndex]) } else { newProfile() }
        case .details:
            if profilePickerIndex < count { edit(profiles.profiles[profilePickerIndex]) }
        default: break
        }
    }

    private func handleHome(_ action: InputAction) {
        switch action {
        case .left: library.moveFocus(by: -1)
        case .right: library.moveFocus(by: 1)
        case .up, .previousShelf: library.cycleShelf(by: -1)
        case .down, .nextShelf: library.cycleShelf(by: 1)
        case .confirm: library.focusedGame.map(play)
        case .details: showDetails(library.focusedGame)
        case .favorite: library.focusedGame.map(library.toggleFavorite)
        case .menu: screen = .emulators
        case .back: break
        }
    }

    private func handleLibrary(_ action: InputAction) {
        switch action {
        case .left: browser.moveFocus(by: -1)
        case .right: browser.moveFocus(by: 1)
        case .up: browser.moveFocus(by: -browser.columns)
        case .down: browser.moveFocus(by: browser.columns)
        case .previousShelf: browser.cycleSystem(by: -1)
        case .nextShelf: browser.cycleSystem(by: 1)
        case .confirm: browser.focusedGame.map(play)
        case .details: showDetails(browser.focusedGame)
        case .favorite: browser.focusedGame.map(library.toggleFavorite)
        case .menu: screen = .emulators
        case .back:
            if browser.isFiltering { browser.clearFilters() } else { screen = .home }
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

/// Cópia de um perfil sendo editado; só vale ao salvar.
@MainActor
@Observable
final class ProfileDraft: Identifiable {
    let id = UUID()
    var profile: Profile
    let isNew: Bool
    /// Foto nova escolhida (copiada ao salvar).
    var avatarSource: URL?
    var removeAvatar = false

    init(profile: Profile, isNew: Bool) {
        self.profile = profile
        self.isNew = isNew
    }
}

/// Busca de informações de um jogo numa fonte pública, com escolha do usuário (ADR-0014).
@MainActor
@Observable
final class MetadataSearchModel {
    enum Phase: Equatable {
        case idle
        case searching
        case results([MetadataCandidate])
        case loading(MetadataCandidate)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var gameID: Game.ID?
    var query = ""

    @ObservationIgnored private let provider = WikipediaMetadataProvider()

    var isActive: Bool { gameID != nil }

    func start(for game: Game) {
        gameID = game.id
        query = game.searchTitle
        Task { await search() }
    }

    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        phase = .searching
        do {
            phase = .results(try await provider.search(query))
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func choose(_ candidate: MetadataCandidate, for game: Game, library: LibraryModel) async {
        phase = .loading(candidate)
        do {
            library.setMetadata(try await provider.metadata(for: candidate), for: game)
            cancel()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func cancel() {
        phase = .idle
        gameID = nil
    }

    private static func message(for error: Error) -> String {
        switch error as? MetadataError {
        case .http(let status) where status >= 500:
            String(localized: "A Wikipedia não respondeu agora (erro \(status)). Tente de novo em alguns minutos.")
        case .http(let status):
            String(localized: "A Wikipedia recusou a busca (erro \(status)).")
        case .network:
            String(localized: "Sem conexão com a internet. O RetroX continua funcionando; só a busca precisa de rede.")
        default:
            String(localized: "A resposta da Wikipedia veio num formato inesperado.")
        }
    }
}
