import Foundation

public enum CPUArchitecture: Hashable, Sendable, CustomStringConvertible {
    case arm64
    case x86_64
    case other(cpuType: Int32)

    init(cpuType: Int32) {
        switch cpuType {
        case 0x0100_000C: self = .arm64   // CPU_TYPE_ARM64
        case 0x0100_0007: self = .x86_64  // CPU_TYPE_X86_64
        default: self = .other(cpuType: cpuType)
        }
    }

    public var description: String {
        switch self {
        case .arm64: "arm64"
        case .x86_64: "x86_64"
        case .other(let cpuType): "cpu(0x\(String(cpuType, radix: 16)))"
        }
    }
}

enum MachOHeader {
    /// Arquiteturas de um executável Mach-O, thin ou universal, a partir dos primeiros bytes do arquivo.
    /// Retorna um conjunto vazio quando o formato não é reconhecido (por exemplo, um script).
    static func architectures(in header: Data) -> Set<CPUArchitecture> {
        guard let magic = header.uint32(at: 0, bigEndian: true) else { return [] }
        switch magic {
        case 0xCFFA_EDFE, 0xCEFA_EDFE:
            // Thin little-endian (64 ou 32 bits): cputype logo após o magic.
            guard let cpuType = header.uint32(at: 4, bigEndian: false) else { return [] }
            return [CPUArchitecture(cpuType: Int32(bitPattern: cpuType))]
        case 0xCAFE_BABE, 0xCAFE_BABF:
            // Universal: cabeçalhos big-endian de 20 bytes (fat) ou 32 bytes (fat64).
            let entrySize = magic == 0xCAFE_BABE ? 20 : 32
            // Arquivos .class de Java também começam com CAFEBABE, mas com uma "contagem" bem maior.
            guard let count = header.uint32(at: 4, bigEndian: true), (1...32).contains(count) else { return [] }
            var result: Set<CPUArchitecture> = []
            for index in 0..<Int(count) {
                // Cabeçalho truncado não é confiável: melhor "desconhecido" do que uma lista parcial.
                guard let cpuType = header.uint32(at: 8 + index * entrySize, bigEndian: true) else { return [] }
                result.insert(CPUArchitecture(cpuType: Int32(bitPattern: cpuType)))
            }
            return result
        default:
            return []
        }
    }
}

private extension Data {
    func uint32(at offset: Int, bigEndian: Bool) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        var value: UInt32 = 0
        for byte in 0..<4 {
            value = value << 8 | UInt32(self[startIndex + offset + (bigEndian ? byte : 3 - byte)])
        }
        return value
    }
}
