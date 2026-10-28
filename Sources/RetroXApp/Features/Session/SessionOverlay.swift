import RetroXCore
import SwiftUI

/// Cobre a tela enquanto o emulador abre e roda, e mostra como a partida terminou.
struct SessionOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.background.opacity(0.94)
                .ignoresSafeArea()
            if let game {
                HStack(alignment: .center, spacing: Spacing.xl) {
                    CoverArtView(game: game, width: 140)
                        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text(overline)
                            .font(Typography.caption)
                            .tracking(1.4)
                            .foregroundStyle(Theme.textSecondary)
                        Text(game.title)
                            .font(Typography.heading)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        detail(for: game)
                    }
                    .frame(maxWidth: 420, alignment: .leading)
                }
                .padding(Spacing.xl)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var game: Game? {
        switch model.session.phase {
        case .idle: nil
        case .launching(let game), .running(let game, _), .ended(let game, _), .failed(let game, _): game
        }
    }

    private var overline: String {
        switch model.session.phase {
        case .idle: ""
        case .launching: String(localized: "Abrindo")
        case .running(_, let emulator): String(localized: "Em jogo no \(emulator)")
        case .ended: String(localized: "Partida encerrada")
        case .failed: String(localized: "Não foi possível jogar")
        }
    }

    @ViewBuilder
    private func detail(for game: Game) -> some View {
        switch model.session.phase {
        case .idle:
            EmptyView()
        case .launching:
            HStack(spacing: Spacing.s) {
                ProgressView().controlSize(.small)
                Text("Preparando o emulador…")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        case .running:
            Text("O RetroX volta para cá quando o emulador fechar.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
            ForEach(model.session.warnings, id: \.message) { warning in
                StatusLine(kind: .info, text: warning.message)
            }
            Button("Trazer emulador para frente") {
                model.session.bringEmulatorToFront()
            }
            .buttonStyle(SecondaryButtonStyle())
        case .ended(_, let after):
            Text("Você jogou por \(after.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, maximumUnitCount: 2).locale(AppLocale.current))).")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
            Button("Continuar") {
                model.session.dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        case .failed(_, let error):
            StatusLine(kind: .warning, text: error.message)
            if error.recoveryActions.contains(.showRosettaHelp) {
                Text("No Terminal: softwareupdate --install-rosetta")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .textSelection(.enabled)
            }
            HStack(spacing: Spacing.s) {
                ForEach(Array(error.recoveryActions.filter { $0 != .showRosettaHelp }.enumerated()), id: \.element) { index, action in
                    Button(title(for: action)) {
                        model.perform(action, for: game)
                    }
                    .buttonStyle(RecoveryButtonStyle(isPrimary: index == 0))
                }
                Button("Fechar") {
                    model.session.dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    /// "Localizar arquivo" vira "Procurar jogos de novo": a biblioteca vem das pastas do emulador.
    private func title(for action: RecoveryAction) -> String {
        switch action {
        case .locateROM: String(localized: "Procurar jogos de novo")
        case .chooseEmulator, .openSettings: String(localized: "Abrir Emuladores")
        default: action.title
        }
    }
}

private struct RecoveryButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        if isPrimary {
            PrimaryButtonStyle().makeBody(configuration: configuration)
        } else {
            SecondaryButtonStyle().makeBody(configuration: configuration)
        }
    }
}
