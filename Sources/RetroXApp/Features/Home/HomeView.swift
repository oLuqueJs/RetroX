import RetroXCore
import SwiftUI

/// Tela inicial no estilo de portátil: palco com o jogo em foco em cima, prateleira de capas embaixo.
/// Teclado e controle passam pelo mesmo roteador (`AppModel.handle`).
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            content
            HintBar()
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onChange(of: model.detailsGame) { _, game in
            if game == nil { isFocused = true }
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard !press.modifiers.contains(.command), let action = Self.action(for: press) else { return .ignored }
            model.handle(action)
            return .handled
        }
    }

    @ViewBuilder
    private var content: some View {
        let library = model.library
        if !model.plugins.hasEnabledPlugin {
            EmptyHome(kind: .noEmulator)
        } else if !library.hasLoaded || (library.games.isEmpty && library.isScanning) {
            EmptyHome(kind: .loading)
        } else if library.games.isEmpty {
            EmptyHome(kind: .noGames)
        } else {
            StageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ShelfView()
        }
    }

    static func action(for press: KeyPress) -> InputAction? {
        switch press.key {
        case .leftArrow: return .left
        case .rightArrow: return .right
        case .upArrow: return .up
        case .downArrow: return .down
        case .return: return .confirm
        case .space: return .details
        case .escape: return .back
        default: break
        }
        switch press.characters.lowercased() {
        case "f": return .favorite
        case "q": return .previousShelf
        case "e": return .nextShelf
        case "m": return .menu
        default: return nil
        }
    }
}

private struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text("RetroX")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if model.library.isScanning || model.plugins.entries.contains(where: \.isDiscovering) {
                HStack(spacing: Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Atualizando biblioteca…")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if let controller = model.input.controllerName {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(Theme.textSecondary)
                    .help(controller)
                    .accessibilityLabel("Controle conectado: \(controller)")
            }
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute().locale(AppLocale.current))
                    .font(Typography.bodyEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            Button {
                model.screen = .emulators
            } label: {
                Label("Emuladores", systemImage: "puzzlepiece.extension")
            }
            .buttonStyle(SecondaryButtonStyle())
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("Ajustes")
        }
        // Espaço para os botões da janela (a barra de título fica escondida).
        .padding(.leading, 88)
        .padding(.trailing, Spacing.xl)
        .padding(.top, Spacing.m)
        .frame(height: 72)
    }
}

private struct StageView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A capa do palco acompanha a altura disponível (janela pequena ou tela cheia), até este limite.
    static let maxCoverWidth: CGFloat = 240

    var body: some View {
        GeometryReader { proxy in
            let coverWidth = min(Self.maxCoverWidth, max(120, (proxy.size.height - Spacing.xl) / CoverArtView.aspectRatio))
            ZStack(alignment: .leading) {
                if let game = model.library.focusedGame {
                    HStack(alignment: .center, spacing: Spacing.xxl) {
                        CoverArtView(game: game, width: coverWidth)
                            .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
                        StageDetails(game: game)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.xxl)
                    .id(game.id)
                    .transition(.opacity)
                } else {
                    EmptyShelfMessage(shelf: model.library.shelf)
                        .padding(.horizontal, Spacing.xxl)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.bottom, Spacing.l)
        .animation(Motion.animation(reduceMotion: reduceMotion), value: model.library.focusedGame?.id)
    }
}

private struct StageDetails: View {
    let game: Game
    @Environment(AppModel.self) private var model

    var body: some View {
        let history = model.library.history(for: game)
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(overline)
                .font(Typography.caption)
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)
            Text(game.title)
                .font(Typography.display)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(Self.metadata(game: game, history: history))
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
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
                    model.detailsGame = game
                } label: {
                    Image(systemName: "info")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Detalhes")
            }
            .padding(.top, Spacing.s)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var overline: String {
        let system = SystemCatalog.system(game.systemID)?.displayName ?? game.systemID.rawValue
        let emulator = model.plugins.entry(game.pluginID)?.plugin.displayName ?? ""
        return "\(system) · \(emulator)".uppercased()
    }

    static func metadata(game: Game, history: GameHistory) -> String {
        var parts: [String] = []
        if let last = history.lastPlayedAt {
            let relative = RelativeDateTimeFormatter()
            relative.locale = AppLocale.current
            relative.unitsStyle = .full
            parts.append(String(localized: "Jogado \(relative.localizedString(for: last, relativeTo: .now))"))
        } else {
            parts.append(String(localized: "Ainda não jogado"))
        }
        parts.append(game.fileSize.formatted(.byteCount(style: .file).locale(AppLocale.current)))
        parts.append(game.fileExtension)
        return parts.joined(separator: " · ")
    }
}

private struct EmptyShelfMessage: View {
    let shelf: LibraryModel.Shelf

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(shelf == .favorites ? "Nenhum favorito ainda" : "Nada por aqui")
                .font(Typography.heading)
                .foregroundStyle(Theme.textPrimary)
            Text(shelf == .favorites
                 ? "Escolha um jogo em Todos e pressione F (ou o botão de favoritar do controle)."
                 : "Troque de prateleira com Q e E, ou com os botões de ombro do controle.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Estados de tela inteira: sem emulador, procurando jogos, nenhum jogo encontrado.
private struct EmptyHome: View {
    enum Kind {
        case noEmulator, loading, noGames
    }

    let kind: Kind
    @Environment(AppModel.self) private var model
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if kind == .loading {
                ProgressView()
                    .controlSize(.large)
            } else {
                Image(systemName: kind == .noEmulator ? "puzzlepiece.extension" : "tray")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(accent.fill))
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(Typography.display)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: 480, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if kind != .loading {
                Button(kind == .noEmulator ? "Ativar emuladores" : "Abrir Emuladores") {
                    model.screen = .emulators
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, Spacing.s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xxl)
    }

    private var title: String {
        switch kind {
        case .noEmulator: String(localized: "Nenhum emulador ativo")
        case .loading: String(localized: "Procurando seus jogos…")
        case .noGames: String(localized: "Nenhum jogo encontrado")
        }
    }

    private var message: String {
        switch kind {
        case .noEmulator:
            String(localized: "Ative o PCSX2 e escolha a pasta dele. O RetroX encontra o app, os jogos e as capas sozinho, sem copiar nem alterar nada.")
        case .loading:
            String(localized: "Lendo as pastas dos emuladores ativos.")
        case .noGames:
            String(localized: "Os emuladores ativos não têm jogos nas pastas encontradas. Confira as pastas em Emuladores.")
        }
    }
}

private struct HintBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let glyphs = model.input.glyphs
        HStack(spacing: Spacing.l) {
            CommandHint(glyphs: glyphs[.confirm].map { [$0] }, key: "↩", label: String(localized: "Jogar"))
            CommandHint(glyphs: glyphs[.details].map { [$0] }, key: "Espaço", label: String(localized: "Detalhes"))
            CommandHint(glyphs: glyphs[.favorite].map { [$0] }, key: "F", label: String(localized: "Favoritar"))
            CommandHint(
                glyphs: [glyphs[.previousShelf], glyphs[.nextShelf]].allSatisfy { $0 != nil }
                    ? [glyphs[.previousShelf]!, glyphs[.nextShelf]!] : nil,
                key: "Q  E",
                label: String(localized: "Prateleira")
            )
            Spacer()
            CommandHint(glyphs: glyphs[.menu].map { [$0] }, key: "M", label: String(localized: "Emuladores"))
        }
        .padding(.horizontal, Spacing.xxl)
        .frame(height: 48)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Theme.divider.frame(height: 1)
        }
    }
}
