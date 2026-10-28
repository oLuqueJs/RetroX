import Foundation
import Observation
import RetroXCore

/// Estado da grade da biblioteca: busca, filtros, ordem, forma de exibir e jogo em foco.
@MainActor
@Observable
final class LibraryBrowser {
    enum Layout: String, CaseIterable, Identifiable {
        case compact, covers, largeCovers, titledCovers, list

        var id: Self { self }

        var title: String {
            switch self {
            case .compact: String(localized: "Capas pequenas")
            case .covers: String(localized: "Capas")
            case .largeCovers: String(localized: "Capas grandes")
            case .titledCovers: String(localized: "Capas e nomes")
            case .list: String(localized: "Lista")
            }
        }

        var symbol: String {
            switch self {
            case .compact: "square.grid.4x3.fill"
            case .covers: "square.grid.3x3"
            case .largeCovers: "square.grid.2x2"
            case .titledCovers: "rectangle.grid.2x2"
            case .list: "list.bullet"
            }
        }

        /// Largura da capa em cada forma de exibir (a lista usa uma miniatura).
        var tileWidth: CGFloat {
            switch self {
            case .compact: 96
            case .covers: 128
            case .largeCovers: 184
            case .titledCovers: 148
            case .list: 40
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case title, recent, size, system

        var id: Self { self }

        var title: String {
            switch self {
            case .title: String(localized: "Nome")
            case .recent: String(localized: "Jogados recentemente")
            case .size: String(localized: "Tamanho")
            case .system: String(localized: "Console")
            }
        }
    }

    var searchText = ""
    var system: GameSystemID?
    var onlyFavorites = false
    private(set) var layout: Layout
    private(set) var sort: Sort
    /// Quantas colunas cabem na grade (informado pela view), para mover o foco para cima e para baixo.
    var columns = 1
    private(set) var focusedGameID: Game.ID?
    /// Jogo sob o ponteiro do mouse, para o realce de hover.
    var hoveredGameID: Game.ID?

    @ObservationIgnored private let library: LibraryModel
    @ObservationIgnored private let defaults: UserDefaults

    init(library: LibraryModel, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        layout = defaults.string(forKey: "library.layout").flatMap(Layout.init(rawValue:)) ?? .titledCovers
        sort = defaults.string(forKey: "library.sort").flatMap(Sort.init(rawValue:)) ?? .title
    }

    func setLayout(_ layout: Layout) {
        self.layout = layout
        defaults.set(layout.rawValue, forKey: "library.layout")
    }

    func setSort(_ sort: Sort) {
        self.sort = sort
        defaults.set(sort.rawValue, forKey: "library.sort")
    }

    var isFiltering: Bool {
        !searchText.isEmpty || system != nil || onlyFavorites
    }

    func clearFilters() {
        searchText = ""
        system = nil
        onlyFavorites = false
    }

    /// Jogos por console, para o filtro: todos os sistemas do catálogo, com a contagem (zero fica desativado).
    var systemCounts: [(GameSystem, Int)] {
        let counts = Dictionary(grouping: library.games, by: \.systemID).mapValues(\.count)
        return SystemCatalog.all.map { ($0, counts[$0.id] ?? 0) }
    }

    var results: [Game] {
        let query = TitleParser.searchKey(searchText.trimmingCharacters(in: .whitespaces))
        let filtered = library.games.filter { game in
            (system == nil || game.systemID == system)
                && (!onlyFavorites || library.isFavorite(game))
                && (query.isEmpty || game.searchKey.contains(query)
                    || game.info.map { TitleParser.searchKey($0.name).contains(query) } == true
                    || game.serial.map { TitleParser.searchKey($0).contains(query) } == true)
        }
        switch sort {
        case .title:
            return filtered
        case .recent:
            return filtered.sorted {
                (library.history[$0.id]?.lastPlayedAt ?? .distantPast) > (library.history[$1.id]?.lastPlayedAt ?? .distantPast)
            }
        case .size:
            return filtered.sorted { $0.fileSize > $1.fileSize }
        case .system:
            let order = Dictionary(uniqueKeysWithValues: SystemCatalog.all.enumerated().map { ($1.id, $0) })
            return filtered.sorted { (order[$0.systemID] ?? .max, $0.title) < (order[$1.systemID] ?? .max, $1.title) }
        }
    }

    var focusedGame: Game? {
        let all = results
        return all.first { $0.id == focusedGameID } ?? all.first
    }

    func focus(_ game: Game) {
        focusedGameID = game.id
    }

    /// Esquerda/direita andam um; cima/baixo andam uma linha inteira da grade.
    func moveFocus(by offset: Int) {
        let all = results
        guard !all.isEmpty else { return }
        let index = all.firstIndex { $0.id == focusedGame?.id } ?? 0
        focusedGameID = all[min(max(index + offset, 0), all.count - 1)].id
    }

    /// LB/RB passam pelos consoles que têm jogos (e por "Todos").
    func cycleSystem(by offset: Int) {
        let options: [GameSystemID?] = [nil] + systemCounts.filter { $0.1 > 0 }.map { Optional($0.0.id) }
        let index = options.firstIndex(of: system) ?? 0
        system = options[(index + offset + options.count) % options.count]
    }
}
