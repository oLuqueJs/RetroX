import Foundation

public enum TitleParser {
    /// Título de exibição derivado do nome do arquivo: sem extensão, `_` vira espaço, espaços colapsados e Unicode em NFC.
    /// Marcas como região, entre parênteses, são mantidas.
    public static func displayTitle(fromFilename filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        let words = base.replacingOccurrences(of: "_", with: " ").split(whereSeparator: \.isWhitespace)
        let title = words.joined(separator: " ").precomposedStringWithCanonicalMapping
        return title.isEmpty ? filename.precomposedStringWithCanonicalMapping : title
    }

    /// Título para buscar em fontes externas: sem região, tags e versões. "GT 4 Spec II v1.08" → "GT 4 Spec II".
    public static func searchTitle(_ title: String) -> String {
        let withoutGroups = title
            .replacingOccurrences(of: "\\([^)]*\\)|\\[[^\\]]*\\]", with: " ", options: .regularExpression)
        let words = withoutGroups.split(whereSeparator: \.isWhitespace).filter {
            $0.range(of: "^v\\d+(\\.\\d+)*$", options: [.regularExpression, .caseInsensitive]) == nil
        }
        return words.joined(separator: " ")
    }

    /// Chave de busca que ignora caixa, acentos e largura: "Ação" e "acao" geram a mesma chave.
    public static func searchKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .precomposedStringWithCanonicalMapping
    }
}
