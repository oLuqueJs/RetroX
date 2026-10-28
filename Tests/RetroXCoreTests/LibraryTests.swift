import Foundation
import Testing
@testable import RetroXCore

/// Pasta temporária real, apagada ao fim do teste.
final class TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "RetroXTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func file(_ relativePath: String, bytes: Int = 0) throws -> URL {
        let fileURL = url.appending(path: relativePath, directoryHint: .notDirectory)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: fileURL)
        return fileURL
    }
}

struct GameScannerTests {
    @Test("Varre recursivamente, ignora caixa da extensão, ocultos e formatos não suportados")
    func scans() throws {
        let folder = try TemporaryFolder()
        try folder.file("roms/Jogo A (USA).iso", bytes: 10)
        try folder.file("roms/sub/Jogo B.CHD", bytes: 20)
        try folder.file("roms/.oculto.iso")
        try folder.file("roms/leia-me.txt")
        try folder.file("roms/jogo.zip")
        let roms = GameScanner.scan(
            [ROMDirectory(url: folder.url.appending(path: "roms"), origin: .rootFolder, isRecursive: true)],
            extensions: ["iso", "chd"]
        )
        #expect(roms.map(\.url.lastPathComponent).sorted() == ["Jogo A (USA).iso", "Jogo B.CHD"])
        #expect(roms.first { $0.url.lastPathComponent == "Jogo B.CHD" }?.fileSize == 20)
    }

    @Test("Pasta não recursiva não desce em subpastas")
    func shallow() throws {
        let folder = try TemporaryFolder()
        try folder.file("A.iso")
        try folder.file("sub/B.iso")
        let roms = GameScanner.scan([ROMDirectory(url: folder.url, origin: .rootFolder, isRecursive: false)], extensions: ["iso"])
        #expect(roms.map(\.url.lastPathComponent) == ["A.iso"])
    }

    @Test("O mesmo arquivo por duas pastas sobrepostas ou por symlink conta uma vez")
    func deduplicates() throws {
        let folder = try TemporaryFolder()
        let original = try folder.file("roms/A.iso")
        try FileManager.default.createDirectory(at: folder.url.appending(path: "atalhos"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: folder.url.appending(path: "atalhos/A.iso"), withDestinationURL: original)
        let roms = GameScanner.scan([
            ROMDirectory(url: folder.url, origin: .rootFolder, isRecursive: true),
            ROMDirectory(url: folder.url.appending(path: "roms"), origin: .emulatorSettings, isRecursive: true),
        ], extensions: ["iso"])
        #expect(roms.count == 1)
    }

    @Test("Não altera nada nas pastas de jogos")
    func readOnly() throws {
        let folder = try TemporaryFolder()
        let rom = try folder.file("roms/A.iso", bytes: 4)
        let before = try FileManager.default.attributesOfItem(atPath: rom.path(percentEncoded: false))
        _ = GameScanner.scan([ROMDirectory(url: folder.url, origin: .rootFolder, isRecursive: true)], extensions: ["iso"])
        let after = try FileManager.default.attributesOfItem(atPath: rom.path(percentEncoded: false))
        #expect(before[.modificationDate] as? Date == after[.modificationDate] as? Date)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.appending(path: "roms").path(percentEncoded: false)) == ["A.iso"])
    }
}

struct LibraryBuilderTests {
    @Test("Monta jogos do plugin com título, sistema e capa")
    func buildsGames() throws {
        let folder = try TemporaryFolder()
        try folder.file("roms/GT 4 Spec II v1.08.iso")
        try folder.file("roms/Test Drive Unlimited (USA).iso")
        let cover = try folder.file("covers/gt4-cover.png")
        var discovery = PluginDiscovery(root: folder.url)
        discovery.romDirectories = [ROMDirectory(url: folder.url.appending(path: "roms"), origin: .rootFolder, isRecursive: true)]
        discovery.coverDirectories = [folder.url.appending(path: "covers")]

        let games = LibraryBuilder.games(for: PCSX2Plugin(), discovery: discovery)
        #expect(games.map(\.title) == ["GT 4 Spec II v1.08", "Test Drive Unlimited (USA)"])
        #expect(games.allSatisfy { $0.systemID == .ps2 && $0.pluginID == .pcsx2 })
        #expect(games[0].coverURL?.lastPathComponent == cover.lastPathComponent)
        #expect(games[1].coverURL == nil)
    }
}

struct CoverMatcherTests {
    let covers = [
        "gt4-cover.png", "Test Drive Unlimited (USA).jpg", "god of war front.webp", "x.png", "notas.txt",
    ].map { URL(filePath: "/capas/\($0)") }

    @Test("Associações esperadas", arguments: [
        ("GT 4 Spec II v1.08.iso", "gt4-cover.png"),
        ("Test Drive Unlimited (USA).iso", "Test Drive Unlimited (USA).jpg"),
        ("God of War (USA).chd", "god of war front.webp"),
        ("Gran Turismo 3.iso", nil),
        ("X.iso", nil),
    ] as [(String, String?)])
    func matches(rom: String, expected: String?) {
        #expect(CoverMatcher.match(romFilename: rom, covers: covers)?.lastPathComponent == expected)
    }

    @Test("Nome idêntico vence prefixo")
    func exactWins() {
        let covers = ["Jogo.png", "Jogo 2.png"].map { URL(filePath: "/c/\($0)") }
        #expect(CoverMatcher.match(romFilename: "Jogo 2.iso", covers: covers)?.lastPathComponent == "Jogo 2.png")
    }
}

struct JSONFileStoreTests {
    @Test("Salva e relê; arquivo ausente devolve nil")
    func roundTrip() throws {
        let folder = try TemporaryFolder()
        let store = JSONFileStore<[String: GameHistory]>(url: folder.url.appending(path: "sub/historico.json"))
        #expect(store.load() == nil)
        let value = ["/a.iso": GameHistory(isFavorite: true, lastPlayedAt: Date(timeIntervalSince1970: 1_000_000), playCount: 2)]
        try store.save(value)
        #expect(store.load() == value)
    }
}

struct PaletteTests {
    private func check(_ first: Tone, _ second: Tone, atLeast minimum: Double) {
        #expect(HexColor.contrast(first.light, second.light) >= minimum)
        #expect(HexColor.contrast(first.dark, second.dark) >= minimum)
    }

    @Test("Texto sobre fundos atinge 4,5:1 nos dois modos")
    func textContrast() {
        for background in [Palette.background, Palette.surface, Palette.raised] {
            check(Palette.textPrimary, background, atLeast: 4.5)
            check(Palette.textSecondary, background, atLeast: 4.5)
        }
    }

    @Test("Acentos: texto sobre o preenchimento 4,5:1; anel de foco sobre o fundo 3:1", arguments: Palette.Accent.allCases)
    func accentContrast(accent: Palette.Accent) {
        check(accent.onFill, accent.fill, atLeast: 4.5)
        check(accent.fill, Palette.background, atLeast: 3)
        check(accent.fill, Palette.surface, atLeast: 3)
    }

    @Test("Texto das capas geradas é legível")
    func coverContrast() {
        check(Palette.onCover, Palette.coverTone(for: .ps2), atLeast: 4.5)
        check(Palette.onCover, Palette.coverTone(for: GameSystemID(rawValue: "outro")), atLeast: 4.5)
    }
}
