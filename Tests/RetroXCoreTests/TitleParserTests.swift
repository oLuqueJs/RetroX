import Testing
@testable import RetroXCore

struct TitleParserTests {
    @Test("Remove a extensão e mantém a região")
    func removesExtensionKeepsRegion() {
        #expect(TitleParser.displayTitle(fromFilename: "Test Drive Unlimited (USA).iso") == "Test Drive Unlimited (USA)")
    }

    @Test("Troca _ por espaço e colapsa espaços")
    func normalizesSpacing() {
        #expect(TitleParser.displayTitle(fromFilename: "Gran_Turismo   4 .chd") == "Gran Turismo 4")
    }

    @Test("Converte nomes em NFD para NFC")
    func convertsToNFC() {
        let nfd = "Ac\u{0327}a\u{0303}o.iso"
        let title = TitleParser.displayTitle(fromFilename: nfd)
        #expect(Array(title.utf8) == Array("Ação".precomposedStringWithCanonicalMapping.utf8))
    }

    @Test("Nome sem base mantém o original")
    func keepsFilenameWhenBaseIsEmpty() {
        #expect(TitleParser.displayTitle(fromFilename: "___.iso") == "___.iso")
    }

    @Test("Chave de busca ignora caixa, acentos e forma Unicode")
    func searchKeyFolds() {
        #expect(TitleParser.searchKey("AÇÃO") == TitleParser.searchKey("acao"))
        #expect(TitleParser.searchKey("Ac\u{0327}a\u{0303}o") == TitleParser.searchKey("ação"))
    }
}
