import AppKit
import Observation
import RetroXCore

/// Emuladores (plugins) que o usuário ativou, a pasta raiz de cada um e o que foi encontrado nela.
@MainActor
@Observable
final class PluginsModel {
    struct Entry: Identifiable {
        let plugin: any EmulatorPlugin
        var config: PluginConfig
        var discovery: PluginDiscovery?
        var isDiscovering = false

        var id: EmulatorPluginID { plugin.id }
        var rootURL: URL? { config.rootPath.map { URL(filePath: $0, directoryHint: .isDirectory) } }
        var isReady: Bool { config.isEnabled && discovery?.isReady == true }
    }

    private(set) var entries: [Entry]
    /// Emuladores conhecidos ainda sem plugin, com o app encontrado neste Mac (se houver).
    private(set) var otherEmulators: [(PluginCatalog.KnownEmulator, URL?)] = []
    @ObservationIgnored private let store: JSONFileStore<[String: PluginConfig]>

    init(
        catalog: [any EmulatorPlugin] = PluginCatalog.available,
        store: JSONFileStore<[String: PluginConfig]> = JSONFileStore(url: RetroXDirectories.applicationSupport.appending(path: "plugins.json"))
    ) {
        self.store = store
        let saved = store.load() ?? [:]
        entries = catalog.map { Entry(plugin: $0, config: saved[$0.id.rawValue] ?? PluginConfig()) }
    }

    var readyPlugins: [(any EmulatorPlugin, PluginDiscovery)] {
        entries.compactMap { entry in
            guard entry.isReady, let discovery = entry.discovery else { return nil }
            return (entry.plugin, discovery)
        }
    }

    var hasEnabledPlugin: Bool { entries.contains { $0.config.isEnabled } }

    func entry(_ id: EmulatorPluginID) -> Entry? {
        entries.first { $0.id == id }
    }

    /// Ativar sem pasta raiz abre o seletor; cancelar o seletor deixa o plugin desativado.
    func setEnabled(_ id: EmulatorPluginID, _ isEnabled: Bool) async {
        guard let entry = entry(id) else { return }
        if isEnabled, entry.config.rootPath == nil {
            await chooseRoot(for: id)
            return
        }
        update(id) { $0.config.isEnabled = isEnabled }
        if isEnabled, entry.discovery == nil { await discover(id) }
    }

    func chooseRoot(for id: EmulatorPluginID) async {
        guard let entry = entry(id) else { return }
        let message = String(localized: "Escolha a pasta do \(entry.plugin.displayName): a que tem o app do emulador e as pastas de jogos.")
        guard let url = await FilePanel.chooseFolder(message: message, startingAt: entry.rootURL) else { return }
        update(id) {
            $0.config.rootPath = url.path(percentEncoded: false)
            $0.config.isEnabled = true
            $0.discovery = nil
        }
        await discover(id)
    }

    func discover(_ id: EmulatorPluginID) async {
        guard let entry = entry(id), let root = entry.rootURL else { return }
        update(id) { $0.isDiscovering = true }
        let plugin = entry.plugin
        let discovery = await Task.detached(priority: .userInitiated) { plugin.discover(root: root) }.value
        update(id) {
            $0.discovery = discovery
            $0.isDiscovering = false
        }
    }

    func discoverAll() async {
        otherEmulators = PluginCatalog.known.compactMap { emulator in
            let app = emulator.bundleIdentifiers.lazy.compactMap { NSWorkspace.shared.urlsForApplications(withBundleIdentifier: $0).first }.first
            return emulator.isPlanned || app != nil ? (emulator, app) : nil
        }
        for entry in entries where entry.config.isEnabled {
            await discover(entry.id)
        }
    }

    private func update(_ id: EmulatorPluginID, _ change: (inout Entry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let previous = entries[index].config
        change(&entries[index])
        if entries[index].config != previous {
            try? store.save(Dictionary(uniqueKeysWithValues: entries.map { ($0.id.rawValue, $0.config) }))
        }
    }
}
