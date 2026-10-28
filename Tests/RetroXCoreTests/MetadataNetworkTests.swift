import Foundation
import Testing
@testable import RetroXCore

/// Consulta a Wikipedia de verdade. Opt-in: `RX_NETWORK=1 scripts/test.sh --filter MetadataNetworkTests`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RX_NETWORK"] == "1"))
struct MetadataNetworkTests {
    @Test("Busca e resumo reais na Wikipedia")
    func liveWikipedia() async throws {
        let provider = WikipediaMetadataProvider()
        let results = try await provider.search("Test Drive Unlimited")
        let first = try #require(results.first)
        #expect(first.title.contains("Test Drive"))
        let metadata = try await provider.metadata(for: first)
        #expect(!metadata.summary.isEmpty)
        #expect(metadata.sourceURL != nil)
    }
}
