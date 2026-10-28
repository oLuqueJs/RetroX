import Foundation

public struct ScannedROM: Sendable, Equatable {
    public let url: URL
    public let fileSize: Int64
}

public enum GameScanner {
    /// Lista as ROMs das pastas, sem abrir nem alterar os arquivos (ADR-0004). Pula arquivos ocultos e
    /// o conteúdo de packages, e conta só uma vez o mesmo arquivo alcançado por caminhos diferentes.
    /// Síncrono e possivelmente lento: chame fora da main thread.
    public static func scan(_ directories: [ROMDirectory], extensions: Set<String>) -> [ScannedROM] {
        var seen: Set<String> = []
        var result: [ScannedROM] = []
        for directory in directories {
            var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            if !directory.isRecursive { options.insert(.skipsSubdirectoryDescendants) }
            guard let enumerator = FileManager.default.enumerator(
                at: directory.url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: options
            ) else { continue }

            for case let url as URL in enumerator {
                if Task.isCancelled { return result }
                guard extensions.contains(url.pathExtension.lowercased()),
                      let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true
                else { continue }
                let identity = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
                guard seen.insert(identity).inserted else { continue }
                result.append(ScannedROM(url: url, fileSize: Int64(values.fileSize ?? 0)))
            }
        }
        return result
    }
}

public enum LibraryBuilder {
    /// Monta os jogos de um plugin pronto: varre as pastas de ROM e associa capas pelo nome.
    public static func games(for plugin: any EmulatorPlugin, discovery: PluginDiscovery, fileSystem: any FileSystemProbing = LocalFileSystem()) -> [Game] {
        // Plugins de um sistema só (o PCSX2) não precisam de detecção; os de vários sistemas usarão o ADR-0012.
        guard let system = plugin.systems.first, plugin.systems.count == 1 else { return [] }
        let extensions = plugin.adapter.supportedExtensions(for: system)
        let covers = discovery.coverDirectories
            .flatMap { fileSystem.contentsOfDirectory(at: $0) }
            .filter { CoverMatcher.imageExtensions.contains($0.pathExtension.lowercased()) }
        // O PCSX2 nomeia as capas que baixa pelo serial do disco, e o banco de dados dele também usa o serial.
        let roms = GameScanner.scan(discovery.romDirectories, extensions: extensions)
            .map { rom in (rom, system == .ps2 ? PS2DiscReader.serial(of: rom.url) : nil) }
        let index = discovery.gameIndexFile.map { PCSX2GameIndex.entries(for: Set(roms.compactMap(\.1)), in: $0) } ?? [:]
        return roms
            .map { rom, serial in
                Game(
                    romURL: rom.url,
                    systemID: system,
                    pluginID: plugin.id,
                    fileSize: rom.fileSize,
                    serial: serial,
                    info: serial.flatMap { index[$0] },
                    coverURL: CoverMatcher.match(romFilename: rom.url.lastPathComponent, serial: serial, covers: covers)
                )
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
