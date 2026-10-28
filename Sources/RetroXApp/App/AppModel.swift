import AppKit
import Observation
import RetroXCore
import SwiftUI

/// Raiz do estado do app: navegação, perfis, plugins, biblioteca, partida, ajustes e entrada.
@MainActor
@Observable
final class AppModel {
    enum Screen: Hashable {
        case profiles, home, library, emulators, settings

        /// Abas da barra superior, na ordem em que os gatilhos do controle passam por elas.
        static let tabs: [Screen] = [.home, .library, .emulators, .settings]

        var title: String {
            switch self {
            case .profiles: String(localized: "Perfis")
            case .home: String(localized: "Início")
            case .library: String(localized: "Biblioteca")
            case .emulators: String(localized: "Emuladores")
            case .settings: String(localized: "Ajustes")
            }
        }

        var symbol: String {
            switch self {
            case .profiles: "person.2"
            case .home: "house"
            case .library: "square.grid.2x2"
            case .emulators: "puzzlepiece.extension"
            case .settings: "slider.horizontal.3"
            }
        }
    }

    enum SplashPhase {
        case intro, revealed, done
    }

    /// Tudo o que, ao mudar, pede para redesenhar a árvore inteira com os tokens novos.
    struct StyleIdentity: Hashable {
        var theme = ThemeSelection()
        var text = TextSettings()
        var motion = MotionSettings()
    }

    private(set) var screen: Screen = .profiles
    /// +1 indo para uma aba à direita, -1 para a esquerda: define o lado do deslize.
    private(set) var navigationDirection = 1
    private(set) var splash: SplashPhase = .done
    var detailsGame: Game?
    var editingProfile: ProfileDraft?
    /// Na tela de perfis: índice do perfil em foco (o último é "Adicionar perfil").
    var profilePickerIndex = 0
    /// Mensagem de erro curta para ações pontuais (importar imagem, por exemplo).
    var notice: String?

    // Ajustes e Emuladores navegáveis por controle e teclado.
    var settingsSection: SettingsSection = .appearance
    /// `nil`: o foco está na lista de seções; senão, na linha de opções.
    var settingsRow: Int?
    var emulatorsFocus = 0
    /// O anel de foco de listas aparece depois do primeiro comando de teclado ou controle.
    private(set) var showsListFocus = false

    private(set) var styleIdentity = StyleIdentity()
    /// Rodando só para capturar a janela (`-RetroXSnapshot`): ignora entradas e nunca abre jogo, para uma
    /// tecla digitada em outro app não disparar nada.
    let isReviewMode = UserDefaults.standard.string(forKey: "RetroXSnapshot") != nil
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
        applyStyle(of: profiles.lastUsed)
        let isSnapshot = UserDefaults.standard.string(forKey: "RetroXSnapshot") != nil
        let forcesSplash = UserDefaults.standard.bool(forKey: "RetroXSplash")
        if forcesSplash || (!isSnapshot && preferences.startupAnimation && Motion.settings.level != .off) {
            splash = .intro
        }
        // Para revisão visual sem clicar: `RetroX -RetroXInitialScreen home|library|emulators|settings`.
        if let initial = UserDefaults.standard.string(forKey: "RetroXInitialScreen"), initial != "profiles",
           let profile = profiles.lastUsed {
            enter(profile)
            screen = switch initial {
            case "library": .library
            case "emulators": .emulators
            case "settings": .settings
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

    /// Abertura: a Rayo e o nome entram, ficam um instante e a tela de perfis aparece por baixo.
    func runSplash() async {
        guard splash == .intro else { return }
        try? await Task.sleep(for: .milliseconds(60))
        withAnimation(Motion.screen) { splash = .revealed }
        try? await Task.sleep(for: .milliseconds(Int(1300 * Motion.settings.factor)))
        withAnimation(Motion.screen) { splash = .done }
    }

    // MARK: Navegação

    func navigate(to target: Screen) {
        guard target != screen else { return }
        let from = Screen.tabs.firstIndex(of: screen) ?? -1
        let to = Screen.tabs.firstIndex(of: target) ?? -1
        navigationDirection = to >= from ? 1 : -1
        showsListFocus = false
        if target == .settings { settingsRow = nil }
        withAnimation(Motion.screen) { screen = target }
    }

    func cycleTab(by offset: Int) {
        guard let index = Screen.tabs.firstIndex(of: screen) else { return }
        let count = Screen.tabs.count
        navigate(to: Screen.tabs[(index + offset + count) % count])
    }

    // MARK: Perfis

    func enter(_ profile: Profile) {
        profiles.select(profile)
        library.use(profile, storage: profiles.storage)
        browser.clearFilters()
        applyStyle(of: profile)
        navigate(to: .home)
    }

    func showProfiles() {
        detailsGame = nil
        profilePickerIndex = profiles.profiles.firstIndex { $0.id == profiles.current?.id } ?? 0
        navigate(to: .profiles)
    }

    func newProfile() {
        withAnimation(Motion.screen) { editingProfile = ProfileDraft(profile: Profile(name: ""), isNew: true) }
    }

    func edit(_ profile: Profile) {
        withAnimation(Motion.screen) { editingProfile = ProfileDraft(profile: profile, isNew: false) }
    }

    func closeEditor() {
        withAnimation(Motion.screen) { editingProfile = nil }
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
        if profiles.current?.id == profile.id { applyStyle(of: profiles.current) }
        if draft.isNew { profilePickerIndex = profiles.profiles.count - 1 }
        closeEditor()
    }

    func delete(_ draft: ProfileDraft) {
        profiles.delete(draft.profile)
        closeEditor()
        profilePickerIndex = min(profilePickerIndex, profiles.profiles.count - 1)
        if profiles.current == nil { showProfiles() }
    }

    // MARK: Estilo do perfil

    var preferences: ProfilePreferences {
        var preferences = (profiles.current ?? profiles.lastUsed)?.preferences ?? ProfilePreferences()
        // Só para revisão visual, sem gravar no perfil: `-RetroXHomeStyle carousel|grid`.
        if let style = UserDefaults.standard.string(forKey: "RetroXHomeStyle").flatMap(ProfilePreferences.HomeStyle.init(rawValue:)) {
            preferences.homeStyle = style
        }
        return preferences
    }

    /// Muda o tema do perfil atual, aplicando na hora.
    func setTheme(_ theme: ThemeID? = nil, accent: Palette.Accent? = nil, appearance: AppearancePreference? = nil) {
        guard var profile = profiles.current else { return }
        if let theme { profile.theme = theme }
        if let accent { profile.accent = accent }
        if let appearance { profile.appearance = appearance }
        profiles.update(profile)
        applyStyle(of: profile)
    }

    func updatePreferences(_ change: (inout ProfilePreferences) -> Void) {
        guard var profile = profiles.current else { return }
        change(&profile.preferences)
        profiles.update(profile)
        applyStyle(of: profile)
    }

    private func applyStyle(of profile: Profile?) {
        var selection = ThemeSelection(theme: profile?.theme ?? .retrox, accent: profile?.accent ?? .coral)
        var appearance = profile?.appearance ?? .system
        // Só para revisão visual, sem gravar no perfil: `-RetroXTheme gruvbox -RetroXAppearance light`.
        let defaults = UserDefaults.standard
        if let theme = defaults.string(forKey: "RetroXTheme").flatMap(ThemeID.init(rawValue:)) { selection.theme = theme }
        if let forced = defaults.string(forKey: "RetroXAppearance").flatMap(AppearancePreference.init(rawValue:)) { appearance = forced }
        let preferences = profile?.preferences ?? ProfilePreferences()
        Theme.current = selection
        Typography.settings = TextSettings(fontStyle: preferences.fontStyle, scale: preferences.textSize.scale)
        Motion.settings = MotionSettings(level: preferences.animationLevel, factor: preferences.animationSpeed.durationFactor)
        styleIdentity = StyleIdentity(theme: selection, text: Typography.settings, motion: Motion.settings)
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

    /// Controles focáveis da tela de Emuladores, na ordem em que o controle passa por eles.
    var emulatorControls: [FocusableControl] {
        plugins.entries.flatMap { entry -> [FocusableControl] in
            let id = entry.id
            var controls = [FocusableControl(id: "\(id).toggle") { [weak self] in
                Task { await self?.setPlugin(id, enabled: !entry.config.isEnabled) }
            }]
            if entry.config.isEnabled {
                controls.append(FocusableControl(id: "\(id).root") { [weak self] in Task { await self?.chooseRoot(for: id) } })
                if let root = entry.discovery?.root {
                    controls.append(FocusableControl(id: "\(id).rediscover") { [weak self] in Task { await self?.rediscover(id) } })
                    controls.append(FocusableControl(id: "\(id).reveal") { NSWorkspace.shared.activateFileViewerSelecting([root]) })
                }
            }
            return controls
        }
    }

    func isFocused(emulatorControl id: String) -> Bool {
        showsListFocus && emulatorControls.indices.contains(emulatorsFocus) && emulatorControls[emulatorsFocus].id == id
    }

    // MARK: Jogos

    func play(_ game: Game) {
        guard !isReviewMode else { return }
        withAnimation(Motion.screen) { detailsGame = nil }
        guard let entry = plugins.entry(game.pluginID) else { return }
        Task { await session.play(game, plugin: entry.plugin, app: entry.discovery?.app) }
    }

    func showDetails(_ game: Game?) {
        metadata.cancel()
        withAnimation(Motion.screen) { detailsGame = game }
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
            if detailsGame != nil { detailsGame = library.game(withID: game.id) }
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
            navigate(to: .emulators)
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

    /// O jogo em foco na tela atual (para o fundo ambiente).
    var ambientGame: Game? {
        switch screen {
        case .home: library.focusedGame
        case .library: browser.focusedGame
        default: nil
        }
    }

    // MARK: Entrada

    /// Um só roteador para teclado e controle: a mesma ação faz a mesma coisa em qualquer dispositivo.
    func handle(_ action: InputAction) {
        guard splash == .done, !isReviewMode else { return }
        if editingProfile != nil {
            if action == .back { closeEditor() }
            return
        }
        if session.isPresenting { return handleSession(action) }
        if let game = detailsGame {
            switch action {
            case .confirm: play(game)
            case .back, .details: showDetails(nil)
            case .favorite: library.toggleFavorite(game)
            default: break
            }
            return
        }
        if screen != .profiles {
            switch action {
            case .previousTab: return cycleTab(by: -1)
            case .nextTab: return cycleTab(by: 1)
            case .menu: return navigate(to: screen == .settings ? .home : .settings)
            case .options: return navigate(to: screen == .emulators ? .home : .emulators)
            default: break
            }
        }
        switch screen {
        case .profiles: handleProfiles(action)
        case .home: handleHome(action)
        case .library: handleLibrary(action)
        case .emulators: handleEmulators(action)
        case .settings: handleSettings(action)
        }
    }

    private func handleProfiles(_ action: InputAction) {
        let count = profiles.profiles.count
        withAnimation(Motion.focus) {
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
    }

    private func handleHome(_ action: InputAction) {
        let isGrid = preferences.homeStyle == .grid
        switch action {
        case .left: library.moveFocus(by: -1)
        case .right: library.moveFocus(by: 1)
        case .up: isGrid ? library.moveFocus(by: -library.homeColumns) : library.cycleShelf(by: -1)
        case .down: isGrid ? library.moveFocus(by: library.homeColumns) : library.cycleShelf(by: 1)
        case .previousShelf: library.cycleShelf(by: -1)
        case .nextShelf: library.cycleShelf(by: 1)
        case .confirm: library.focusedGame.map(play)
        case .details: showDetails(library.focusedGame)
        case .favorite: library.focusedGame.map(library.toggleFavorite)
        default: break
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
        case .back:
            if browser.isFiltering { browser.clearFilters() } else { navigate(to: .home) }
        default: break
        }
    }

    private func handleEmulators(_ action: InputAction) {
        let controls = emulatorControls
        showsListFocus = true
        switch action {
        case .up, .left: emulatorsFocus = max(emulatorsFocus - 1, 0)
        case .down, .right: emulatorsFocus = min(emulatorsFocus + 1, max(controls.count - 1, 0))
        case .confirm: if controls.indices.contains(emulatorsFocus) { controls[emulatorsFocus].run() }
        case .back: navigate(to: .home)
        default: break
        }
    }

    private func handleSettings(_ action: InputAction) {
        showsListFocus = true
        let sections = SettingsSection.allCases
        guard let row = settingsRow else {
            let index = sections.firstIndex(of: settingsSection) ?? 0
            switch action {
            case .up: settingsSection = sections[max(index - 1, 0)]
            case .down: settingsSection = sections[min(index + 1, sections.count - 1)]
            case .right, .confirm: if !settingsRows.isEmpty { settingsRow = 0 }
            case .back: navigate(to: .home)
            default: break
            }
            return
        }
        let rows = settingsRows
        guard rows.indices.contains(row) else { settingsRow = rows.isEmpty ? nil : rows.count - 1; return }
        switch action {
        case .up: settingsRow = max(row - 1, 0)
        case .down: settingsRow = min(row + 1, rows.count - 1)
        case .left: rows[row].step(by: -1)
        case .right: rows[row].step(by: 1)
        case .confirm: rows[row].activate()
        case .back: settingsRow = nil
        default: break
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

/// Um controle que teclado e controle de jogo alcançam com as setas.
struct FocusableControl: Identifiable {
    let id: String
    let run: () -> Void
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
