import RetroXCore
import SwiftUI
import UniformTypeIdentifiers

struct LaunchView: View {
    @Bindable var model: LaunchViewModel

    var body: some View {
        Form {
            Section {
                emulatorRow
            } header: {
                Text("Emulador")
            } footer: {
                emulatorFooter
            }

            Section("Jogo") {
                romRow
            }

            Section {
                Toggle("Modo simulado", isOn: $model.isDryRun)
                    .help("Valida e mostra o comando que seria usado, sem abrir o emulador.")
                HStack {
                    Spacer()
                    Button("Jogar") {
                        Task { await model.play() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .disabled(!model.canPlay)
                }
            }

            if model.status != .idle {
                Section("Status") {
                    StatusPanel(model: model, onRecovery: perform)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 480)
        .fileImporter(
            isPresented: Binding(get: { model.importer != nil }, set: { if !$0 { model.importer = nil } }),
            allowedContentTypes: contentTypes
        ) { result in
            guard case .success(let url) = result else { return }
            switch model.importer {
            case .emulator: model.selectEmulator(url)
            case .rom: model.selectROM(url)
            case nil: break
            }
            model.importer = nil
        }
        .onChange(of: model.status) { _, status in
            announce(status)
        }
    }

    private var emulatorRow: some View {
        LabeledContent {
            Button("Escolher…") { model.importer = .emulator }
        } label: {
            if let url = model.emulatorURL {
                Text(url.deletingPathExtension().lastPathComponent)
                Text(url.deletingLastPathComponent().path(percentEncoded: false))
                    .truncationMode(.middle)
            } else {
                Text("Nenhum emulador escolhido")
                Text("Escolha o PCSX2.app instalado neste Mac.")
            }
        }
    }

    @ViewBuilder
    private var emulatorFooter: some View {
        if let error = model.emulatorError {
            Label(error.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } else if let info = model.emulatorInfo {
            let architectures = info.architectures.map(\.description).sorted().joined(separator: ", ")
            Text("\(info.bundleIdentifier ?? "?") · versão \(info.version ?? "?") · \(architectures.isEmpty ? "arquitetura desconhecida" : architectures)")
        }
    }

    private var romRow: some View {
        LabeledContent {
            Button("Escolher…") { model.importer = .rom }
        } label: {
            if let url = model.romURL {
                Text(TitleParser.displayTitle(fromFilename: url.lastPathComponent))
                Text(url.lastPathComponent)
                    .truncationMode(.middle)
            } else {
                Text("Nenhum jogo escolhido")
                Text("Formatos: \(model.adapter.supportedExtensions(for: .ps2).sorted().joined(separator: ", "))")
            }
        }
    }

    private var contentTypes: [UTType] {
        switch model.importer {
        case .emulator:
            [.applicationBundle]
        case .rom, nil:
            model.adapter.supportedExtensions(for: .ps2).sorted().compactMap { UTType(filenameExtension: $0) }
        }
    }

    private func perform(_ action: RecoveryAction) {
        switch action {
        case .chooseEmulator, .openSettings: model.importer = .emulator
        case .locateROM: model.importer = .rom
        case .retry: Task { await model.play() }
        case .bringEmulatorToFront: model.bringEmulatorToFront()
        case .showRosettaHelp: break
        }
    }

    private func announce(_ status: LaunchViewModel.Status) {
        let message: String? = switch status {
        case .failed(let error): error.message
        case .running: String(localized: "Jogo aberto no emulador.")
        case .ended: String(localized: "Sessão encerrada.")
        default: nil
        }
        if let message {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

private struct StatusPanel: View {
    let model: LaunchViewModel
    let onRecovery: (RecoveryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(model.warnings, id: \.message) { warning in
                Label(warning.message, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch model.status {
        case .idle:
            EmptyView()
        case .planned(let plan):
            Label("Modo simulado: nada foi aberto.", systemImage: "eye")
            Text("Estratégia: \(plan.strategy.rawValue)")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(plan.arguments.enumerated()), id: \.offset) { index, argument in
                    Text("[\(index)] \(argument)")
                }
            }
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Argumentos: \(plan.arguments.joined(separator: ", "))")
        case .launching:
            HStack {
                ProgressView().controlSize(.small)
                Text("Abrindo no PCSX2…")
            }
        case .running:
            Label("Em jogo no PCSX2. O RetroX volta à frente quando o emulador fechar.", systemImage: "gamecontroller")
            Button("Trazer emulador para frente") { onRecovery(.bringEmulatorToFront) }
        case .ended(let after):
            Label("Sessão encerrada após \(after.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))).",
                  systemImage: "checkmark.circle")
        case .failed(let error):
            Label(error.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            if error.recoveryActions.contains(.showRosettaHelp) {
                Text("No Terminal: softwareupdate --install-rosetta")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            HStack {
                ForEach(error.recoveryActions.filter { $0 != .showRosettaHelp }, id: \.self) { action in
                    Button(action.title) { onRecovery(action) }
                }
            }
        }
    }
}
