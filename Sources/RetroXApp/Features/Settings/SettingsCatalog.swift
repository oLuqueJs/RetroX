import AppKit
import RetroXCore

enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance, home, library, text, controller, animations, about

    var id: Self { self }

    var title: String {
        switch self {
        case .appearance: String(localized: "Aparência")
        case .home: String(localized: "Tela inicial")
        case .library: String(localized: "Biblioteca")
        case .text: String(localized: "Texto")
        case .controller: String(localized: "Controle")
        case .animations: String(localized: "Animações")
        case .about: String(localized: "Sobre")
        }
    }

    var symbol: String {
        switch self {
        case .appearance: "paintpalette"
        case .home: "house"
        case .library: "square.grid.2x2"
        case .text: "textformat.size"
        case .controller: "gamecontroller"
        case .animations: "wand.and.stars"
        case .about: "info.circle"
        }
    }
}

/// Uma linha de ajuste. A mesma lista desenha a tela e responde ao controle (← → muda, A ativa).
struct SettingsRow: Identifiable {
    enum Control {
        case choice(options: [String], selected: Int, select: @MainActor (Int) -> Void)
        case toggle(isOn: Bool, set: @MainActor (Bool) -> Void)
        case action(label: String, run: @MainActor () -> Void)
        case info(String)
    }

    let id: String
    let title: String
    var detail: String?
    let control: Control

    @MainActor
    func step(by offset: Int) {
        switch control {
        case .choice(let options, let selected, let select):
            select((selected + offset + options.count) % options.count)
        case .toggle(let isOn, let set):
            set(!isOn)
        case .action, .info:
            break
        }
    }

    @MainActor
    func activate() {
        switch control {
        case .choice: step(by: 1)
        case .toggle(let isOn, let set): set(!isOn)
        case .action(_, let run): run()
        case .info: break
        }
    }
}

extension AppModel {
    var settingsRows: [SettingsRow] { rows(for: settingsSection) }

    func rows(for section: SettingsSection) -> [SettingsRow] {
        let preferences = self.preferences
        switch section {
        case .appearance:
            guard let profile = profiles.current else { return [] }
            var rows = [
                choice("theme", String(localized: "Tema"), ThemeID.allCases, profile.theme, \.title) { self.setTheme($0) },
            ]
            if profile.theme == .retrox {
                rows.append(choice("accent", String(localized: "Acento"), Palette.Accent.allCases, profile.accent, \.title) { self.setTheme(accent: $0) })
            }
            rows.append(choice("appearance", String(localized: "Modo"), AppearancePreference.allCases, profile.appearance, \.title) {
                self.setTheme(appearance: $0)
            })
            rows.append(toggle("ambient", String(localized: "Fundo ambiente"),
                               detail: String(localized: "A capa do jogo em foco, desfocada, atrás da tela."),
                               preferences.ambientBackground) { value in self.updatePreferences { $0.ambientBackground = value } })
            return rows
        case .home:
            return [
                choice("homeStyle", String(localized: "Visualização"), ProfilePreferences.HomeStyle.allCases, preferences.homeStyle, \.title) { value in
                    self.updatePreferences { $0.homeStyle = value }
                },
                choice("tileSize", String(localized: "Tamanho das capas"), ProfilePreferences.TileSize.allCases, preferences.tileSize, \.title) { value in
                    self.updatePreferences { $0.tileSize = value }
                },
                choice("startShelf", String(localized: "Prateleira ao abrir"), ProfilePreferences.StartShelf.allCases, preferences.startShelf, \.title) { value in
                    self.updatePreferences { $0.startShelf = value }
                },
                toggle("clock", String(localized: "Relógio na barra"), preferences.showsClock) { value in self.updatePreferences { $0.showsClock = value } },
                toggle("favoriteBadge", String(localized: "Estrela nos favoritos"), preferences.showsFavoriteBadge) { value in
                    self.updatePreferences { $0.showsFavoriteBadge = value }
                },
            ]
        case .library:
            return [
                choice("libraryLayout", String(localized: "Visualização padrão"), LibraryBrowser.Layout.allCases, browser.layout, \.title) {
                    self.browser.setLayout($0)
                },
                choice("librarySort", String(localized: "Ordem padrão"), LibraryBrowser.Sort.allCases, browser.sort, \.title) {
                    self.browser.setSort($0)
                },
            ]
        case .text:
            return [
                choice("font", String(localized: "Fonte"), ProfilePreferences.FontStyle.allCases, preferences.fontStyle, \.title) { value in
                    self.updatePreferences { $0.fontStyle = value }
                },
                choice("textSize", String(localized: "Tamanho do texto"), ProfilePreferences.TextSize.allCases, preferences.textSize, \.title) { value in
                    self.updatePreferences { $0.textSize = value }
                },
            ]
        case .controller:
            return [
                choice("preset", String(localized: "Tipo de controle"), ControllerPreset.allCases, input.preset, \.title) { self.input.setPreset($0) },
                toggle("swap", String(localized: "Inverter confirmar e voltar"),
                       detail: String(localized: input.confirmsWithEastButton ? "Agora: confirma com o botão da direita." : "Agora: confirma com o botão de baixo."),
                       input.swapsConfirmAndBack) { self.input.setSwapsConfirmAndBack($0) },
                choice("repeat", String(localized: "Repetição ao segurar"), RepeatSpeed.allCases, input.repeatSpeed, \.title) { self.input.setRepeatSpeed($0) },
                choice("hints", String(localized: "Dicas de botões"), HintsMode.allCases, input.hintsMode, \.title) { self.input.setHintsMode($0) },
            ]
        case .animations:
            return [
                choice("animationLevel", String(localized: "Animações"), ProfilePreferences.AnimationLevel.allCases, preferences.animationLevel, \.title) { value in
                    self.updatePreferences { $0.animationLevel = value }
                },
                choice("animationSpeed", String(localized: "Velocidade"), ProfilePreferences.AnimationSpeed.allCases, preferences.animationSpeed, \.title) { value in
                    self.updatePreferences { $0.animationSpeed = value }
                },
                toggle("startup", String(localized: "Animação de abertura"), preferences.startupAnimation) { value in
                    self.updatePreferences { $0.startupAnimation = value }
                },
            ]
        case .about:
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
            return [
                SettingsRow(id: "version", title: String(localized: "Versão"), control: .info("RetroX \(version)")),
                SettingsRow(id: "emulators", title: String(localized: "Emuladores ativos"),
                            control: .info(plugins.entries.filter(\.config.isEnabled).map(\.plugin.displayName).joined(separator: ", ").nilIfEmpty
                                ?? String(localized: "Nenhum"))),
                SettingsRow(id: "data", title: String(localized: "Dados do RetroX"), detail: String(localized: "Perfis, favoritos, capas próprias e configuração dos emuladores."),
                            control: .action(label: String(localized: "Mostrar no Finder")) {
                                NSWorkspace.shared.activateFileViewerSelecting([RetroXDirectories.applicationSupport])
                            }),
                SettingsRow(id: "profiles", title: String(localized: "Perfis"), control: .action(label: String(localized: "Trocar de perfil")) { self.showProfiles() }),
            ]
        }
    }

    private func choice<Value: Equatable>(
        _ id: String, _ title: String, _ options: [Value], _ selected: Value, _ name: KeyPath<Value, String>,
        select: @escaping @MainActor (Value) -> Void
    ) -> SettingsRow {
        SettingsRow(id: id, title: title, control: .choice(
            options: options.map { $0[keyPath: name] },
            selected: options.firstIndex(of: selected) ?? 0,
            select: { select(options[$0]) }
        ))
    }

    private func toggle(_ id: String, _ title: String, detail: String? = nil, _ isOn: Bool, set: @escaping @MainActor (Bool) -> Void) -> SettingsRow {
        SettingsRow(id: id, title: title, detail: detail, control: .toggle(isOn: isOn, set: set))
    }
}
