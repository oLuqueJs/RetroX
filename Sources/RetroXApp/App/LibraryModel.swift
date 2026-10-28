import Foundation
import Observation
import RetroXCore

/// Os jogos dos plugins prontos, com o histórico do perfil atual e as personalizações (capa, informações).
@MainActor
@Observable
final class LibraryModel {
    enum Shelf: Hashable, Identifiable {
        case recent, all, favorites
        case system(GameSystemID)

        var id: Self { self }

        var title: String {
            switch self {
            case .recent: String(localized: "Recentes")
            case .all: String(localized: "Todos")
            case .favorites: String(localized: "Favoritos")
            case .system(let id): SystemCatalog.system(id)?.shortName ?? id.rawValue
            }
        }
    }

    /// Jogos já com a capa escolhida pelo usuário, quando houver.
    private(set) var games: [Game] = []
    private(set) var history: [String: GameHistory] = [:]
    private(set) var customizations: [String: GameCustomization]
    private(set) var isScanning = false
    private(set) var hasLoaded = false
    private(set) var shelf: Shelf = .all
    private(set) var focusedGameID: Game.ID?
    /// Colunas da grade da tela inicial (estilo Grade), para mover o foco para cima e para baixo.
    var homeColumns = 1

    @ObservationIgnored private var scanned: [Game] = []
    @ObservationIgnored private var startShelf: ProfilePreferences.StartShelf = .automatic
    @ObservationIgnored private var historyStore: JSONFileStore<[String: GameHistory]>?
    @ObservationIgnored let artwork: ArtworkStorage

    init(artwork: ArtworkStorage = ArtworkStorage()) {
        self.artwork = artwork
        customizations = artwork.customizations.load() ?? [:]
    }

    // MARK: Perfil

    func use(_ profile: Profile, storage: ProfileStorage) {
        historyStore = storage.history(for: profile.id)
        history = historyStore?.load() ?? [:]
        startShelf = profile.preferences.startShelf
        shelf = initialShelf
        focusedGameID = visibleGames.first?.id
    }

    /// A prateleira escolhida nas preferências; Recentes só se houver algo jogado.
    private var initialShelf: Shelf {
        let hasRecent = shelves.contains(.recent)
        switch startShelf {
        case .automatic, .recent: return hasRecent ? .recent : .all
        case .all: return .all
        case .favorites: return .favorites
        }
    }

    // MARK: Prateleiras (tela inicial)

    var shelves: [Shelf] {
        var result: [Shelf] = []
        if games.contains(where: { history[$0.id]?.lastPlayedAt != nil }) { result.append(.recent) }
        result += [.all, .favorites]
        let systems = Set(games.map(\.systemID))
        if systems.count > 1 {
            result += SystemCatalog.all.map(\.id).filter(systems.contains).map(Shelf.system)
        }
        return result
    }

    var visibleGames: [Game] {
        switch shelf {
        case .all: games
        case .favorites: games.filter { isFavorite($0) }
        case .recent: recentGames
        case .system(let id): games.filter { $0.systemID == id }
        }
    }

    var recentGames: [Game] {
        games
            .filter { history[$0.id]?.lastPlayedAt != nil }
            .sorted { (history[$0.id]?.lastPlayedAt ?? .distantPast) > (history[$1.id]?.lastPlayedAt ?? .distantPast) }
    }

    var focusedIndex: Int? {
        focusedIndex(in: visibleGames)
    }

    var focusedGame: Game? {
        let visible = visibleGames
        return focusedIndex(in: visible).map { visible[$0] }
    }

    private func focusedIndex(in visible: [Game]) -> Int? {
        visible.firstIndex { $0.id == focusedGameID } ?? (visible.isEmpty ? nil : 0)
    }

    func focus(_ game: Game) {
        focusedGameID = game.id
    }

    func moveFocus(by offset: Int) {
        let visible = visibleGames
        guard let index = focusedIndex(in: visible), !visible.isEmpty else { return }
        focusedGameID = visible[min(max(index + offset, 0), visible.count - 1)].id
    }

    func select(_ shelf: Shelf) {
        guard shelf != self.shelf else { return }
        let previous = focusedGameID
        self.shelf = shelf
        // Mantém o mesmo jogo em foco se ele também está na nova prateleira.
        focusedGameID = visibleGames.contains { $0.id == previous } ? previous : visibleGames.first?.id
    }

    func cycleShelf(by offset: Int) {
        let all = shelves
        guard let index = all.firstIndex(of: shelf) else { return select(.all) }
        select(all[(index + offset + all.count) % all.count])
    }

    // MARK: Jogos

    func game(withID id: Game.ID) -> Game? {
        games.first { $0.id == id }
    }

    func gameCount(for plugin: EmulatorPluginID) -> Int {
        games.filter { $0.pluginID == plugin }.count
    }

    func reload(from ready: [(any EmulatorPlugin, PluginDiscovery)]) async {
        isScanning = true
        scanned = await Task.detached(priority: .userInitiated) {
            ready.flatMap { plugin, discovery in LibraryBuilder.games(for: plugin, discovery: discovery) }
        }.value
        decorate()
        let isFirstLoad = !hasLoaded
        hasLoaded = true
        isScanning = false
        if isFirstLoad {
            shelf = initialShelf
        } else if !shelves.contains(shelf) {
            shelf = .all
        }
        if focusedGame?.id != focusedGameID {
            focusedGameID = visibleGames.first?.id
        }
    }

    // MARK: Histórico do perfil

    func history(for game: Game) -> GameHistory {
        history[game.id] ?? GameHistory()
    }

    func isFavorite(_ game: Game) -> Bool {
        history[game.id]?.isFavorite == true
    }

    func toggleFavorite(_ game: Game) {
        edit(game) { $0.isFavorite.toggle() }
    }

    func recordPlay(_ game: Game, at date: Date) {
        edit(game) {
            $0.lastPlayedAt = date
            $0.playCount += 1
        }
    }

    private func edit(_ game: Game, _ change: (inout GameHistory) -> Void) {
        var entry = history[game.id] ?? GameHistory()
        change(&entry)
        history[game.id] = entry
        try? historyStore?.save(history)
    }

    // MARK: Personalização (compartilhada entre perfis)

    func customization(for game: Game) -> GameCustomization? {
        customizations[game.id]
    }

    func hasCustomCover(_ game: Game) -> Bool {
        customizations[game.id]?.coverFile != nil
    }

    /// Copia a imagem escolhida como capa e devolve o endereço dela.
    @discardableResult
    func setCustomCover(for game: Game, from source: URL) throws -> URL {
        let name = try artwork.importCover(from: source, for: game.id)
        customize(game) { $0.coverFile = name }
        return artwork.artworkDirectory.appending(path: name)
    }

    func removeCustomCover(for game: Game) {
        if let url = artwork.coverURL(for: customizations[game.id]) { try? FileManager.default.removeItem(at: url) }
        customize(game) { $0.coverFile = nil }
    }

    func setMetadata(_ metadata: GameMetadata?, for game: Game) {
        customize(game) { $0.metadata = metadata }
    }

    private func customize(_ game: Game, _ change: (inout GameCustomization) -> Void) {
        var entry = customizations[game.id] ?? GameCustomization()
        change(&entry)
        customizations[game.id] = entry == GameCustomization() ? nil : entry
        try? artwork.customizations.save(customizations)
        decorate()
    }

    private func decorate() {
        games = scanned.map { game in
            artwork.coverURL(for: customizations[game.id]).map(game.withCover) ?? game
        }
    }
}
