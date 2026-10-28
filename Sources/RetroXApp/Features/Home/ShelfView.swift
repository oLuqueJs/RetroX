import RetroXCore
import SwiftUI

/// Prateleira de capas. Detalhe de assinatura: a capa em foco sobe, ganha um halo na cor de tema
/// e se reflete no "chão" da prateleira. Com Reduce Motion, fica só o anel de foco.
struct ShelfView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let tileWidth: CGFloat = 128
    static let reflectionHeight: CGFloat = 32

    var body: some View {
        let library = model.library
        VStack(alignment: .leading, spacing: Spacing.s) {
            ShelfTabs()
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: Spacing.l) {
                        ForEach(library.visibleGames) { game in
                            ShelfTile(game: game, isFocused: game.id == library.focusedGame?.id)
                                .id(game.id)
                        }
                    }
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.top, Spacing.xl)
                }
                .scrollClipDisabled()
                .frame(height: Self.tileWidth * CoverArtView.aspectRatio + Self.reflectionHeight + Spacing.xl + Spacing.s)
                .background(alignment: .bottom) { ShelfFloor() }
                .onChange(of: library.focusedGameID) { _, id in
                    guard let id else { return }
                    withAnimation(Motion.animation(reduceMotion: reduceMotion)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .padding(.bottom, Spacing.m)
    }
}

private struct ShelfTabs: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accent) private var accent

    var body: some View {
        let library = model.library
        HStack(spacing: Spacing.l) {
            ForEach(library.shelves) { shelf in
                let isSelected = shelf == library.shelf
                Button {
                    library.select(shelf)
                } label: {
                    VStack(spacing: Spacing.xs) {
                        Text(shelf.title)
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                        Capsule()
                            .fill(isSelected ? Color(accent.fill) : .clear)
                            .frame(width: 20, height: 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
            Text(countLabel(library.visibleGames.count))
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Spacing.xxl)
    }

    private func countLabel(_ count: Int) -> String {
        count == 1 ? String(localized: "1 jogo") : String(localized: "\(count) jogos")
    }
}

private struct ShelfTile: View {
    let game: Game
    let isFocused: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.accent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let lifts = isFocused && !reduceMotion
        VStack(spacing: 0) {
            CoverArtView(game: game, width: ShelfView.tileWidth)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.m + 5, style: .continuous)
                        .strokeBorder(Color(accent.fill), lineWidth: 3)
                        .padding(-6)
                        .opacity(isFocused ? 1 : 0)
                }
                .shadow(
                    color: isFocused ? Color(accent.fill).opacity(0.45) : .black.opacity(0.16),
                    radius: isFocused ? 22 : 6,
                    y: isFocused ? 10 : 3
                )
                .scaleEffect(lifts ? 1.1 : 1, anchor: .bottom)
                .offset(y: lifts ? -6 : 0)
            Reflection(game: game)
                .opacity(isFocused ? 1 : 0)
        }
        .animation(Motion.animation(reduceMotion: reduceMotion), value: isFocused)
        .contentShape(Rectangle())
        .onTapGesture { model.library.focus(game) }
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.play(game) })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.library.focus(game) }
        .accessibilityAction(named: "Jogar") { model.play(game) }
        .accessibilityAction(named: "Favoritar") { model.library.toggleFavorite(game) }
    }

    private var accessibilityLabel: String {
        let system = SystemCatalog.system(game.systemID)?.shortName ?? ""
        let favorite = model.library.history(for: game).isFavorite ? String(localized: ", favorito") : ""
        return "\(game.title), \(system)\(favorite)"
    }
}

/// O pé da capa espelhado e esmaecido, como num piso brilhante.
private struct Reflection: View {
    let game: Game

    var body: some View {
        CoverArtView(game: game, width: ShelfView.tileWidth)
            .scaleEffect(x: 1, y: -1)
            .frame(height: ShelfView.reflectionHeight, alignment: .top)
            .clipped()
            .mask {
                LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
            }
            .padding(.top, 2)
            .accessibilityHidden(true)
    }
}

/// O "chão" da prateleira: uma linha fina e uma faixa que escurece suavemente para baixo.
private struct ShelfFloor: View {
    var body: some View {
        VStack(spacing: 0) {
            Theme.divider.frame(height: 1)
            LinearGradient(colors: [Theme.raised.opacity(0.9), Theme.background], startPoint: .top, endPoint: .bottom)
        }
        .frame(height: ShelfView.reflectionHeight + Spacing.m)
        .accessibilityHidden(true)
    }
}
