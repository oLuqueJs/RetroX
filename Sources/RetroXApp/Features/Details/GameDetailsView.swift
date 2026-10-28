import AppKit
import RetroXCore
import SwiftUI

struct GameDetailsView: View {
    let game: Game
    @Environment(AppModel.self) private var model

    var body: some View {
        let history = model.library.history(for: game)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.xl) {
                VStack(spacing: Spacing.s) {
                    CoverArtView(game: game, width: 220)
                        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                    HStack(spacing: Spacing.s) {
                        Button("Trocar capa…") { Task { await model.chooseCustomCover(for: game) } }
                        if model.library.hasCustomCover(game) {
                            Button("Original") { model.restoreOriginalCover(for: game) }
                                .help("Voltar para a capa encontrada nas pastas")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(isCompact: true))
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        header
                        facts(history)
                        MetadataSection(game: game)
                        DisclosureGroup("Comando de abertura") {
                            commandPlan
                                .padding(.top, Spacing.s)
                        }
                        .font(Typography.body)
                        .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, Spacing.s)
                }
                .scrollIndicators(.automatic)
            }
            .padding(Spacing.xl)

            HStack(spacing: Spacing.s) {
                Button {
                    model.play(game)
                } label: {
                    Label("Jogar", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                Button {
                    model.library.toggleFavorite(game)
                } label: {
                    Label(history.isFavorite ? "Favorito" : "Favoritar", systemImage: history.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([game.romURL])
                } label: {
                    Label("Mostrar no Finder", systemImage: "folder")
                }
                .buttonStyle(SecondaryButtonStyle())
                Spacer()
                Button("Fechar") { model.showDetails(nil) }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.m)
            .background(Theme.background)
            .overlay(alignment: .top) { Theme.divider.frame(height: 1) }
        }
        .frame(width: 880, height: 620)
        .background(Theme.surface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(GameText.overline(game, emulator: model.plugins.entry(game.pluginID)?.plugin.displayName))
                .font(Typography.caption)
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)
            Text(game.title)
                .font(Typography.display)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let official = game.info?.name, TitleParser.searchKey(official) != TitleParser.searchKey(TitleParser.searchTitle(game.title)) {
                Text("Nome no \(model.plugins.entry(game.pluginID)?.plugin.displayName ?? "emulador"): \(official)")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func facts(_ history: GameHistory) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.m, verticalSpacing: Spacing.s) {
            row(String(localized: "Arquivo"), game.romURL.lastPathComponent)
            row(String(localized: "Pasta"), (game.romURL.deletingLastPathComponent().path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath)
            row(String(localized: "Tamanho"), GameText.size(game))
            if let serial = game.serial { row(String(localized: "Serial"), serial) }
            if let region = game.info?.region { row(String(localized: "Região"), region) }
            if let compatibility = game.info?.compatibility {
                GridRow {
                    label(String(localized: "Compatibilidade"))
                    HStack(spacing: Spacing.xxs) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= compatibility ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundStyle(star <= compatibility ? Theme.accent : Theme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(compatibility) de 5 no \(model.plugins.entry(game.pluginID)?.plugin.displayName ?? "emulador")")
                }
            }
            row(String(localized: "Emulador"), emulatorDescription)
            row(String(localized: "Partidas"), playsDescription(history))
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(Theme.textSecondary)
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            label(title)
            Text(value)
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private var emulatorDescription: String {
        guard let entry = model.plugins.entry(game.pluginID) else { return "—" }
        return [entry.plugin.displayName, entry.discovery?.app?.version].compactMap { $0 }.joined(separator: " ")
    }

    private func playsDescription(_ history: GameHistory) -> String {
        guard let last = history.lastPlayedAt else { return String(localized: "Nunca jogado") }
        let date = last.formatted(.dateTime.day().month(.wide).hour().minute().locale(AppLocale.current))
        return history.playCount == 1
            ? String(localized: "1 vez · última em \(date)")
            : String(localized: "\(history.playCount) vezes · última em \(date)")
    }

    /// O argv exato que seria usado, para diagnóstico. Nada é executado aqui.
    @ViewBuilder
    private var commandPlan: some View {
        switch model.plan(for: game) {
        case .success(let prepared):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(prepared.plan.arguments.enumerated()), id: \.offset) { index, argument in
                    Text("[\(index)] \(argument)")
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .textSelection(.enabled)
        case .failure(let error):
            StatusLine(kind: .warning, text: error.message)
        }
    }
}

/// Informações de uma fonte pública: só com a ação do usuário, que escolhe o resultado certo (ADR-0014).
private struct MetadataSection: View {
    let game: Game
    @Environment(AppModel.self) private var model

    var body: some View {
        let search = model.metadata
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Sobre o jogo")
                    .font(Typography.heading)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !search.isActive {
                    Button(model.library.customization(for: game)?.metadata == nil ? "Buscar na Wikipedia" : "Buscar de novo") {
                        search.start(for: game)
                    }
                    .buttonStyle(SecondaryButtonStyle(isCompact: true))
                }
            }
            if search.isActive && search.gameID == game.id {
                SearchPanel(game: game)
            } else if let metadata = model.library.customization(for: game)?.metadata {
                SavedMetadata(game: game, metadata: metadata)
            } else {
                Text("Sem informações extras. A busca usa a Wikipedia (sem conta) e você escolhe o resultado certo.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.m)
        .background(Theme.background.opacity(0.6), in: RoundedRectangle.rx(Radius.l))
    }
}

private struct SearchPanel: View {
    let game: Game
    @Environment(AppModel.self) private var model
    @FocusState private var isQueryFocused: Bool

    var body: some View {
        @Bindable var search = model.metadata
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                SearchField(text: $search.query, prompt: String(localized: "Nome do jogo"), isFocused: $isQueryFocused)
                    .onSubmit { Task { await search.search() } }
                Button("Buscar") { Task { await search.search() } }
                    .buttonStyle(SecondaryButtonStyle(isCompact: true))
                Button("Cancelar") { search.cancel() }
                    .buttonStyle(SecondaryButtonStyle(isCompact: true))
            }
            switch search.phase {
            case .idle:
                EmptyView()
            case .searching:
                HStack(spacing: Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Buscando na Wikipedia…").font(Typography.body).foregroundStyle(Theme.textSecondary)
                }
            case .results(let candidates) where candidates.isEmpty:
                Text("Nenhum resultado. Tente o nome sem número de versão ou em inglês.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            case .results(let candidates):
                Text("Qual destes é o jogo?")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                ForEach(candidates) { candidate in
                    Button {
                        Task { await search.choose(candidate, for: game, library: model.library) }
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("\(candidate.title)  ·  \(candidate.language.uppercased())")
                                .font(Typography.bodyEmphasis)
                                .foregroundStyle(Theme.textPrimary)
                            Text(candidate.snippet)
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.s + Spacing.xs)
                        .background(Theme.raised, in: RoundedRectangle.rx(Radius.m))
                        .contentShape(RoundedRectangle.rx(Radius.m))
                    }
                    .buttonStyle(.plain)
                }
            case .loading(let candidate):
                HStack(spacing: Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Lendo “\(candidate.title)”…").font(Typography.body).foregroundStyle(Theme.textSecondary)
                }
            case .failed(let message):
                StatusLine(kind: .warning, text: message)
            }
        }
        .onAppear { isQueryFocused = false }
    }
}

private struct SavedMetadata: View {
    let game: Game
    let metadata: GameMetadata
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let description = metadata.shortDescription {
                Text(description.prefix(1).uppercased() + description.dropFirst())
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(metadata.summary)
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.m, verticalSpacing: Spacing.xs) {
                if let year = metadata.releaseYear { fact(String(localized: "Lançamento"), String(year)) }
                if !metadata.developers.isEmpty { fact(String(localized: "Desenvolvedora"), metadata.developers.joined(separator: ", ")) }
                if !metadata.publishers.isEmpty { fact(String(localized: "Editora"), metadata.publishers.joined(separator: ", ")) }
                if !metadata.genres.isEmpty { fact(String(localized: "Gênero"), metadata.genres.joined(separator: ", ")) }
            }
            .padding(.top, Spacing.xs)
            HStack(spacing: Spacing.s) {
                if let url = metadata.sourceURL {
                    Link("Fonte: \(metadata.sourceName) · CC BY-SA", destination: url)
                        .font(Typography.caption)
                } else {
                    Text("Fonte: \(metadata.sourceName)").font(Typography.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button("Remover") { model.library.setMetadata(nil, for: game) }
                    .buttonStyle(SecondaryButtonStyle(isCompact: true))
            }
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).font(Typography.caption).foregroundStyle(Theme.textSecondary)
            Text(value).font(Typography.body).foregroundStyle(Theme.textPrimary)
        }
    }
}
