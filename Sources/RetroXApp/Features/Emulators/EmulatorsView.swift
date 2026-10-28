import AppKit
import RetroXCore
import SwiftUI

/// Os emuladores como plugins: ativar, escolher a pasta raiz e ver o que foi encontrado nela.
struct EmulatorsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    ForEach(model.plugins.entries) { entry in
                        PluginCard(entry: entry)
                    }
                    ForEach(PluginCatalog.upcoming) { upcoming in
                        UpcomingCard(upcoming: upcoming)
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxl)
                // Mesma margem esquerda da tela inicial, em vez de uma coluna centralizada.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button {
                model.screen = .home
            } label: {
                Label("Início", systemImage: "chevron.left")
            }
            .buttonStyle(SecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
            Text("Emuladores")
                .font(Typography.display)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, Spacing.m)
            Text("Ative os emuladores instalados neste Mac e diga onde eles estão. O RetroX só lê essas pastas: nada é copiado, movido ou alterado.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: 560, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, Spacing.xxl)
        .padding(.top, 56)
        .padding(.bottom, Spacing.l)
    }
}

private struct PluginCard: View {
    let entry: PluginsModel.Entry
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .center, spacing: Spacing.m) {
                SystemBadge(system: entry.plugin.systems.first ?? .ps2)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(entry.plugin.displayName)
                        .font(Typography.heading)
                        .foregroundStyle(Theme.textPrimary)
                    Text(entry.plugin.summary)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Toggle("Ativado", isOn: Binding(
                    get: { entry.config.isEnabled },
                    set: { isEnabled in Task { await model.setPlugin(entry.id, enabled: isEnabled) } }
                ))
                .toggleStyle(.switch)
                .font(Typography.body)
            }

            if entry.config.isEnabled {
                Theme.divider.frame(height: 1)
                rootFolder
                if entry.isDiscovering {
                    HStack(spacing: Spacing.s) {
                        ProgressView().controlSize(.small)
                        Text("Procurando o emulador e os jogos…")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else if let discovery = entry.discovery {
                    DiscoveryReport(entry: entry, discovery: discovery)
                }
            }
        }
        .padding(Spacing.l)
        .background(Theme.surface, in: RoundedRectangle.rx(Radius.l))
    }

    private var rootFolder: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Pasta do emulador")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(entry.rootURL.map(abbreviated) ?? String(localized: "Nenhuma pasta escolhida"))
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer()
            Button("Escolher pasta…") {
                Task { await model.chooseRoot(for: entry.id) }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

private struct DiscoveryReport: View {
    let entry: PluginsModel.Entry
    let discovery: PluginDiscovery
    @Environment(AppModel.self) private var model

    private static let host = HostEnvironment.current()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if discovery.issues.contains(.rootNotFound) {
                StatusLine(kind: .warning, text: PluginIssue.rootNotFound.message)
            } else {
                appLine
                gamesLines
                coversLine
                biosLine
                achievementsLine
                if let controller = discovery.controller {
                    ControllerMapping(controller: controller, emulator: entry.plugin.displayName)
                }
                ForEach(Array(otherIssues.enumerated()), id: \.offset) { _, issue in
                    StatusLine(kind: .warning, text: issue.message)
                }
                if discovery.settingsFile != nil {
                    StatusLine(kind: .info, text: String(localized: "Lendo a configuração do \(entry.plugin.displayName) (só leitura)."))
                }
            }
            HStack(spacing: Spacing.s) {
                Button {
                    Task { await model.rediscover(entry.id) }
                } label: {
                    Label("Procurar de novo", systemImage: "arrow.clockwise")
                }
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([discovery.root])
                } label: {
                    Label("Mostrar no Finder", systemImage: "folder")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, Spacing.s)
        }
    }

    @ViewBuilder
    private var appLine: some View {
        if let app = discovery.app {
            let architectures = app.architectures.map(\.description).sorted().joined(separator: ", ")
            let viaRosetta = Self.host.compatibility(with: app.architectures) == .rosetta
            StatusLine(kind: .ok, text: [
                "\(entry.plugin.displayName) \(app.version ?? "")",
                architectures,
                viaRosetta ? String(localized: "roda via Rosetta") : nil,
            ].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
        } else {
            StatusLine(kind: .warning, text: String(localized: "O app do \(entry.plugin.displayName) não está nesta pasta nem numa subpasta dela."))
        }
    }

    @ViewBuilder
    private var gamesLines: some View {
        if discovery.romDirectories.isEmpty {
            StatusLine(kind: .warning, text: String(localized: "Nenhuma pasta de jogos. Crie uma pasta “roms” aqui ou configure a lista de jogos no próprio emulador."))
        } else {
            let count = model.library.gameCount(for: entry.id)
            StatusLine(kind: .ok, text: count == 1 ? String(localized: "1 jogo encontrado") : String(localized: "\(count) jogos encontrados"))
            ForEach(discovery.romDirectories, id: \.self) { directory in
                StatusLine(kind: .info, text: "\(abbreviated(directory.url)) · \(origin(directory.origin))")
                    .padding(.leading, Spacing.l)
            }
        }
    }

    @ViewBuilder
    private var coversLine: some View {
        if discovery.coverDirectories.isEmpty {
            StatusLine(kind: .info, text: String(localized: "Capas são opcionais: crie uma pasta “covers” com imagens nomeadas como os jogos ou pelo serial do disco."))
        } else {
            let withCover = model.library.games.filter { $0.pluginID == entry.id && $0.coverURL != nil }.count
            StatusLine(kind: .ok, text: String(localized: "Capas para \(withCover) de \(model.library.gameCount(for: entry.id)) jogos"))
            ForEach(discovery.coverDirectories, id: \.self) { directory in
                let isInRoot = directory.standardizedFileURL.path(percentEncoded: false)
                    .hasPrefix(discovery.root.standardizedFileURL.path(percentEncoded: false))
                StatusLine(kind: .info, text: "\(abbreviated(directory)) · \(isInRoot ? String(localized: "na pasta do emulador") : String(localized: "capas do \(entry.plugin.displayName)"))")
                    .padding(.leading, Spacing.l)
            }
        }
    }

    @ViewBuilder
    private var biosLine: some View {
        switch discovery.bios {
        case .configured(let name):
            StatusLine(kind: .ok, text: String(localized: "BIOS configurada no emulador: \(name)"))
        case .fileMissing(let name):
            StatusLine(kind: .warning, text: String(localized: "A BIOS configurada no emulador (\(name)) não foi encontrada."))
        case .notConfigured:
            StatusLine(kind: .warning, text: String(localized: "BIOS não configurada: abra o emulador e conclua a configuração inicial."))
        case .unknown:
            StatusLine(kind: .info, text: String(localized: "Configuração do emulador não encontrada: ele pedirá a BIOS na primeira vez."))
        }
    }

    /// Estado do RetroAchievements no emulador. A conta é escolhida e conectada no próprio emulador.
    @ViewBuilder
    private var achievementsLine: some View {
        if let status = discovery.achievements {
            switch (status.isEnabled, status.username) {
            case (false, _):
                StatusLine(kind: .info, text: String(localized: "RetroAchievements desligado no \(entry.plugin.displayName)."))
            case (true, nil):
                StatusLine(kind: .warning, text: String(localized: "RetroAchievements ligado, mas sem conta conectada no \(entry.plugin.displayName)."))
            case (true, let username?):
                StatusLine(kind: .ok, text: String(localized: "RetroAchievements: conectado como \(username)\(status.isHardcore ? String(localized: " · hardcore") : "")"))
            }
        }
    }

    private var otherIssues: [PluginIssue] {
        discovery.issues.filter {
            switch $0 {
            case .settingsFolderMissing: true
            default: false
            }
        }
    }

    private func origin(_ origin: ROMDirectory.Origin) -> String {
        switch origin {
        case .rootFolder: String(localized: "na pasta do emulador")
        case .emulatorSettings: String(localized: "da lista de jogos do \(entry.plugin.displayName)")
        }
    }
}

private struct UpcomingCard: View {
    let upcoming: PluginCatalog.Upcoming

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 48, height: 48)
                .background(Theme.raised, in: RoundedRectangle.rx(Radius.m))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(upcoming.name)
                    .font(Typography.heading)
                    .foregroundStyle(Theme.textPrimary)
                Text(upcoming.systems)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text("Em breve")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(Theme.raised, in: Capsule())
        }
        .padding(Spacing.l)
        .background(Theme.surface.opacity(0.6), in: RoundedRectangle.rx(Radius.l))
        .accessibilityElement(children: .combine)
    }
}

private func abbreviated(_ url: URL) -> String {
    (url.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty
        ? "/" : (url.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath)
}

/// O mapeamento do controle configurado no emulador, só para conferir (não é alterado aqui).
private struct ControllerMapping: View {
    let controller: ControllerSummary
    let emulator: String

    var body: some View {
        DisclosureGroup {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.m, verticalSpacing: Spacing.xs) {
                ForEach(controller.bindings, id: \.self) { binding in
                    GridRow {
                        Text(Self.ps2Name(binding.button))
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(Theme.textPrimary)
                        Text(Self.inputName(binding.input))
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.top, Spacing.s)
            .padding(.leading, Spacing.l)
        } label: {
            StatusLine(kind: .ok, text: String(localized: "Controle no \(emulator): \(controller.type)\(controller.device.map { " · \($0)" } ?? "")"))
        }
    }

    static func ps2Name(_ button: String) -> String {
        switch button {
        case "Cross": "×"
        case "Circle": "○"
        case "Square": "□"
        case "Triangle": "△"
        case "Up": "↑"
        case "Down": "↓"
        case "Left": "←"
        case "Right": "→"
        default: button
        }
    }

    /// "SDL-0/FaceSouth" → "botão de baixo (A / ×)".
    static func inputName(_ input: String) -> String {
        let name = input.split(separator: "/").last.map(String.init) ?? input
        let names: [String: String] = [
            "FaceSouth": String(localized: "botão de baixo (A / ×)"),
            "FaceEast": String(localized: "botão da direita (B / ○)"),
            "FaceWest": String(localized: "botão da esquerda (X / □)"),
            "FaceNorth": String(localized: "botão de cima (Y / △)"),
            "DPadUp": String(localized: "direcional ↑"),
            "DPadDown": String(localized: "direcional ↓"),
            "DPadLeft": String(localized: "direcional ←"),
            "DPadRight": String(localized: "direcional →"),
            "LeftShoulder": "LB / L1",
            "RightShoulder": "RB / R1",
            "+LeftTrigger": "LT / L2",
            "+RightTrigger": "RT / R2",
            "LeftStick": String(localized: "clique do analógico esquerdo"),
            "RightStick": String(localized: "clique do analógico direito"),
            "Back": "Select / View",
            "Start": "Start / Menu",
        ]
        return names[name] ?? input
    }
}
