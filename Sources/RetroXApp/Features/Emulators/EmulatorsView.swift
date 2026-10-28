import AppKit
import RetroXCore
import SwiftUI

/// Os emuladores como plugins: ativar, escolher a pasta raiz e ver o que foi encontrado nela.
/// Tudo alcançável pelo controle (↑ ↓ passa pelos botões, A ativa).
struct EmulatorsView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("Emuladores")
                                .font(Typography.display)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Ative os emuladores instalados neste Mac e diga onde eles estão. O RetroX só lê essas pastas: nada é copiado, movido ou alterado.")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: 600, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(model.plugins.entries) { entry in
                            PluginCard(entry: entry)
                        }
                        if !model.plugins.otherEmulators.isEmpty {
                            OtherEmulators()
                        }
                    }
                    .frame(maxWidth: 880, alignment: .leading)
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xxl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: model.emulatorsFocus) { _, index in
                    let controls = model.emulatorControls
                    guard controls.indices.contains(index) else { return }
                    withAnimation(Motion.focus) { scroll.scrollTo(controls[index].id, anchor: .center) }
                }
            }
            HintBar(items: [
                .init(actions: [.up, .down], key: "↑  ↓", label: String(localized: "Navegar")),
                .init(action: .confirm, key: "↩", label: String(localized: "Escolher")),
                .init(action: .back, key: "Esc", label: String(localized: "Voltar")),
            ], showsMenu: false)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard !press.modifiers.contains(.command), let action = KeyMapping.action(for: press) else { return .ignored }
            model.handle(action)
            return .handled
        }
    }
}

extension View {
    /// Anel de foco para controles alcançados pelo teclado ou controle de jogo.
    func controllerFocus(_ isFocused: Bool, radius: CGFloat = 26) -> some View {
        overlay {
            RoundedRectangle.rx(radius)
                .strokeBorder(Theme.accent, lineWidth: 2.5)
                .padding(-5)
                .opacity(isFocused ? 1 : 0)
        }
        .scaleEffect(isFocused && Motion.settings.level == .full ? 1.03 : 1)
        .animation(Motion.focus, value: isFocused)
    }
}

/// Ícone do app instalado (o mesmo que o Finder mostra), ou um selo genérico.
struct EmulatorIcon: View {
    let appURL: URL?
    var fallbackSystem: GameSystemID?
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let appURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path(percentEncoded: false)))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else if let fallbackSystem {
                SystemBadge(system: fallbackSystem, size: size * 0.86)
            } else {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: size * 0.86, height: size * 0.86)
                    .background(Theme.raised, in: RoundedRectangle.rx(Radius.l))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct PluginCard: View {
    let entry: PluginsModel.Entry
    @Environment(AppModel.self) private var model

    var body: some View {
        let id = entry.id.rawValue
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(alignment: .center, spacing: Spacing.m) {
                EmulatorIcon(appURL: entry.discovery?.app?.bundleURL, fallbackSystem: entry.plugin.systems.first, size: 72)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.s) {
                        Text(entry.plugin.displayName)
                            .font(Typography.heading)
                            .foregroundStyle(Theme.textPrimary)
                        if let version = entry.discovery?.app?.version {
                            Text(version)
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, Spacing.s)
                                .padding(.vertical, Spacing.xxs)
                                .background(Theme.raised, in: Capsule())
                        }
                    }
                    Text(entry.plugin.summary)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                    StatusPill(entry: entry)
                }
                Spacer()
                Toggle("Ativado", isOn: Binding(
                    get: { entry.config.isEnabled },
                    set: { isEnabled in Task { await model.setPlugin(entry.id, enabled: isEnabled) } }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.accent)
                .padding(Spacing.xs)
                .controllerFocus(model.isFocused(emulatorControl: "\(id).toggle"))
                .id("\(id).toggle")
                .accessibilityLabel("Ativar \(entry.plugin.displayName)")
            }

            if entry.config.isEnabled {
                RootFolderRow(entry: entry)
                if entry.isDiscovering {
                    HStack(spacing: Spacing.s) {
                        ProgressView().controlSize(.small)
                        Text("Procurando o emulador e os jogos…")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .transition(.opacity)
                } else if let discovery = entry.discovery {
                    DiscoverySummary(entry: entry, discovery: discovery)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
        }
        .padding(Spacing.l)
        .background(Theme.surface, in: RoundedRectangle.rx(Radius.xl))
        .animation(Motion.screen, value: entry.config.isEnabled)
        .animation(Motion.screen, value: entry.isDiscovering)
    }
}

private struct StatusPill: View {
    let entry: PluginsModel.Entry

    var body: some View {
        let (text, symbol, isGood): (String, String, Bool) = {
            if !entry.config.isEnabled { return (String(localized: "Desativado"), "pause.circle", false) }
            if entry.config.rootPath == nil { return (String(localized: "Escolha a pasta"), "folder.badge.questionmark", false) }
            if entry.isDiscovering { return (String(localized: "Procurando…"), "magnifyingglass", false) }
            if entry.isReady { return (String(localized: "Pronto"), "checkmark.circle.fill", true) }
            return (String(localized: "Precisa de atenção"), "exclamationmark.triangle.fill", false)
        }()
        Label(text, systemImage: symbol)
            .font(Typography.caption)
            .foregroundStyle(isGood ? Theme.onAccent : Theme.textPrimary)
            .padding(.horizontal, Spacing.s + Spacing.xxs)
            .padding(.vertical, Spacing.xs)
            .background(isGood ? Theme.accent : Theme.raised, in: Capsule())
            .contentTransition(.opacity)
    }
}

private struct RootFolderRow: View {
    let entry: PluginsModel.Entry
    @Environment(AppModel.self) private var model

    var body: some View {
        let id = entry.id.rawValue
        HStack(alignment: .center, spacing: Spacing.m) {
            Image(systemName: "folder.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.raised, in: RoundedRectangle.rx(Radius.m))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
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
            .controllerFocus(model.isFocused(emulatorControl: "\(id).root"))
            .id("\(id).root")
        }
        .padding(Spacing.m)
        .background(Theme.background.opacity(0.5), in: RoundedRectangle.rx(Radius.l))
    }
}

/// Resumo em blocos (app, jogos, capas, BIOS), avisos, ações e os detalhes recolhíveis.
private struct DiscoverySummary: View {
    let entry: PluginsModel.Entry
    let discovery: PluginDiscovery
    @Environment(AppModel.self) private var model

    var body: some View {
        let id = entry.id.rawValue
        VStack(alignment: .leading, spacing: Spacing.m) {
            if discovery.issues.contains(.rootNotFound) {
                StatusLine(kind: .warning, text: PluginIssue.rootNotFound.message)
            } else {
                HStack(spacing: Spacing.s) {
                    StatTile(symbol: "app.badge.checkmark", value: discovery.app == nil ? "—" : String(localized: "Encontrado"),
                             label: discovery.app.map(appDetail) ?? String(localized: "App não encontrado"), isGood: discovery.app != nil)
                    StatTile(symbol: "gamecontroller", value: "\(gameCount)", label: String(localized: "jogos"), isGood: gameCount > 0)
                    StatTile(symbol: "photo.on.rectangle", value: "\(coverCount)/\(gameCount)", label: String(localized: "com capa"), isGood: coverCount > 0)
                    StatTile(symbol: "cpu", value: biosValue, label: String(localized: "BIOS"), isGood: biosIsGood)
                }
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    StatusLine(kind: .warning, text: warning)
                }
                HStack(spacing: Spacing.s) {
                    Button {
                        Task { await model.rediscover(entry.id) }
                    } label: {
                        Label("Procurar de novo", systemImage: "arrow.clockwise")
                    }
                    .controllerFocus(model.isFocused(emulatorControl: "\(id).rediscover"))
                    .id("\(id).rediscover")
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([discovery.root])
                    } label: {
                        Label("Mostrar no Finder", systemImage: "folder")
                    }
                    .controllerFocus(model.isFocused(emulatorControl: "\(id).reveal"))
                    .id("\(id).reveal")
                }
                .buttonStyle(SecondaryButtonStyle())
                DisclosureGroup {
                    DetailsList(entry: entry, discovery: discovery)
                        .padding(.top, Spacing.s)
                } label: {
                    Text("Pastas, BIOS e controle")
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    private var gameCount: Int { model.library.gameCount(for: entry.id) }

    private var coverCount: Int {
        model.library.games.filter { $0.pluginID == entry.id && $0.coverURL != nil }.count
    }

    private func appDetail(_ app: AppBundleInfo) -> String {
        let architectures = app.architectures.map(\.description).sorted().joined(separator: ", ")
        let viaRosetta = HostEnvironment.current().compatibility(with: app.architectures) == .rosetta
        return viaRosetta ? String(localized: "\(architectures) · via Rosetta") : architectures
    }

    private var biosValue: String {
        switch discovery.bios {
        case .configured: String(localized: "Configurada")
        case .fileMissing: String(localized: "Ausente")
        case .notConfigured: String(localized: "Falta")
        case .unknown: "—"
        }
    }

    private var biosIsGood: Bool {
        if case .configured = discovery.bios { return true }
        return false
    }

    private var warnings: [String] {
        var result: [String] = []
        if discovery.romDirectories.isEmpty {
            result.append(String(localized: "Nenhuma pasta de jogos. Crie uma pasta “roms” aqui ou configure a lista de jogos no próprio emulador."))
        }
        switch discovery.bios {
        case .fileMissing(let name): result.append(String(localized: "A BIOS configurada no emulador (\(name)) não foi encontrada."))
        case .notConfigured: result.append(String(localized: "BIOS não configurada: abra o emulador e conclua a configuração inicial."))
        default: break
        }
        for issue in discovery.issues {
            if case .settingsFolderMissing = issue { result.append(issue.message) }
        }
        return result
    }
}

private struct StatTile: View {
    let symbol: String
    let value: String
    let label: String
    let isGood: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isGood ? Theme.accent : Theme.textSecondary)
            Text(value)
                .font(Typography.heading)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Theme.background.opacity(0.5), in: RoundedRectangle.rx(Radius.l))
        .accessibilityElement(children: .combine)
    }
}

private struct DetailsList: View {
    let entry: PluginsModel.Entry
    let discovery: PluginDiscovery

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(discovery.romDirectories, id: \.self) { directory in
                StatusLine(kind: .info, text: "\(abbreviated(directory.url)) · \(origin(directory.origin))")
            }
            ForEach(discovery.coverDirectories, id: \.self) { directory in
                let isInRoot = directory.standardizedFileURL.path(percentEncoded: false)
                    .hasPrefix(discovery.root.standardizedFileURL.path(percentEncoded: false))
                StatusLine(kind: .info, text: "\(abbreviated(directory)) · \(isInRoot ? String(localized: "capas na pasta do emulador") : String(localized: "capas do \(entry.plugin.displayName)"))")
            }
            if case .configured(let name) = discovery.bios {
                StatusLine(kind: .ok, text: String(localized: "BIOS: \(name)"))
            }
            if discovery.settingsFile != nil {
                StatusLine(kind: .info, text: String(localized: "Lendo a configuração do \(entry.plugin.displayName) (só leitura)."))
            }
            if let controller = discovery.controller {
                ControllerMapping(controller: controller, emulator: entry.plugin.displayName)
                    .padding(.top, Spacing.s)
            }
        }
    }

    private func origin(_ origin: ROMDirectory.Origin) -> String {
        switch origin {
        case .rootFolder: String(localized: "jogos na pasta do emulador")
        case .emulatorSettings: String(localized: "da lista de jogos do \(entry.plugin.displayName)")
        }
    }
}

/// Emuladores reconhecidos sem plugin: o planejado (Dolphin) e os que já estão instalados neste Mac.
private struct OtherEmulators: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Outros emuladores")
                .font(Typography.heading)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, Spacing.s)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)], spacing: Spacing.m) {
                ForEach(model.plugins.otherEmulators, id: \.0.id) { emulator, app in
                    HStack(spacing: Spacing.m) {
                        EmulatorIcon(appURL: app, size: 48)
                            .saturation(app == nil ? 0 : 1)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(emulator.name)
                                .font(Typography.bodyEmphasis)
                                .foregroundStyle(Theme.textPrimary)
                            Text(emulator.systems)
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text(app == nil ? String(localized: "Em breve") : String(localized: "Instalado · plugin em breve"))
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(Spacing.m)
                    .background(Theme.surface.opacity(0.7), in: RoundedRectangle.rx(Radius.l))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// O mapeamento do controle configurado no emulador, só para conferir (não é alterado aqui).
private struct ControllerMapping: View {
    let controller: ControllerSummary
    let emulator: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StatusLine(kind: .ok, text: String(localized: "Controle no \(emulator): \(controller.type)\(controller.device.map { " · \($0)" } ?? "")"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible(), spacing: Spacing.s)], alignment: .leading, spacing: Spacing.xs) {
                ForEach(controller.bindings, id: \.self) { binding in
                    HStack(spacing: Spacing.s) {
                        Text(Self.ps2Name(binding.button))
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, alignment: .leading)
                        Text(Self.inputName(binding.input))
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.leading, Spacing.l)
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

private func abbreviated(_ url: URL) -> String {
    (url.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
}
