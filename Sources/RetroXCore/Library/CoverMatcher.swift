import Foundation

/// Associa capas locais (fornecidas pelo usuário) a ROMs pelo nome do arquivo. Sem rede (ADR-0006).
public enum CoverMatcher {
    public static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp"]

    /// Palavras que costumam enfeitar o nome de uma capa e não identificam o jogo.
    static let noiseWords: Set<String> = ["cover", "covers", "front", "box", "boxart", "capa", "art"]

    /// Chave curta demais casaria com jogos demais ("gt" é prefixo de muita coisa).
    static let minimumKeyLength = 3

    /// "GT 4 Spec II v1.08.iso" → "gt4speciiv108"; "gt4-cover.png" → "gt4".
    static func key(_ filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        let folded = base.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return folded
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !noiseWords.contains($0) }
            .joined()
    }

    /// Prefere o serial do disco (como o PCSX2 nomeia as capas que baixa); depois o nome idêntico; senão,
    /// a capa cujo nome é o prefixo mais longo do nome da ROM (ou vice-versa).
    public static func match(romFilename: String, serial: String? = nil, covers: [URL]) -> URL? {
        PreparedCovers(covers).match(romFilename: romFilename, serial: serial)
    }

    struct PreparedCovers {
        private struct Cover {
            let url: URL
            let basename: String
            let key: String
        }

        private let covers: [Cover]

        init(_ urls: [URL]) {
            covers = urls.map { url in
                Cover(url: url, basename: (url.lastPathComponent as NSString).deletingPathExtension, key: CoverMatcher.key(url.lastPathComponent))
            }
        }

        func match(romFilename: String, serial: String? = nil) -> URL? {
            if let serial, let cover = covers.first(where: {
                $0.basename.caseInsensitiveCompare(serial) == .orderedSame
            }) {
                return cover.url
            }
            let romKey = key(romFilename)
            guard romKey.count >= minimumKeyLength else { return nil }
            var best: (url: URL, length: Int)?
            for cover in covers {
                let coverKey = cover.key
                guard coverKey.count >= minimumKeyLength else { continue }
                if coverKey == romKey { return cover.url }
                if romKey.hasPrefix(coverKey) || coverKey.hasPrefix(romKey) {
                    let length = min(coverKey.count, romKey.count)
                    if length > (best?.length ?? 0) { best = (cover.url, length) }
                }
            }
            return best?.url
        }
    }
}
