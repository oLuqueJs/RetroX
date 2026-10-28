import Foundation

/// Lê o serial de um disco de PS2 em ISO (por exemplo, "SLUS-21490"), do mesmo jeito que o PCSX2 nomeia
/// as capas que baixa. Lê só o descritor de volume, a pasta raiz e o `SYSTEM.CNF`: poucos KB, sem hash
/// e sem alterar o arquivo. Formatos comprimidos (CHD, CSO, ZSO) não são lidos.
public enum PS2DiscReader {
    static let sectorSize = 2048
    static let maxDirectorySize = 64 * 1024
    static let maxConfigSize = 4 * 1024

    public static func serial(of url: URL) -> String? {
        guard url.pathExtension.lowercased() == "iso", let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        // Descritor de volume primário no setor 16: tipo 1 + "CD001".
        guard let descriptor = read(handle, offset: 16 * sectorSize, length: sectorSize),
              descriptor.count == sectorSize, descriptor[0] == 1,
              String(decoding: descriptor[1...5], as: UTF8.self) == "CD001"
        else { return nil }
        let blockSize = Int(descriptor.uint16LE(at: 128) ?? 0)
        guard blockSize > 0,
              let rootSector = descriptor.uint32LE(at: 156 + 2),
              let rootSize = descriptor.uint32LE(at: 156 + 10),
              let root = read(handle, offset: Int(rootSector) * blockSize, length: min(Int(rootSize), maxDirectorySize)),
              let entry = findFile(named: "SYSTEM.CNF", in: root, blockSize: blockSize),
              let config = read(handle, offset: entry.sector * blockSize, length: min(entry.size, maxConfigSize))
        else { return nil }
        return serial(fromSystemConfig: String(decoding: config, as: UTF8.self))
    }

    /// `BOOT2 = cdrom0:\SLUS_214.90;1` → "SLUS-21490". Só PS2 (`BOOT2`); discos de PS1 usam `BOOT`.
    static func serial(fromSystemConfig text: String) -> String? {
        let ini = INIFile(text)
        guard let boot = ini.value("BOOT2", in: "") else { return nil }
        let file = boot.split(whereSeparator: { $0 == "\\" || $0 == ":" || $0 == "/" }).last.map(String.init) ?? boot
        let name = file.split(separator: ";").first.map(String.init) ?? file
        let parts = name.split(separator: "_", maxSplits: 1)
        guard parts.count == 2, parts[0].count == 4, parts[0].allSatisfy(\.isLetter) else { return nil }
        let digits = parts[1].filter(\.isNumber)
        guard digits.count == 5 else { return nil }
        return "\(parts[0].uppercased())-\(digits)"
    }

    private static func findFile(named name: String, in directory: Data, blockSize: Int) -> (sector: Int, size: Int)? {
        var offset = 0
        while offset < directory.count {
            let length = Int(directory[directory.startIndex + offset])
            if length == 0 {
                // Registros não atravessam o fim do bloco: o resto do bloco é preenchimento.
                offset = (offset / blockSize + 1) * blockSize
                continue
            }
            guard offset + 33 <= directory.count, length >= 34, offset + length <= directory.count else { return nil }
            let nameLength = Int(directory[directory.startIndex + offset + 32])
            guard offset + 33 + nameLength <= offset + length else { return nil }
            let start = directory.startIndex + offset + 33
            let entryName = String(decoding: directory[start..<(start + nameLength)], as: UTF8.self)
            if entryName.split(separator: ";").first.map({ $0.uppercased() == name }) == true,
               let sector = directory.uint32LE(at: offset + 2), let size = directory.uint32LE(at: offset + 10) {
                return (Int(sector), Int(size))
            }
            offset += length
        }
        return nil
    }

    private static func read(_ handle: FileHandle, offset: Int, length: Int) -> Data? {
        guard length > 0, (try? handle.seek(toOffset: UInt64(offset))) != nil else { return nil }
        return try? handle.read(upToCount: length)
    }
}

extension Data {
    func uint16LE(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        return UInt16(self[startIndex + offset]) | UInt16(self[startIndex + offset + 1]) << 8
    }

    func uint32LE(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        return (0..<4).reduce(UInt32(0)) { value, byte in value | UInt32(self[startIndex + offset + byte]) << (8 * byte) }
    }
}
