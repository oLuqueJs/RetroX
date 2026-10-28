import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RetroXCore

struct ProfileTests {
    @Test("Iniciais do avatar sem foto", arguments: [
        ("Ana Souza", "AS"), ("Jogador 1", "J1"), ("léo", "L"), ("  ", "?"), ("Maria da Silva", "MD"),
    ])
    func initials(name: String, expected: String) {
        #expect(Profile(name: name).initials == expected)
    }

    @Test("Perfil de versão anterior (sem tema e aparência) abre com os padrões")
    func decodesOlderFiles() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Ana"}"#
        let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
        #expect(profile.theme == .retrox)
        #expect(profile.appearance == .system)
        #expect(profile.accent == .coral)
    }

    @Test("Histórico antigo passa para o primeiro perfil e o arquivo antigo é guardado")
    func migratesLegacyHistory() throws {
        let folder = try TemporaryFolder()
        let storage = ProfileStorage(root: folder.url)
        let legacy = ["/jogos/a.iso": GameHistory(isFavorite: true, playCount: 3)]
        try JSONFileStore<[String: GameHistory]>(url: folder.url.appending(path: "history.json")).save(legacy)
        let profile = Profile(name: "Jogador 1")

        try storage.migrateLegacyHistory(into: profile.id)
        #expect(storage.history(for: profile.id).load() == legacy)
        #expect(FileManager.default.fileExists(atPath: folder.url.appending(path: "history.legacy.json").path(percentEncoded: false)))
        #expect(!FileManager.default.fileExists(atPath: folder.url.appending(path: "history.json").path(percentEncoded: false)))

        // Rodar de novo não apaga nem sobrescreve nada.
        try storage.migrateLegacyHistory(into: profile.id)
        #expect(storage.history(for: profile.id).load() == legacy)
    }
}

struct ImageImporterTests {
    private func writePNG(width: Int, height: Int, to url: URL) throws {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    @Test("Copia reduzido, sem tocar no original")
    func importsDownsampled() throws {
        let folder = try TemporaryFolder()
        let source = folder.url.appending(path: "foto.png")
        try writePNG(width: 2000, height: 1000, to: source)
        let before = try Data(contentsOf: source)

        let destination = folder.url.appending(path: "Avatars/eu.png")
        try ImageImporter.importPNG(from: source, to: destination, maxPixelSize: 512)
        let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(destination as CFURL, nil)!, 0, nil)!
        #expect(max(image.width, image.height) == 512)
        #expect(try Data(contentsOf: source) == before)

        // Importar de novo substitui a cópia anterior.
        try ImageImporter.importPNG(from: source, to: destination, maxPixelSize: 256)
        let replaced = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(destination as CFURL, nil)!, 0, nil)!
        #expect(max(replaced.width, replaced.height) == 256)
    }

    @Test("Arquivo que não é imagem")
    func rejectsNonImages() throws {
        let folder = try TemporaryFolder()
        let source = try folder.file("nota.txt", bytes: 10)
        #expect(throws: ImageImporterError.unreadableImage) {
            try ImageImporter.importPNG(from: source, to: folder.url.appending(path: "x.png"), maxPixelSize: 100)
        }
    }

    @Test("Nome da capa é estável e só tem caracteres seguros")
    func coverFileName() {
        let name = ArtworkStorage.coverFileName(for: "/Volumes/Jogos Ação/Jogo (USA).iso")
        #expect(name == ArtworkStorage.coverFileName(for: "/Volumes/Jogos Ação/Jogo (USA).iso"))
        #expect(name.range(of: "^[0-9a-f]{24}\\.png$", options: .regularExpression) != nil)
    }
}

struct GameIndexTests {
    let yaml = """
        # comentário
        SCUS-97436:
          name: "Gran Turismo 4 [Online Public Beta]"
          region: "NTSC-U"
          clampModes: *gran-turismo-4-clamp-modes
        SLUS-21490:
          name: "Test Drive Unlimited"
          region: "NTSC-U"
          compat: 5
          gameFixes:
            - SoftwareRendererFMVHack
          patches:
            default:
              name: "não é o nome do jogo"
        SLUS-99999:
          name: "Outro jogo"
          compat: 3
        """

    @Test("Lê nome, região e compatibilidade só dos seriais pedidos")
    func parses() {
        let entries = PCSX2GameIndex.parse(yaml, serials: ["SLUS-21490", "SCUS-97436"])
        #expect(entries.count == 2)
        #expect(entries["SLUS-21490"] == GameIndexEntry(name: "Test Drive Unlimited", region: "NTSC-U", compatibility: 5))
        #expect(entries["SCUS-97436"]?.name == "Gran Turismo 4 [Online Public Beta]")
        #expect(entries["SCUS-97436"]?.compatibility == nil)
    }
}

struct PluginEmulatorSettingsTests {
    @Test("Controle vem do PCSX2.ini; nada da seção de conquistas (nem o token) é lido")
    func controllerOnly() {
        let scenario = PluginScenario(settings: """
            [Achievements]
            Enabled = true
            ChallengeMode = true
            Username = jogadora
            Token = SEGREDO-NAO-PODE-VAZAR
            [Pad1]
            Type = DualShock2
            Cross = SDL-0/FaceSouth
            Circle = SDL-0/FaceEast
            Start = SDL-0/Start
            """)
        let discovery = scenario.discover()
        #expect(discovery.controller?.type == "DualShock2")
        #expect(discovery.controller?.device == "SDL-0")
        #expect(discovery.controller?.bindings.first == ControllerSummary.Binding(button: "Cross", input: "SDL-0/FaceSouth"))
        #expect(!String(describing: discovery).contains("SEGREDO"))
        #expect(!String(describing: discovery).contains("jogadora"))
    }

    @Test("Sem [Pad1], sem resumo de controle")
    func noController() {
        #expect(PluginScenario(settings: "[UI]\nStartFullscreen = true\n").discover().controller == nil)
    }

    @Test("Aponta o GameIndex.yaml de dentro do app, quando existe")
    func gameIndexFile() {
        var scenario = PluginScenario()
        scenario.disk["/Emuladores/ps2/PCSX2-v2.9.144.app/Contents/Resources"] = .directory
        scenario.disk["/Emuladores/ps2/PCSX2-v2.9.144.app/Contents/Resources/GameIndex.yaml"] = .file()
        #expect(scenario.discover().gameIndexFile?.lastPathComponent == "GameIndex.yaml")
        #expect(PluginScenario().discover().gameIndexFile == nil)
    }
}

/// Responde por trecho de URL; o que não estiver mapeado falha como servidor fora do ar.
struct FakeHTTP: HTTPFetching {
    var responses: [String: String]

    func data(from url: URL) async throws -> Data {
        let address = url.absoluteString.removingPercentEncoding ?? url.absoluteString
        guard let match = responses.first(where: { address.contains($0.key) }) else { throw MetadataError.http(503) }
        return Data(match.value.utf8)
    }
}

struct WikipediaMetadataProviderTests {
    static let ptSearch = #"""
        {"query":{"search":[{"title":"Test Drive Unlimited","snippet":"<span class=\"searchmatch\">Test</span> Drive Unlimited é um jogo eletrônico de corrida &amp; mundo aberto"}]}}
        """#
    static let ptSummary = #"""
        {"title":"Test Drive Unlimited","extract":"Test Drive Unlimited é um jogo eletrônico de corrida de 2006.","description":"videojogo de 2006","wikibase_item":"Q853941","content_urls":{"desktop":{"page":"https://pt.wikipedia.org/wiki/Test_Drive_Unlimited"}}}
        """#
    static let claims = #"""
        {"entities":{"Q853941":{"claims":{
          "P577":[{"mainsnak":{"datavalue":{"value":{"time":"+2007-03-16T00:00:00Z"}}}},{"mainsnak":{"datavalue":{"value":{"time":"+2006-09-05T00:00:00Z"}}}}],
          "P178":[{"mainsnak":{"datavalue":{"value":{"id":"Q1"}}}}],
          "P123":[{"mainsnak":{"datavalue":{"value":{"id":"Q2"}}}}],
          "P136":[{"mainsnak":{"datavalue":{"value":{"id":"Q3"}}}},{"mainsnak":{"snaktype":"novalue"}}]
        }}}}
        """#
    static let labels = #"""
        {"entities":{"Q1":{"labels":{"en":{"value":"Eden Games"}}},"Q2":{"labels":{"pt":{"value":"Atari"}}},"Q3":{"labels":{"pt":{"value":"jogo eletrônico de corrida"}}}}}
        """#

    @Test("Busca em português e limpa o HTML do trecho")
    func searchesPortuguese() async throws {
        let provider = WikipediaMetadataProvider(http: FakeHTTP(responses: ["pt.wikipedia.org/w/api.php": Self.ptSearch]))
        let results = try await provider.search("Test Drive Unlimited")
        #expect(results == [MetadataCandidate(
            title: "Test Drive Unlimited", snippet: "Test Drive Unlimited é um jogo eletrônico de corrida & mundo aberto", language: "pt"
        )])
    }

    @Test("Sem resultado em português, tenta em inglês")
    func fallsBackToEnglish() async throws {
        let provider = WikipediaMetadataProvider(http: FakeHTTP(responses: [
            "pt.wikipedia.org/w/api.php": #"{"query":{"search":[]}}"#,
            "en.wikipedia.org/w/api.php": #"{"query":{"search":[{"title":"Raro","snippet":"a video game"}]}}"#,
        ]))
        #expect(try await provider.search("Raro").map(\.language) == ["en"])
    }

    @Test("Resumo da Wikipedia completado pelo Wikidata")
    func metadataWithWikidata() async throws {
        let provider = WikipediaMetadataProvider(http: FakeHTTP(responses: [
            "rest_v1/page/summary/Test_Drive_Unlimited": Self.ptSummary,
            "props=claims": Self.claims,
            "props=labels": Self.labels,
        ]))
        let candidate = MetadataCandidate(title: "Test Drive Unlimited", snippet: "", language: "pt")
        let metadata = try await provider.metadata(for: candidate)
        #expect(metadata.summary == "Test Drive Unlimited é um jogo eletrônico de corrida de 2006.")
        #expect(metadata.releaseYear == 2006)
        #expect(metadata.developers == ["Eden Games"])
        #expect(metadata.publishers == ["Atari"])
        #expect(metadata.genres == ["jogo eletrônico de corrida"])
        #expect(metadata.sourceName == "Wikipedia (pt)")
        #expect(metadata.sourceURL?.absoluteString == "https://pt.wikipedia.org/wiki/Test_Drive_Unlimited")
    }

    @Test("Wikidata fora do ar: fica só o resumo, sem erro")
    func wikidataDown() async throws {
        let provider = WikipediaMetadataProvider(http: FakeHTTP(responses: ["rest_v1/page/summary/": Self.ptSummary]))
        let metadata = try await provider.metadata(for: MetadataCandidate(title: "Test Drive Unlimited", snippet: "", language: "pt"))
        #expect(metadata.releaseYear == nil)
        #expect(metadata.developers.isEmpty)
        #expect(!metadata.summary.isEmpty)
    }

    @Test("Wikipedia fora do ar: o erro chega a quem chamou")
    func wikipediaDown() async {
        let provider = WikipediaMetadataProvider(http: FakeHTTP(responses: [:]))
        await #expect(throws: MetadataError.http(503)) { try await provider.search("x") }
    }
}

struct SearchTitleTests {
    @Test("Título para busca", arguments: [
        ("GT 4 Spec II v1.08", "GT 4 Spec II"),
        ("Test Drive Unlimited (USA)", "Test Drive Unlimited"),
        ("PES 2014 - Pro Evolution Soccer (Europe) (En,Nl,Sv,Ru,Tr)", "PES 2014 - Pro Evolution Soccer"),
        ("Jogo [!] [T-Por]", "Jogo"),
    ])
    func cleans(title: String, expected: String) {
        #expect(TitleParser.searchTitle(title) == expected)
    }
}
