import Foundation
import Observation
import RetroXCore

/// Os jogos dos plugins prontos, organizados em prateleiras, com o jogo em foco.
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

    private(set) var games: [Game] = []
    private(set) var history: [String: GameHistory]
    private(set) var isScanning = false
    private(set) var hasLoaded = false
    private(set) var shelf: Shelf = .all
    private(set) var focusedGameID: Game.ID?

    @ObservationIgnored private let store: JSONFileStore<[String: GameHistory]>

    init(store: JSONFileStore<[String: GameHistory]> = JSONFileStore(url: RetroXDirectories.applicationSupport.appending(path: "history.json"))) {
        self.store = store
        history = store.load() ?? [:]
    }

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
        case .all:
            games
        case .favorites:
            games.filter { history[$0.id]?.isFavorite == true }
        case .recent:
            games
                .filter { history[$0.id]?.lastPlayedAt != nil }
                .sorted { (history[$0.id]?.lastPlayedAt ?? .distantPast) > (history[$1.id]?.lastPlayedAt ?? .distantPast) }
        case .system(let id):
            games.filter { $0.systemID == id }
        }
    }

    var focusedIndex: Int? {
        let visible = visibleGames
        return visible.firstIndex { $0.id == focusedGameID } ?? (visible.isEmpty ? nil : 0)
    }

    var focusedGame: Game? {
        focusedIndex.map { visibleGames[$0] }
    }

    func history(for game: Game) -> GameHistory {
        history[game.id] ?? GameHistory()
    }

    func gameCount(for plugin: EmulatorPluginID) -> Int {
        games.filter { $0.pluginID == plugin }.count
    }

    func reload(from ready: [(any EmulatorPlugin, PluginDiscovery)]) async {
        isScanning = true
        let scanned = await Task.detached(priority: .userInitiated) {
            ready.flatMap { plugin, discovery in LibraryBuilder.games(for: plugin, discovery: discovery) }
        }.value
        let isFirstLoad = !hasLoaded
        games = scanned
        hasLoaded = true
        isScanning = false
        if isFirstLoad, shelves.contains(.recent) {
            shelf = .recent
        } else if !shelves.contains(shelf) {
            shelf = .all
        }
        if focusedGame?.id != focusedGameID {
            focusedGameID = visibleGames.first?.id
        }
    }

    func focus(_ game: Game) {
        focusedGameID = game.id
    }

    func moveFocus(by offset: Int) {
        let visible = visibleGames
        guard let index = focusedIndex, !visible.isEmpty else { return }
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
        try? store.save(history)
    }
}
