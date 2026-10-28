import Foundation

/// Leitor mínimo de INI (só leitura), no formato que o PCSX2 grava: `[Seção]` e `chave = valor`.
/// Chaves podem se repetir (por exemplo, várias `RecursivePaths`); a ordem é preservada.
public struct INIFile: Sendable, Equatable {
    struct Entry: Sendable, Equatable {
        let section: String
        let key: String
        let value: String
    }

    private let entries: [Entry]

    public init(_ text: String) {
        var section = ""
        var entries: [Entry] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if line.hasPrefix("["), line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                continue
            }
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            entries.append(Entry(section: section, key: key, value: value))
        }
        self.entries = entries
    }

    /// Todos os valores da chave na seção, na ordem do arquivo. Seção e chave ignoram caixa.
    public func values(_ key: String, in section: String) -> [String] {
        entries
            .filter { $0.section.caseInsensitiveCompare(section) == .orderedSame && $0.key.caseInsensitiveCompare(key) == .orderedSame }
            .map(\.value)
    }

    /// O último valor não vazio da chave, como o próprio PCSX2 faria ao reler o arquivo.
    public func value(_ key: String, in section: String) -> String? {
        values(key, in: section).last { !$0.isEmpty }
    }
}
