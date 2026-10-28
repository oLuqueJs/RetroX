import AppKit
import RetroXCore
import SwiftUI

/// Todos os jogos em grade ou lista, com busca, filtro por console e favoritos.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isGridFocused: Bool
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            LibraryToolbar(isSearchFocused: $isSearchFocused)
            content
            HintBar(items: [
                .init(action: .confirm, key: "↩", label: String(localized: "Jogar")),
                .init(action: .details, key: "Espaço", label: String(localized: "Detalhes")),
                .init(action: .favorite, key: "F", label: String(localized: "Favoritar")),
                .init(actions: [.previousShelf, .nextShelf], key: "Q  E", label: String(localized: "Console")),
                .init(actions: [], key: "/", label: String(localized: "Buscar")),
            ])
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isGridFocused)
        .onAppear { isGridFocused = true }
        .onChange(of: model.detailsGame) { _, game in
            if game == nil { isGridFocused = true }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            if isSearchFocused {
                // Na busca, Esc e as setas para baixo voltam para a grade; o resto é texto.
                guard press.key == .escape || press.key == .downArrow || press.key == .return else { return .ignored }
                isSearchFocused = false
                isGridFocused = true
                return .handled
            }
            if press.characters == "/" || (press.modifiers.contains(.command) && press.characters == "f") {
                isSearchFocused = true
                return .handled
            }
            guard !press.modifiers.contains(.command), let action = KeyMapping.action(for: press) else { return .ignored }
            model.handle(action)
            return .handled
        }
    }

    @ViewBuilder
    private var content: some View {
        let library = model.library
        if !model.plugins.hasEnabledPlugin {
            EmptyHome(kind: .noEmulator)
        } else if !library.hasLoaded {
            EmptyHome(kind: .loading)
        } else if library.games.isEmpty {
            EmptyHome(kind: .noGames)
        } else if model.browser.results.isEmpty {
            NoResults()
        } else {
            LibraryGrid()
        }
    }
}

private struct LibraryToolbar: View {
    var isSearchFocused: FocusState<Bool>.Binding
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var browser = model.browser
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                Text("Biblioteca")
                    .font(Typography.display)
                    .foregroundStyle(Theme.textPrimary)
                Text(countLabel)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                SearchField(text: $browser.searchText, prompt: String(localized: "Buscar por nome ou serial"), isFocused: isSearchFocused)
                    .frame(width: 320)
            }
            HStack(spacing: Spacing.s) {
                SystemChips()
                Button {
                    withAnimation(Motion.hover) { browser.onlyFavorites.toggle() }
                } label: {
                    Label("Favoritos", systemImage: browser.onlyFavorites ? "star.fill" : "star")
                }
                .buttonStyle(ChipButtonStyle(isSelected: browser.onlyFavorites))
                .accessibilityAddTraits(browser.onlyFavorites ? .isSelected : [])
                if browser.isFiltering {
                    Button("Limpar filtros") { withAnimation(Motion.hover) { browser.clearFilters() } }
                        .buttonStyle(SecondaryButtonStyle(isCompact: true))
                        .transition(.opacity)
                }
                Spacer()
                Menu {
                    Picker("Ordenar por", selection: Binding(get: { browser.sort }, set: { browser.setSort($0) })) {
                        ForEach(LibraryBrowser.Sort.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(browser.sort.title, systemImage: "arrow.up.arrow.down")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Spacing.s + Spacing.xs)
                        .frame(minHeight: 32)
                        .background(Theme.raised, in: Capsule())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Ordenar")
                LayoutPicker()
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.m)
        .animation(Motion.hover, value: browser.isFiltering)
    }

    private var countLabel: String {
        let shown = model.browser.results.count
        let total = model.library.games.count
        return shown == total ? String(localized: "\(total) jogos") : String(localized: "\(shown) de \(total) jogos")
    }
}

/// "Todos" + os consoles que têm jogos, e um menu com o catálogo inteiro (os sem jogos ficam desativados).
private struct SystemChips: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let browser = model.browser
        let counts = browser.systemCounts
        HStack(spacing: Spacing.s) {
            chip(String(localized: "Todos"), isSelected: browser.system == nil) { browser.system = nil }
            ForEach(counts.filter { $0.1 > 0 }, id: \.0.id) { system, count in
                chip("\(system.shortName) · \(count)", isSelected: browser.system == system.id) { browser.system = system.id }
            }
            Menu {
                ForEach(counts, id: \.0.id) { system, count in
                    Button("\(system.displayName) (\(count))") { browser.system = system.id }
                        .disabled(count == 0)
                }
            } label: {
                Label("Consoles", systemImage: "line.3.horizontal.decrease")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Spacing.s + Spacing.xs)
                    .frame(minHeight: 32)
                    .background(Theme.raised, in: Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Filtrar por console")
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(title) { withAnimation(Motion.hover) { action() } }
            .buttonStyle(ChipButtonStyle(isSelected: isSelected))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct LayoutPicker: View {
    @Environment(AppModel.self) private var model
    @Namespace private var selection

    var body: some View {
        let browser = model.browser
        HStack(spacing: Spacing.xxs) {
            ForEach(LibraryBrowser.Layout.allCases) { layout in
                let isSelected = browser.layout == layout
                Button {
                    withAnimation(Motion.focus) { browser.setLayout(layout) }
                } label: {
                    Image(systemName: layout.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                        .frame(width: 36, height: 28)
                        .background {
                            if isSelected {
                                Capsule().fill(Theme.accent).matchedGeometryEffect(id: "layout", in: selection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(layout.title)
                .accessibilityLabel(layout.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Spacing.xxs + 1)
        .background(Theme.raised, in: Capsule())
    }
}

private struct LibraryGrid: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let browser = model.browser
        let layout = browser.layout
        let results = browser.results
        let focusedID = browser.focusedGame?.id
        GeometryReader { proxy in
            let spacing = layout == .largeCovers ? Spacing.l : Spacing.m + Spacing.xs
            let available = proxy.size.width - 2 * Spacing.xxl
            let columns = layout == .list ? 1 : max(1, Int((available + spacing) / (layout.tileWidth + spacing)))
            ScrollViewReader { scroll in
                ScrollView {
                    Group {
                        if layout == .list {
                            LazyVStack(spacing: Spacing.xs) {
                                ForEach(results) { game in
                                    GameRow(game: game, isFocused: game.id == focusedID).id(game.id)
                                }
                            }
                        } else {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.fixed(layout.tileWidth), spacing: spacing, alignment: .top), count: columns),
                                alignment: .leading,
                                spacing: layout == .titledCovers ? Spacing.l : spacing
                            ) {
                                ForEach(results) { game in
                                    GridTile(game: game, layout: layout, isFocused: game.id == focusedID).id(game.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.vertical, Spacing.m)
                }
                .onChange(of: columns, initial: true) { _, value in browser.columns = value }
                .onChange(of: browser.focusedGameID) { _, id in
                    guard let id else { return }
                    withAnimation(Motion.animation(reduceMotion: reduceMotion)) { scroll.scrollTo(id) }
                }
            }
        }
        .animation(Motion.focus, value: layout)
    }
}

/// Uma capa da grade. Em "Capas e nomes", com título e console embaixo.
private struct GridTile: View {
    let game: Game
    let layout: LibraryBrowser.Layout
    let isFocused: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isHovered = model.browser.hoveredGameID == game.id
        let isFavorite = model.library.isFavorite(game)
        VStack(alignment: .leading, spacing: Spacing.s) {
            CoverArtView(game: game, width: layout.tileWidth)
                .overlay(alignment: .topTrailing) {
                    if isFavorite && model.preferences.showsFavoriteBadge {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 24, height: 24)
                            .background(Theme.accent, in: Circle())
                            .padding(Spacing.s)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    RoundedRectangle.rx(Radius.m + 4)
                        .strokeBorder(Theme.accent, lineWidth: 3)
                        .padding(-5)
                        .opacity(isFocused ? 1 : 0)
                }
                .shadow(
                    color: isFocused ? Theme.accent.opacity(0.35) : .black.opacity(isHovered ? 0.22 : 0.12),
                    radius: isFocused ? 16 : (isHovered ? 12 : 5),
                    y: isFocused || isHovered ? 8 : 3
                )
                .scaleEffect(Motion.allowsMovement(reduceMotion: reduceMotion) && (isFocused || isHovered) ? 1.03 : 1)
            if layout == .titledCovers {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(game.title)
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Text("\(SystemCatalog.system(game.systemID)?.shortName ?? "") · \(GameText.size(game))")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: layout.tileWidth, alignment: .leading)
            }
        }
        .animation(Motion.animation(reduceMotion: reduceMotion), value: isFocused)
        .animation(Motion.hover, value: isHovered)
        .contentShape(Rectangle())
        .onHover { inside in
            model.browser.hoveredGameID = inside ? game.id : (model.browser.hoveredGameID == game.id ? nil : model.browser.hoveredGameID)
        }
        .onTapGesture { withAnimation(Motion.focus) { model.browser.focus(game) } }
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.play(game) })
        .contextMenu { GameContextMenu(game: game) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameAccessibility.label(game, isFavorite: isFavorite))
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.browser.focus(game) }
        .accessibilityAction(named: "Jogar") { model.play(game) }
        .accessibilityAction(named: "Detalhes") { model.showDetails(game) }
        .accessibilityAction(named: "Favoritar") { model.library.toggleFavorite(game) }
    }
}

/// Uma linha da lista: miniatura, nome, console, tamanho e última partida.
private struct GameRow: View {
    let game: Game
    let isFocused: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let isHovered = model.browser.hoveredGameID == game.id
        let history = model.library.history(for: game)
        HStack(spacing: Spacing.m) {
            CoverArtView(game: game, width: LibraryBrowser.Layout.list.tileWidth)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(game.title)
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(game.info?.name ?? game.romURL.lastPathComponent)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.m)
            Text(SystemCatalog.system(game.systemID)?.shortName ?? "")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 56, alignment: .leading)
            Text(GameText.size(game))
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 72, alignment: .trailing)
            Text(GameText.lastPlayed(history))
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 160, alignment: .trailing)
            Button {
                model.library.toggleFavorite(game)
            } label: {
                Image(systemName: history.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(history.isFavorite ? Theme.accent : Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(history.isFavorite ? "Remover dos favoritos" : "Favoritar")
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(isFocused || isHovered ? Theme.raised : .clear, in: RoundedRectangle.rx(Radius.m))
        .overlay {
            RoundedRectangle.rx(Radius.m)
                .strokeBorder(Theme.accent, lineWidth: 2)
                .opacity(isFocused ? 1 : 0)
        }
        .animation(Motion.hover, value: isHovered)
        .animation(Motion.focus, value: isFocused)
        .contentShape(Rectangle())
        .onHover { inside in
            model.browser.hoveredGameID = inside ? game.id : (model.browser.hoveredGameID == game.id ? nil : model.browser.hoveredGameID)
        }
        .onTapGesture { model.browser.focus(game) }
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.play(game) })
        .contextMenu { GameContextMenu(game: game) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: "Jogar") { model.play(game) }
    }
}

struct GameContextMenu: View {
    let game: Game
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Jogar") { model.play(game) }
        Button("Detalhes") { model.showDetails(game) }
        Button(model.library.isFavorite(game) ? "Remover dos favoritos" : "Favoritar") { model.library.toggleFavorite(game) }
        Divider()
        Button("Trocar capa…") { Task { await model.chooseCustomCover(for: game) } }
        Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([game.romURL]) }
    }
}

enum GameAccessibility {
    static func label(_ game: Game, isFavorite: Bool) -> String {
        let system = SystemCatalog.system(game.systemID)?.shortName ?? ""
        return "\(game.title), \(system)\(isFavorite ? String(localized: ", favorito") : "")"
    }
}

private struct NoResults: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Nenhum jogo com esses filtros")
                .font(Typography.heading)
                .foregroundStyle(Theme.textPrimary)
            Text("Tente outro nome, outro console ou desligue o filtro de favoritos.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
            Button("Limpar filtros") { model.browser.clearFilters() }
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.xl)
    }
}
