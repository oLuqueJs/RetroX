import RetroXCore
import SwiftUI

/// Ajustes dentro da janela, como num console: seções à esquerda, opções à direita, tudo pelo controle.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.xl) {
                SectionList()
                    .frame(width: 232)
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(model.settingsSection.title)
                            .font(Typography.display)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.bottom, Spacing.s)
                        ForEach(Array(model.settingsRows.enumerated()), id: \.element.id) { index, row in
                            SettingsRowView(row: row, isFocused: model.showsListFocus && model.settingsRow == index)
                                .onTapGesture { model.settingsRow = index }
                        }
                        SectionExtras(section: model.settingsSection)
                            .padding(.top, Spacing.m)
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.bottom, Spacing.xl)
                    .id(model.settingsSection)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
                .scrollIndicators(.never)
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.m)
            .animation(Motion.screen, value: model.settingsSection)
            HintBar(items: [
                .init(actions: [.up, .down], key: "↑  ↓", label: String(localized: "Navegar")),
                .init(actions: [.left, .right], key: "←  →", label: String(localized: "Mudar")),
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

private struct SectionList: View {
    @Environment(AppModel.self) private var model
    @Namespace private var selection

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(SettingsSection.allCases) { section in
                let isSelected = model.settingsSection == section
                let isFocused = isSelected && model.settingsRow == nil && model.showsListFocus
                Button {
                    withAnimation(Motion.focus) {
                        model.settingsSection = section
                        model.settingsRow = nil
                    }
                } label: {
                    Label(section.title, systemImage: section.symbol)
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.m)
                        .frame(height: 44)
                        .background {
                            if isSelected {
                                RoundedRectangle.rx(Radius.m).fill(Theme.accent)
                                    .matchedGeometryEffect(id: "section", in: selection)
                            }
                        }
                        .overlay {
                            RoundedRectangle.rx(Radius.m + 4)
                                .strokeBorder(Theme.accent, lineWidth: 2)
                                .padding(-4)
                                .opacity(isFocused ? 1 : 0)
                        }
                        .contentShape(RoundedRectangle.rx(Radius.m))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Spacing.s)
        .background(Theme.surface, in: RoundedRectangle.rx(Radius.l))
    }
}

struct SettingsRowView: View {
    let row: SettingsRow
    let isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(row.title)
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Theme.textPrimary)
                if let detail = row.detail {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Spacing.m)
            control
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s + Spacing.xs)
        .frame(minHeight: 60)
        .background(isFocused ? Theme.raised : Theme.surface, in: RoundedRectangle.rx(Radius.l))
        .overlay {
            RoundedRectangle.rx(Radius.l)
                .strokeBorder(Theme.accent, lineWidth: 2)
                .opacity(isFocused ? 1 : 0)
        }
        .scaleEffect(isFocused && Motion.allowsMovement(reduceMotion: false) ? 1.01 : 1)
        .animation(Motion.focus, value: isFocused)
        .contentShape(RoundedRectangle.rx(Radius.l))
    }

    @ViewBuilder
    private var control: some View {
        switch row.control {
        case .choice(let options, let selected, let select):
            HStack(spacing: Spacing.xs) {
                stepButton("chevron.left") { select((selected - 1 + options.count) % options.count) }
                Text(options[selected])
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(minWidth: 168)
                    .contentTransition(.opacity)
                    .id(options[selected])
                    .transition(.opacity)
                stepButton("chevron.right") { select((selected + 1) % options.count) }
            }
            .padding(Spacing.xs)
            .background(Theme.raised, in: Capsule())
            .animation(Motion.hover, value: selected)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(row.title): \(options[selected])")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: select((selected + 1) % options.count)
                case .decrement: select((selected - 1 + options.count) % options.count)
                @unknown default: break
                }
            }
        case .toggle(let isOn, let set):
            Toggle(row.title, isOn: Binding(get: { isOn }, set: set))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.accent)
        case .action(let label, let run):
            Button(label, action: run)
                .buttonStyle(SecondaryButtonStyle(isCompact: true))
        case .info(let text):
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .textSelection(.enabled)
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 32, height: 32)
                .background(Theme.surface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Conteúdo visual de cada seção, além das linhas: galeria de temas, prévia do texto, mapa do controle.
private struct SectionExtras: View {
    let section: SettingsSection
    @Environment(AppModel.self) private var model

    var body: some View {
        switch section {
        case .appearance:
            if let profile = model.profiles.current {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Todos os temas")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                    ThemeGallery(
                        selection: Binding(get: { profile.theme }, set: { model.setTheme($0) }),
                        accent: Binding(get: { profile.accent }, set: { model.setTheme(accent: $0) }),
                        columns: 4,
                        showsAccents: false
                    )
                }
            }
        case .text:
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Prévia")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Test Drive Unlimited")
                        .font(Typography.display)
                    Text("Corrida em mundo aberto · Jogado ontem · 4 GB")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle.rx(Radius.l))
            }
        case .controller:
            ControllerMap()
        default:
            EmptyView()
        }
    }
}

/// Mapa dos botões no RetroX conforme o tipo de controle, e o último botão apertado.
private struct ControllerMap: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let input = model.input
        let preset = input.effectivePreset
        let confirm: ControllerControl = input.confirmsWithEastButton ? .east : .south
        let back: ControllerControl = input.confirmsWithEastButton ? .south : .east
        let entries: [(ControllerControl, String)] = [
            (confirm, String(localized: "Confirmar / jogar")), (back, String(localized: "Voltar")),
            (.west, String(localized: "Detalhes")), (.north, String(localized: "Favoritar")),
            (.leftShoulder, String(localized: "Prateleira ou console anterior")), (.rightShoulder, String(localized: "Próxima prateleira ou console")),
            (.leftTrigger, String(localized: "Aba anterior")), (.rightTrigger, String(localized: "Próxima aba")),
            (.menu, String(localized: "Ajustes")), (.options, String(localized: "Emuladores")),
        ]
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(input.controllerName == nil ? Theme.textSecondary : Theme.accent)
                Text(input.controllerName.map { String(localized: "Conectado: \($0)") } ?? String(localized: "Nenhum controle conectado. Mostrando \(preset.title)."))
                    .font(Typography.body)
                    .foregroundStyle(Theme.textPrimary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible(), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(entries, id: \.0) { control, label in
                    HStack(spacing: Spacing.s) {
                        Image(systemName: preset.glyph(for: control) ?? "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 32)
                        Text(label)
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(Spacing.s + Spacing.xs)
                    .background(Theme.surface, in: RoundedRectangle.rx(Radius.m))
                }
            }
            HStack(spacing: Spacing.m) {
                Text("Último botão")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(input.lastAction.map(Self.describe) ?? "—")
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Theme.accent)
                    .id(input.actionCount)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            .animation(Motion.focus, value: input.actionCount)
            Text("O mapeamento dentro do jogo é do emulador: confira o do PCSX2 em Emuladores e mude no próprio PCSX2.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    static func describe(_ action: InputAction) -> String {
        switch action {
        case .up: String(localized: "Cima")
        case .down: String(localized: "Baixo")
        case .left: String(localized: "Esquerda")
        case .right: String(localized: "Direita")
        case .confirm: String(localized: "Confirmar")
        case .back: String(localized: "Voltar")
        case .details: String(localized: "Detalhes")
        case .favorite: String(localized: "Favoritar")
        case .previousShelf: String(localized: "Prateleira anterior")
        case .nextShelf: String(localized: "Próxima prateleira")
        case .previousTab: String(localized: "Aba anterior")
        case .nextTab: String(localized: "Próxima aba")
        case .menu: String(localized: "Ajustes")
        case .options: String(localized: "Emuladores")
        }
    }
}
