import Foundation
import Testing
@testable import RetroXCore

/// Respostas em ordem e registro de URLs, sem estado global compartilhado entre testes.
private actor ScriptedHTTP: HTTPFetching {
    private var replies: [Result<Data, MetadataError>]
    private(set) var requests: [URL] = []

    init(_ replies: [Result<Data, MetadataError>]) { self.replies = replies }

    func data(from url: URL) async throws -> Data {
        requests.append(url)
        guard !replies.isEmpty else { throw MetadataError.invalidResponse }
        return try replies.removeFirst().get()
    }
}

struct MockedMetadataTests {
    private let found = Data(#"{"query":{"search":[{"title":"Jogo","snippet":"Descrição"}]}}"#.utf8)
    private let empty = Data(#"{"query":{"search":[]}}"#.utf8)

    @Test("Resultado em português evita chamada em inglês")
    func stopsAfterFirstResult() async throws {
        let http = ScriptedHTTP([.success(found)])
        let results = try await WikipediaMetadataProvider(http: http).search("Jogo")
        #expect(results.count == 1)
        #expect(await http.requests.map(\.host) == ["pt.wikipedia.org"])
    }

    @Test("Erro em português permite recuperação em inglês")
    func recoversAfterError() async throws {
        let http = ScriptedHTTP([.failure(.http(503)), .success(found)])
        let results = try await WikipediaMetadataProvider(http: http).search("Jogo")
        #expect(results.map(\.language) == ["en"])
        #expect(await http.requests.map(\.host) == ["pt.wikipedia.org", "en.wikipedia.org"])
    }

    @Test("JSON inválido permite recuperação no idioma seguinte")
    func recoversAfterMalformedJSON() async throws {
        let http = ScriptedHTTP([.success(Data("não é JSON".utf8)), .success(found)])
        #expect(try await WikipediaMetadataProvider(http: http).search("Jogo").first?.language == "en")
        #expect(await http.requests.count == 2)
    }

    @Test("Busca vazia não faz chamadas além dos idiomas configurados")
    func emptyResults() async throws {
        let http = ScriptedHTTP([.success(empty), .success(empty)])
        #expect(try await WikipediaMetadataProvider(http: http).search("Nada").isEmpty)
        #expect(await http.requests.count == 2)
    }

    @Test("Caracteres reservados ficam no parâmetro, sem alterar a requisição")
    func escapesQuery() async throws {
        let query = "Ação & 日本? #x=/🎮"
        let http = ScriptedHTTP([.success(found)])
        _ = try await WikipediaMetadataProvider(http: http).search(query)
        let url = try #require(await http.requests.first)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first { $0.name == "srsearch" }?.value == "\(query) jogo eletrônico")
        #expect(components.fragment == nil)
        #expect(components.path == "/w/api.php")
    }
}
