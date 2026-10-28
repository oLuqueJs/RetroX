import Foundation

/// Informações de um jogo vindas de uma fonte pública, guardadas com a origem (ADR-0014).
public struct GameMetadata: Codable, Sendable, Equatable {
    public var title: String
    public var summary: String
    public var shortDescription: String?
    public var releaseYear: Int?
    public var developers: [String]
    public var publishers: [String]
    public var genres: [String]
    public var sourceName: String
    public var sourceURL: URL?
    public var fetchedAt: Date

    public init(
        title: String, summary: String, shortDescription: String? = nil, releaseYear: Int? = nil,
        developers: [String] = [], publishers: [String] = [], genres: [String] = [],
        sourceName: String, sourceURL: URL? = nil, fetchedAt: Date = .now
    ) {
        self.title = title
        self.summary = summary
        self.shortDescription = shortDescription
        self.releaseYear = releaseYear
        self.developers = developers
        self.publishers = publishers
        self.genres = genres
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.fetchedAt = fetchedAt
    }
}

/// Um resultado de busca para o usuário escolher. Nada é salvo sem a escolha dele.
public struct MetadataCandidate: Identifiable, Sendable, Hashable {
    public let title: String
    public let snippet: String
    public let language: String

    public var id: String { "\(language):\(title)" }
}

public enum MetadataError: Error, Equatable {
    case http(Int)
    case network(String)
    case invalidResponse
}

public protocol HTTPFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

/// URLSession com identificação, como pede a política da Wikimedia.
public struct URLSessionHTTP: HTTPFetching {
    public static let userAgent = "RetroX/0.1 (launcher de emuladores para macOS)"

    public init() {}

    public func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MetadataError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw MetadataError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw MetadataError.http(http.statusCode) }
        return data
    }
}

/// Busca na Wikipedia (português, depois inglês) e completa com dados estruturados do Wikidata quando
/// disponíveis. Não precisa de conta nem de chave. Texto da Wikipedia: CC BY-SA, com link para a origem.
public struct WikipediaMetadataProvider: Sendable {
    private let http: any HTTPFetching
    private let languages: [String]

    public init(http: any HTTPFetching = URLSessionHTTP(), languages: [String] = ["pt", "en"]) {
        self.http = http
        self.languages = languages
    }

    public func search(_ query: String) async throws -> [MetadataCandidate] {
        var lastError: Error?
        for language in languages {
            do {
                let results = try await search(query, language: language)
                if !results.isEmpty { return results }
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        return []
    }

    public func metadata(for candidate: MetadataCandidate) async throws -> GameMetadata {
        let encodedTitle = candidate.title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#")))
            ?? candidate.title
        let url = URL(string: "https://\(candidate.language).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)")!
        let summary = try await JSONDecoder().decode(Summary.self, from: http.data(from: url))
        var metadata = GameMetadata(
            title: summary.title,
            summary: summary.extract ?? "",
            shortDescription: summary.description,
            sourceName: "Wikipedia (\(candidate.language))",
            sourceURL: summary.contentURLs?.desktop?.page.flatMap(URL.init(string:))
        )
        // O Wikidata é um complemento: se estiver fora do ar, fica só o resumo.
        if let item = summary.wikibaseItem {
            try? await enrich(&metadata, item: item, language: candidate.language)
        }
        return metadata
    }

    // MARK: Wikipedia

    private func search(_ query: String, language: String) async throws -> [MetadataCandidate] {
        var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")!
        let hint = language == "pt" ? "jogo eletrônico" : "video game"
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: "\(query) \(hint)"),
            URLQueryItem(name: "srlimit", value: "6"),
            URLQueryItem(name: "srprop", value: "snippet"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
        ]
        let response = try await JSONDecoder().decode(SearchResponse.self, from: http.data(from: components.url!))
        return response.query.search.map {
            MetadataCandidate(title: $0.title, snippet: Self.plainText($0.snippet), language: language)
        }
    }

    /// "<span class=\"searchmatch\">Test</span> Drive" → "Test Drive".
    static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, character) in ["&quot;": "\"", "&amp;": "&", "&#039;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Wikidata

    private func enrich(_ metadata: inout GameMetadata, item: String, language: String) async throws {
        let claims = try await JSONDecoder().decode(EntitiesResponse.self, from: http.data(from: wikidataURL(ids: [item], props: "claims", language: language)))
            .entities[item]?.claims ?? [:]
        metadata.releaseYear = claims["P577"]?.compactMap(\.mainsnak.datavalue?.value.year).min()
        let developers = claims["P178"]?.compactMap(\.mainsnak.datavalue?.value.id) ?? []
        let publishers = claims["P123"]?.compactMap(\.mainsnak.datavalue?.value.id) ?? []
        let genres = claims["P136"]?.compactMap(\.mainsnak.datavalue?.value.id) ?? []
        let ids = Array(Set(developers + publishers + genres)).sorted()
        guard !ids.isEmpty else { return }
        let labels = try await JSONDecoder().decode(EntitiesResponse.self, from: http.data(from: wikidataURL(ids: ids, props: "labels", language: language)))
            .entities.compactMapValues { $0.labels?[language]?.value ?? $0.labels?["en"]?.value }
        metadata.developers = developers.compactMap { labels[$0] }
        metadata.publishers = publishers.compactMap { labels[$0] }
        metadata.genres = genres.compactMap { labels[$0] }
    }

    private func wikidataURL(ids: [String], props: String, language: String) -> URL {
        var components = URLComponents(string: "https://www.wikidata.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "wbgetentities"),
            URLQueryItem(name: "ids", value: ids.joined(separator: "|")),
            URLQueryItem(name: "props", value: props),
            URLQueryItem(name: "languages", value: Array(Set([language, "en"])).sorted().joined(separator: "|")),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components.url!
    }
}

// MARK: Formatos das respostas

private struct SearchResponse: Decodable {
    struct Query: Decodable { let search: [Hit] }
    struct Hit: Decodable {
        let title: String
        let snippet: String
    }

    let query: Query
}

private struct Summary: Decodable {
    struct ContentURLs: Decodable {
        struct Desktop: Decodable { let page: String? }
        let desktop: Desktop?
    }

    let title: String
    let extract: String?
    let description: String?
    let wikibaseItem: String?
    let contentURLs: ContentURLs?

    enum CodingKeys: String, CodingKey {
        case title, extract, description
        case wikibaseItem = "wikibase_item"
        case contentURLs = "content_urls"
    }
}

private struct EntitiesResponse: Decodable {
    struct Entity: Decodable {
        let claims: [String: [Claim]]?
        let labels: [String: Label]?
    }

    struct Label: Decodable { let value: String }

    struct Claim: Decodable {
        struct Snak: Decodable { let datavalue: DataValue? }
        let mainsnak: Snak
    }

    /// `value` é um id de entidade ({"id": "Q123"}) ou uma data ({"time": "+2006-09-05T00:00:00Z"}).
    struct DataValue: Decodable {
        struct Value: Decodable {
            let id: String?
            let time: String?

            var year: Int? {
                guard let time else { return nil }
                return Int(time.drop(while: { $0 == "+" }).prefix(4))
            }
        }

        let value: Value

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = (try? container.decode(Value.self, forKey: .value)) ?? Value(id: nil, time: nil)
        }

        enum CodingKeys: String, CodingKey { case value }
    }

    let entities: [String: Entity]
}
