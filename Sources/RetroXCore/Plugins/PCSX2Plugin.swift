import Foundation

/// Plugin nativo do PCSX2. A partir da pasta raiz do emulador (a que guarda o `.app`, as ROMs, as capas e a BIOS),
/// encontra o app e as pastas de jogos, e lê, sem alterar, a configuração do próprio PCSX2 (`inis/PCSX2.ini`):
/// pastas da lista de jogos, pasta de capas e BIOS escolhida.
public struct PCSX2Plugin: EmulatorPlugin {
    public let id = EmulatorPluginID.pcsx2
    public let displayName = "PCSX2"
    public var summary: String { String(localized: "PlayStation 2 · plugin nativo") }
    public let systems: [GameSystemID] = [.ps2]
    public var adapter: any EmulatorAdapter { PCSX2Adapter() }

    /// Nomes de subpastas tratadas como pastas de jogos (sem diferença de caixa).
    static let romFolderNames: Set<String> = ["roms", "rom", "games", "jogos", "isos", "iso", "ps2"]
    static let coverFolderNames: Set<String> = ["covers", "capas", "boxart", "artwork"]

    private let fileSystem: any FileSystemProbing
    private let defaultDataDirectory: URL

    /// `defaultDataDirectory` é onde o PCSX2 guarda a configuração fora do modo portátil.
    public init(
        fileSystem: any FileSystemProbing = LocalFileSystem(),
        defaultDataDirectory: URL = URL.homeDirectory.appending(path: "Library/Application Support/PCSX2", directoryHint: .isDirectory)
    ) {
        self.fileSystem = fileSystem
        self.defaultDataDirectory = defaultDataDirectory
    }

    public func discover(root selected: URL) -> PluginDiscovery {
        // Aceita também o próprio .app: a raiz passa a ser a pasta que o contém.
        let root = selected.pathExtension.lowercased() == "app" ? selected.deletingLastPathComponent() : selected
        var discovery = PluginDiscovery(root: root)
        guard fileSystem.kind(of: root) == .directory else {
            discovery.issues = [.rootNotFound]
            return discovery
        }

        let children = fileSystem.contentsOfDirectory(at: root)
        discovery.app = findApp(in: children)
        if discovery.app == nil { discovery.issues.append(.appNotFound) }

        let dataDirectory = discovery.app.flatMap(portableDataDirectory) ?? defaultDataDirectory
        let settingsURL = dataDirectory.appending(path: "inis/PCSX2.ini", directoryHint: .notDirectory)
        let settings = fileSystem.readText(of: settingsURL).map(INIFile.init)
        if settings != nil { discovery.settingsFile = settingsURL }

        var romDirectories: [ROMDirectory] = []
        for child in children where fileSystem.kind(of: child) == .directory && child.pathExtension.lowercased() != "app" {
            if Self.romFolderNames.contains(child.lastPathComponent.lowercased()) {
                romDirectories.append(ROMDirectory(url: child, origin: .rootFolder, isRecursive: true))
            } else if Self.coverFolderNames.contains(child.lastPathComponent.lowercased()) {
                discovery.coverDirectories.append(child)
            }
        }
        let extensions = adapter.supportedExtensions(for: .ps2)
        if children.contains(where: { extensions.contains($0.pathExtension.lowercased()) }) {
            romDirectories.append(ROMDirectory(url: root, origin: .rootFolder, isRecursive: false))
        }

        if let settings {
            let listed = settings.values("Paths", in: "GameList").map { ($0, false) }
                + settings.values("RecursivePaths", in: "GameList").map { ($0, true) }
            for (path, isRecursive) in listed where !path.isEmpty {
                let url = resolve(path, relativeTo: dataDirectory)
                if fileSystem.kind(of: url) == .directory {
                    romDirectories.append(ROMDirectory(url: url, origin: .emulatorSettings, isRecursive: isRecursive))
                } else {
                    discovery.issues.append(.settingsFolderMissing(path))
                }
            }
            let coversURL = resolve(settings.value("Covers", in: "Folders") ?? "covers", relativeTo: dataDirectory)
            if fileSystem.kind(of: coversURL) == .directory { discovery.coverDirectories.append(coversURL) }
            discovery.bios = biosStatus(settings: settings, dataDirectory: dataDirectory)
            discovery.controller = Self.controller(settings)
        }
        if let app = discovery.app {
            let index = app.bundleURL.appending(path: "Contents/Resources/GameIndex.yaml", directoryHint: .notDirectory)
            if fileSystem.kind(of: index) == .regularFile { discovery.gameIndexFile = index }
        }

        discovery.romDirectories = Self.merged(romDirectories)
        if discovery.romDirectories.isEmpty { discovery.issues.append(.noROMDirectories) }
        return discovery
    }

    private func findApp(in children: [URL]) -> AppBundleInfo? {
        let inspector = AppBundleInspector(fileSystem: fileSystem)
        let expected = adapter.expectedBundleIdentifiers
        // O app pode estar direto na raiz ou uma pasta abaixo (por exemplo, "PCSX2/PCSX2.app").
        let nested = children
            .filter { fileSystem.kind(of: $0) == .directory && $0.pathExtension.lowercased() != "app" }
            .flatMap { fileSystem.contentsOfDirectory(at: $0) }
        let matches = (children + nested)
            .filter { $0.pathExtension.lowercased() == "app" }
            .compactMap { try? inspector.inspect($0) }
            .filter { $0.bundleIdentifier.map(expected.contains) == true }
        // Com versões lado a lado (ex.: depois de atualizar), usa a mais nova.
        return matches.max { ($0.version ?? "").compare($1.version ?? "", options: .numeric) == .orderedAscending }
    }

    /// No modo portátil, o PCSX2 guarda a configuração na pasta que contém o `.app`.
    private func portableDataDirectory(for app: AppBundleInfo) -> URL? {
        let folder = app.bundleURL.deletingLastPathComponent()
        let markers = ["portable.ini", "portable.txt"].map { folder.appending(path: $0, directoryHint: .notDirectory) }
        return markers.contains(where: { fileSystem.kind(of: $0) == .regularFile }) ? folder : nil
    }

    static let padButtons = ["Cross", "Circle", "Square", "Triangle", "Up", "Down", "Left", "Right",
                             "L1", "R1", "L2", "R2", "L3", "R3", "Select", "Start"]

    /// `[Pad1]` do PCSX2.ini: tipo de controle e a que entrada cada botão do PS2 está ligado.
    static func controller(_ settings: INIFile) -> ControllerSummary? {
        guard let type = settings.value("Type", in: "Pad1"), type != "None" else { return nil }
        let bindings = padButtons.compactMap { button in
            settings.value(button, in: "Pad1").map { ControllerSummary.Binding(button: button, input: $0) }
        }
        let device = bindings.first?.input.split(separator: "/").first.map(String.init)
        return ControllerSummary(type: type, device: device, bindings: bindings)
    }

    private func biosStatus(settings: INIFile, dataDirectory: URL) -> PluginDiscovery.BIOSStatus {
        guard let name = settings.value("BIOS", in: "Filenames") else { return .notConfigured }
        let folder = resolve(settings.value("Bios", in: "Folders") ?? "bios", relativeTo: dataDirectory)
        let file = folder.appending(path: name, directoryHint: .notDirectory)
        return fileSystem.kind(of: file) == .regularFile ? .configured(name) : .fileMissing(name)
    }

    private func resolve(_ path: String, relativeTo base: URL) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        let url = expanded.hasPrefix("/")
            ? URL(filePath: expanded, directoryHint: .isDirectory)
            : base.appending(path: expanded, directoryHint: .isDirectory)
        return url.standardizedFileURL
    }

    /// Junta pastas repetidas (raiz e configuração apontando para o mesmo lugar), mantendo a primeira origem.
    static func merged(_ directories: [ROMDirectory]) -> [ROMDirectory] {
        var result: [ROMDirectory] = []
        for directory in directories {
            let key = directory.url.standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/")
            if let index = result.firstIndex(where: { $0.url.standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/") == key }) {
                let existing = result[index]
                result[index] = ROMDirectory(url: existing.url, origin: existing.origin, isRecursive: existing.isRecursive || directory.isRecursive)
            } else {
                result.append(directory)
            }
        }
        return result
    }
}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        count > suffix.count && hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
