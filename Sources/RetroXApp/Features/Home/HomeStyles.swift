import RetroXCore
import SwiftUI

/// Carrossel: a capa em foco grande no centro, as vizinhas menores e inclinadas, deslizando com mola.
/// O jogo em foco tem título e ações embaixo. Com animações reduzidas, as vizinhas não inclinam.
struct CarouselHome: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Quantas capas de cada lado do foco ficam visíveis.
    static let reach = 4

    var body: some View {
        let library = model.library
        let games = library.visibleGames
        let focused = library.focusedIndex ?? 0
        let moves = Motion.allowsMovement(reduceMotion: reduceMotion)
        VStack(spacing: Spacing.m) {
            ShelfTabs()
                .padding(.top, Spacing.s)
            GeometryReader { proxy in
                let coverWidth = min(260 * model.preferences.tileSize.scale, (proxy.size.height - Spacing.xxl) / CoverArtView.aspectRatio)
                ZStack {
                    ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                        let distance = Double(index - focused)
                        if abs(distance) <= Double(Self.reach) {
                            CarouselCover(game: game, width: coverWidth, distance: distance, moves: moves)
                                .onTapGesture {
                                    if index == focused { model.play(game) } else { withAnimation(Motion.focus) { library.focus(game) } }
                                }
                                .transition(.opacity)
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .animation(Motion.focus, value: focused)
                .animation(Motion.focus, value: library.shelf)
            }
            if let game = library.focusedGame {
                FocusedGameCaption(game: game, centered: true)
                    .id(game.id)
                    .transition(.opacity)
                    .animation(Motion.fade, value: game.id)
            }
        }
        .padding(.bottom, Spacing.l)
        .gesture(DragGesture(minimumDistance: 24).onEnded { value in
            let steps = Int((-value.translation.width / 120).rounded())
            if steps != 0 { withAnimation(Motion.focus) { library.moveFocus(by: steps) } }
        })
    }
}

private struct CarouselCover: View {
    let game: Game
    let width: CGFloat
    let distance: Double
    let moves: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let magnitude = min(abs(distance), 3)
        let side: Double = distance == 0 ? 0 : (distance > 0 ? 1 : -1)
        let isFocused = distance == 0
        VStack(spacing: 0) {
            CoverArtView(game: game, width: width)
                .overlay {
                    RoundedRectangle.rx(Radius.m + 6)
                        .strokeBorder(Theme.accent, lineWidth: 3)
                        .padding(-7)
                        .opacity(isFocused ? 1 : 0)
                }
                .shadow(color: isFocused ? Theme.accent.opacity(0.4) : .black.opacity(0.25), radius: isFocused ? 30 : 12, y: 14)
            Reflection(game: game, width: width)
                .opacity(isFocused ? 1 : 0.4)
        }
        .scaleEffect(1 - magnitude * 0.16)
        .rotation3DEffect(.degrees(moves ? -side * 38 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .offset(x: distance * width * 0.58 + side * width * 0.24)
        .opacity(abs(distance) >= Double(CarouselHome.reach) ? 0 : 1 - magnitude * 0.18)
        .zIndex(-abs(distance))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameAccessibility.label(game, isFavorite: model.library.isFavorite(game)))
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: "Jogar") { model.play(game) }
    }
}

/// Grade: o jogo em foco numa faixa no topo e todas as capas da prateleira embaixo.
struct GridHome: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let library = model.library
        let tileWidth = 120 * model.preferences.tileSize.scale
        let focusedID = library.focusedGame?.id
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let game = library.focusedGame {
                FocusedGameCaption(game: game, centered: false)
                    .padding(.horizontal, Spacing.xxl)
                    .id(game.id)
                    .transition(.opacity)
                    .animation(Motion.fade, value: game.id)
            }
            ShelfTabs()
            GeometryReader { proxy in
                let spacing = Spacing.m + Spacing.xs
                let columns = max(1, Int((proxy.size.width - 2 * Spacing.xxl + spacing) / (tileWidth + spacing)))
                ScrollViewReader { scroll in
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: spacing), count: columns),
                            alignment: .leading,
                            spacing: spacing
                        ) {
                            ForEach(library.visibleGames) { game in
                                HomeGridTile(game: game, width: tileWidth, isFocused: game.id == focusedID)
                                    .id(game.id)
                            }
                        }
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.vertical, Spacing.m)
                    }
                    .onChange(of: columns, initial: true) { _, value in library.homeColumns = value }
                    .onChange(of: library.focusedGameID) { _, id in
                        guard let id else { return }
                        withAnimation(Motion.animation(reduceMotion: reduceMotion)) { scroll.scrollTo(id) }
                    }
                }
            }
        }
        .padding(.top, Spacing.s)
    }
}

private struct HomeGridTile: View {
    let game: Game
    let width: CGFloat
    let isFocused: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isHovered = model.browser.hoveredGameID == game.id
        let lifts = Motion.allowsMovement(reduceMotion: reduceMotion) && (isFocused || isHovered)
        CoverArtView(game: game, width: width)
            .overlay {
                RoundedRectangle.rx(Radius.m + 4)
                    .strokeBorder(Theme.accent, lineWidth: 3)
                    .padding(-5)
                    .opacity(isFocused ? 1 : 0)
            }
            .shadow(color: isFocused ? Theme.accent.opacity(0.35) : .black.opacity(isHovered ? 0.22 : 0.12),
                    radius: isFocused ? 16 : 6, y: 6)
            .scaleEffect(lifts ? 1.04 : 1)
            .animation(Motion.focus, value: isFocused)
            .animation(Motion.hover, value: isHovered)
            .onHover { inside in
                model.browser.hoveredGameID = inside ? game.id : (model.browser.hoveredGameID == game.id ? nil : model.browser.hoveredGameID)
            }
            .onTapGesture { withAnimation(Motion.focus) { model.library.focus(game) } }
            .simultaneousGesture(TapGesture(count: 2).onEnded { model.play(game) })
            .contextMenu { GameContextMenu(game: game) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GameAccessibility.label(game, isFavorite: model.library.isFavorite(game)))
            .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: "Jogar") { model.play(game) }
    }
}

/// Título, metadados e ações do jogo em foco (carrossel e grade).
private struct FocusedGameCaption: View {
    let game: Game
    let centered: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let history = model.library.history(for: game)
        let stack = VStack(alignment: centered ? .center : .leading, spacing: Spacing.s) {
            Text(game.title)
                .font(Typography.heading)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(GameText.metadata(game: game, history: history))
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        HStack(spacing: Spacing.m) {
            if centered { Spacer() }
            stack
            if !centered { Spacer() }
            HStack(spacing: Spacing.s) {
                Button {
                    model.play(game)
                } label: {
                    Label("Jogar", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    model.library.toggleFavorite(game)
                } label: {
                    Image(systemName: history.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(IconButtonStyle(isActive: history.isFavorite))
                .accessibilityLabel(history.isFavorite ? "Remover dos favoritos" : "Favoritar")
                Button {
                    model.showDetails(game)
                } label: {
                    Image(systemName: "info")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Detalhes")
            }
            if centered { Spacer() }
        }
    }
}
