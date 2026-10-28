import Foundation
import Testing
@testable import RetroXCore

/// Pasta raiz no formato "emulador + roms + capas + bios", com a configuração do PCSX2 fora dela.
struct PluginScenario {
    var disk = FakeFileSystem()
    let root = "/Emuladores/ps2"
    let dataDirectory = "/Dados/PCSX2"

    init(settings: String? = PluginScenario.defaultSettings) {
        for folder in [
            "/Emuladores", root, "\(root)/roms", "\(root)/covers", "\(root)/ps2 bios",
            "/Outra", "/Outra/Jogos", "/Dados", dataDirectory, "\(dataDirectory)/inis",
        ] {
            disk[folder] = .directory
        }
        disk.addAppBundle(at: "\(root)/PCSX2-v2.9.144.app", executable: "PCSX2")
        disk["\(root)/roms/Jogo (USA).iso"] = .file()
        disk["\(root)/covers/jogo-cover.png"] = .file()
        disk["\(root)/ps2 bios/SCPH-0001.bin"] = .file()
        if let settings {
            disk["\(dataDirectory)/inis/PCSX2.ini"] = .file(Data(settings.utf8))
        }
    }

    static let defaultSettings = """
        [UI]
        StartFullscreen = true

        [Folders]
        Bios = ../../Emuladores/ps2/ps2 bios

        [Filenames]
        BIOS = SCPH-0001.bin

        [GameList]
        RecursivePaths = /Emuladores/ps2/roms
        Paths = /Outra/Jogos
        """

    var plugin: PCSX2Plugin {
        PCSX2Plugin(fileSystem: disk, defaultDataDirectory: URL(filePath: dataDirectory, directoryHint: .isDirectory))
    }

    func discover(_ path: String? = nil) -> PluginDiscovery {
        plugin.discover(root: URL(filePath: path ?? root, directoryHint: .isDirectory))
    }
}

private func path(_ url: URL) -> String {
    url.standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/")
}

struct PCSX2PluginTests {
    @Test("Encontra app, pastas de jogos, capas e BIOS a partir da pasta raiz e do PCSX2.ini")
    func discoversEverything() {
        let discovery = PluginScenario().discover()
        #expect(discovery.issues.isEmpty)
        #expect(discovery.isReady)
        #expect(discovery.app?.bundleIdentifier == "net.pcsx2.pcsx2")
        #expect(discovery.romDirectories.map { path($0.url) } == ["/Emuladores/ps2/roms", "/Outra/Jogos"])
        // A pasta "roms" aparece na raiz e no PCSX2.ini: fica uma vez só, recursiva, com a origem da raiz.
        #expect(discovery.romDirectories[0].origin == .rootFolder)
        #expect(discovery.romDirectories[0].isRecursive)
        #expect(discovery.romDirectories[1] == ROMDirectory(url: discovery.romDirectories[1].url, origin: .emulatorSettings, isRecursive: false))
        #expect(discovery.coverDirectories.map(path) == ["/Emuladores/ps2/covers"])
        #expect(discovery.bios == .configured("SCPH-0001.bin"))
        #expect(discovery.settingsFile.map(path) == "/Dados/PCSX2/inis/PCSX2.ini")
    }

    @Test("Escolher o próprio .app usa a pasta que o contém como raiz")
    func acceptsAppAsRoot() {
        let discovery = PluginScenario().discover("/Emuladores/ps2/PCSX2-v2.9.144.app")
        #expect(path(discovery.root) == "/Emuladores/ps2")
        #expect(discovery.isReady)
    }

    @Test("App numa subpasta da raiz também é encontrado")
    func findsNestedApp() {
        var scenario = PluginScenario()
        for key in scenario.disk.entries.keys where key.hasPrefix("/Emuladores/ps2/PCSX2-v2.9.144.app") {
            scenario.disk.entries[key] = nil
        }
        scenario.disk["/Emuladores/ps2/emulador"] = .directory
        scenario.disk.addAppBundle(at: "/Emuladores/ps2/emulador/PCSX2.app", executable: "PCSX2")
        #expect(scenario.discover().app.map { path($0.bundleURL) } == "/Emuladores/ps2/emulador/PCSX2.app")
    }

    @Test("Modo portátil: lê a configuração ao lado do .app")
    func portableMode() {
        var scenario = PluginScenario(settings: nil)
        scenario.disk["/Emuladores/ps2/portable.ini"] = .file()
        scenario.disk["/Emuladores/ps2/inis"] = .directory
        scenario.disk["/Emuladores/ps2/inis/PCSX2.ini"] = .file(Data("[Filenames]\nBIOS = SCPH-0001.bin\n[Folders]\nBios = ps2 bios\n".utf8))
        let discovery = scenario.discover()
        #expect(discovery.settingsFile.map(path) == "/Emuladores/ps2/inis/PCSX2.ini")
        #expect(discovery.bios == .configured("SCPH-0001.bin"))
    }

    @Test("Sem configuração do PCSX2: BIOS desconhecida, mas a raiz ainda basta")
    func withoutSettings() {
        let discovery = PluginScenario(settings: nil).discover()
        #expect(discovery.settingsFile == nil)
        #expect(discovery.bios == .unknown)
        #expect(discovery.romDirectories.map { path($0.url) } == ["/Emuladores/ps2/roms"])
        #expect(discovery.isReady)
    }

    @Test("BIOS configurada mas ausente e pasta da lista de jogos que sumiu")
    func brokenSettings() {
        var scenario = PluginScenario(settings: """
            [Filenames]
            BIOS = Sumiu.bin
            [GameList]
            RecursivePaths = /Disco Externo/PS2
            """)
        scenario.disk["/Emuladores/ps2/ps2 bios/SCPH-0001.bin"] = nil
        let discovery = scenario.discover()
        #expect(discovery.bios == .fileMissing("Sumiu.bin"))
        #expect(discovery.issues == [.settingsFolderMissing("/Disco Externo/PS2")])
    }

    @Test("Problemas: raiz inexistente, sem app, sem pastas de jogos")
    func issues() {
        #expect(PluginScenario().discover("/Nada").issues == [.rootNotFound])

        var noApp = PluginScenario()
        for key in noApp.disk.entries.keys where key.contains(".app") { noApp.disk.entries[key] = nil }
        #expect(noApp.discover().issues == [.appNotFound])
        #expect(!noApp.discover().isReady)

        var noGames = PluginScenario(settings: nil)
        noGames.disk["/Emuladores/ps2/roms"] = nil
        noGames.disk["/Emuladores/ps2/roms/Jogo (USA).iso"] = nil
        #expect(noGames.discover().issues == [.noROMDirectories])
    }

    @Test("ROMs soltas na raiz viram uma pasta não recursiva")
    func loosROMsAtRoot() {
        var scenario = PluginScenario(settings: nil)
        scenario.disk["/Emuladores/ps2/Solto.chd"] = .file()
        let directories = scenario.discover().romDirectories
        #expect(directories.contains(ROMDirectory(url: directories.last!.url, origin: .rootFolder, isRecursive: false)))
        #expect(directories.map { path($0.url) }.contains("/Emuladores/ps2"))
    }
}

struct INIFileTests {
    @Test("Seções, chaves repetidas, comentários e espaços")
    func parses() {
        let ini = INIFile("""
            ; comentário
            [GameList]
            RecursivePaths = /a
            recursivepaths=/b c
            Paths =
            # outro comentário
            [Folders]
            Bios = ../bios = com igual
            """)
        #expect(ini.values("RecursivePaths", in: "gamelist") == ["/a", "/b c"])
        #expect(ini.value("Paths", in: "GameList") == nil)
        #expect(ini.value("Bios", in: "Folders") == "../bios = com igual")
        #expect(ini.value("Bios", in: "GameList") == nil)
    }
}
