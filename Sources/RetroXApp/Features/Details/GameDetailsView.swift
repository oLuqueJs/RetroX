import AppKit
import RetroXCore
import SwiftUI

struct GameDetailsView: View {
    let game: Game
    @Environment(AppModel.self) private var model

    var body: some View {
        let history = model.library.history(for: game)
        HStack(alignment: .top, spacing: Spacing.xl) {
            CoverArtView(game: game, width: 200)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text((SystemCatalog.system(game.systemID)?.displayName ?? "").uppercased())
                    .font(Typography.caption)
                    .tracking(1.4)
                    .foregroundStyle(Theme.textSecondary)
                Text(game.title)
                    .font(Typography.heading)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.m, verticalSpacing: Spacing.s) {
                    row(String(localized: "Arquivo"), game.romURL.lastPathComponent)
                    row(String(localized: "Pasta"), (game.romURL.deletingLastPathComponent().path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath)
                    row(String(localized: "Tamanho"), game.fileSize.formatted(.byteCount(style: .file).locale(AppLocale.current)))
                    if let serial = game.serial {
                        row(String(localized: "Serial"), serial)
                    }
                    row(String(localized: "Emulador"), emulatorDescription)
                    row(String(localized: "Partidas"), playsDescription(history))
                }
                DisclosureGroup("Comando de abertura") {
                    commandPlan
                        .padding(.top, Spacing.s)
                }
                .font(Typography.body)
                Spacer(minLength: 0)
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
                    Button("Fechar") {
                        model.detailsGame = nil
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(Spacing.xl)
        .frame(width: 760, height: 460)
        .background(Theme.surface)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
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
