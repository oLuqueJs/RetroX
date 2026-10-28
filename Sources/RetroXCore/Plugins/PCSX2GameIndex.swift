import Foundation

/// O que o banco de dados de jogos do emulador sabe sobre um disco.
public struct GameIndexEntry: Codable, Sendable, Equatable, Hashable {
    public let name: String
    public let region: String?
    /// Nota de compatibilidade do PCSX2, de 1 (não abre) a 5 (perfeito).
    public let compatibility: Int?
}

/// Lê o `GameIndex.yaml` que vem dentro do app do PCSX2 (serial → nome, região, compatibilidade).
/// Offline e sem alterar nada. Só os seriais pedidos são guardados; o resto do arquivo é ignorado.
public enum PCSX2GameIndex {
    public static func entries(for serials: Set<String>, in url: URL) -> [String: GameIndexEntry] {
        guard !serials.isEmpty, let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return parse(text, serials: serials)
    }

    static func parse(_ text: String, serials: Set<String>) -> [String: GameIndexEntry] {
        var result: [String: GameIndexEntry] = [:]
        var current: String?
        var fields: [String: String] = [:]

        func flush() {
            if let current, let name = fields["name"] {
                result[current] = GameIndexEntry(name: name, region: fields["region"], compatibility: fields["compat"].flatMap { Int($0) })
            }
            fields = [:]
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let first = line.first, !first.isWhitespace, first != "#" {
                // Nova entrada de nível superior ("SLUS-21490:").
                flush()
                let key = line.split(separator: ":", maxSplits: 1).first.map { String($0).trimmingCharacters(in: .whitespaces) }
                current = key.flatMap { serials.contains($0) ? $0 : nil }
                continue
            }
            guard current != nil else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Só os campos diretos da entrada (dois espaços de recuo), não os aninhados.
            guard line.hasPrefix("  "), !line.hasPrefix("   "),
                  let colon = trimmed.firstIndex(of: ":")
            else { continue }
            let key = String(trimmed[..<colon])
            var value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
            }
            if ["name", "region", "compat"].contains(key) { fields[key] = value }
        }
        flush()
        return result
    }
}
