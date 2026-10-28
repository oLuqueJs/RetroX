import RetroXCore
import SwiftUI

/// Capa do jogo na proporção 5:7. Sem imagem local, desenha uma capa própria: tom do sistema,
/// sigla e título, e um disco em relevo discreto. Nada de arte de terceiros.
struct CoverArtView: View {
    let game: Game
    let width: CGFloat
    @Environment(CoverImageStore.self) private var covers

    static let aspectRatio: CGFloat = 7 / 5

    var body: some View {
        ZStack {
            if let image = covers.image(for: game.coverURL) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                GeneratedCover(game: game, width: width)
            }
        }
        .frame(width: width, height: width * Self.aspectRatio)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        }
        .task(id: game.coverURL) {
            if let url = game.coverURL { await covers.load(url) }
        }
        .accessibilityHidden(true)
    }
}

private struct GeneratedCover: View {
    let game: Game
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.coverTone(game.systemID)
            Circle()
                .strokeBorder(Theme.onCover.opacity(0.07), lineWidth: width * 0.09)
                .frame(width: width * 0.9, height: width * 0.9)
                .offset(x: width * 0.38, y: width * 0.78)
            VStack(alignment: .leading, spacing: width * 0.04) {
                Text(SystemCatalog.system(game.systemID)?.shortName ?? "")
                    .font(.system(size: max(width * 0.075, 9), weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Theme.onCover.opacity(0.75))
                Spacer(minLength: 0)
                Text(game.title)
                    .font(.system(size: max(width * 0.12, 11), weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.onCover)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
            }
            .padding(width * 0.09)
        }
    }
}
