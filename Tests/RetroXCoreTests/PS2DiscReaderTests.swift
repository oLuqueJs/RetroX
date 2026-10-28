import Foundation
import Testing
@testable import RetroXCore

/// ISO 9660 mínima: descritor de volume, pasta raiz e um SYSTEM.CNF. Sem nenhum dado de jogo.
enum SyntheticISO {
    static func make(systemConfig: String, fileName: String = "SYSTEM.CNF;1") -> Data {
        let sector = 2048
        var bytes = [UInt8](repeating: 0, count: 22 * sector)
        func put(_ value: UInt32, at offset: Int) {
            for byte in 0..<4 { bytes[offset + byte] = UInt8((value >> (8 * UInt32(byte))) & 0xFF) }
        }
        func record(at offset: Int, sector extent: UInt32, size: UInt32, name: [UInt8]) -> Int {
            let length = (33 + name.count + 1) & ~1
            bytes[offset] = UInt8(length)
            put(extent, at: offset + 2)
            put(size, at: offset + 10)
            bytes[offset + 32] = UInt8(name.count)
            bytes.replaceSubrange((offset + 33)..<(offset + 33 + name.count), with: name)
            return length
        }

        let descriptor = 16 * sector
        bytes[descriptor] = 1
        bytes.replaceSubrange((descriptor + 1)...(descriptor + 5), with: Array("CD001".utf8))
        bytes[descriptor + 128] = 0x00
        bytes[descriptor + 129] = 0x08  // 2048, little-endian
        _ = record(at: descriptor + 156, sector: 20, size: UInt32(sector), name: [0])

        var offset = 20 * sector
        offset += record(at: offset, sector: 20, size: UInt32(sector), name: [0])
        offset += record(at: offset, sector: 20, size: UInt32(sector), name: [1])
        let config = Array(systemConfig.utf8)
        _ = record(at: offset, sector: 21, size: UInt32(config.count), name: Array(fileName.utf8))
        bytes.replaceSubrange((21 * sector)..<(21 * sector + config.count), with: config)
        return Data(bytes)
    }
}

struct PS2DiscReaderTests {
    @Test("Lê o serial do SYSTEM.CNF de uma ISO")
    func readsSerial() throws {
        let folder = try TemporaryFolder()
        let iso = folder.url.appending(path: "Jogo (USA).iso")
        try SyntheticISO.make(systemConfig: "BOOT2 = cdrom0:\\SLUS_214.90;1\r\nVER = 1.00\r\nVMODE = NTSC\r\n").write(to: iso)
        #expect(PS2DiscReader.serial(of: iso) == "SLUS-21490")
    }

    @Test("Sem SYSTEM.CNF, arquivo que não é ISO 9660, ou formato comprimido: sem serial")
    func noSerial() throws {
        let folder = try TemporaryFolder()
        let other = folder.url.appending(path: "Outro.iso")
        try SyntheticISO.make(systemConfig: "x", fileName: "README.TXT;1").write(to: other)
        #expect(PS2DiscReader.serial(of: other) == nil)
        #expect(PS2DiscReader.serial(of: try folder.file("Vazio.iso", bytes: 40_000)) == nil)
        #expect(PS2DiscReader.serial(of: try folder.file("Jogo.chd", bytes: 10)) == nil)
    }

    @Test("Formatos do BOOT2", arguments: [
        ("BOOT2 = cdrom0:\\SLUS_214.90;1", "SLUS-21490"),
        ("boot2=cdrom0:\\sces_502.94;1", "SCES-50294"),
        ("BOOT2 = cdrom0:\\SLES_556.76;1\nVER = 1.01", "SLES-55676"),
        ("BOOT = cdrom:\\SLUS_000.01;1", nil),
        ("BOOT2 = cdrom0:\\GAME.ELF;1", nil),
    ] as [(String, String?)])
    func parsesBootLine(text: String, expected: String?) {
        #expect(PS2DiscReader.serial(fromSystemConfig: text) == expected)
    }

    @Test("Capa nomeada pelo serial vence a capa pelo nome")
    func serialCoverWins() {
        let covers = ["Test Drive Unlimited (USA).png", "SLUS-21490.jpg"].map { URL(filePath: "/c/\($0)") }
        let match = CoverMatcher.match(romFilename: "Test Drive Unlimited (USA).iso", serial: "SLUS-21490", covers: covers)
        #expect(match?.lastPathComponent == "SLUS-21490.jpg")
    }
}

struct PCSX2PluginVersionTests {
    @Test("Com duas versões na pasta, usa a mais nova (comparação numérica)")
    func prefersNewestVersion() {
        var scenario = PluginScenario(settings: nil)
        scenario.disk.addAppBundle(at: "/Emuladores/ps2/PCSX2-v2.10.0.app", executable: "PCSX2", version: "v2.10.0")
        scenario.disk.addAppBundle(at: "/Emuladores/ps2/PCSX2-v2.9.147.app", executable: "PCSX2", version: "v2.9.147")
        #expect(scenario.discover().app?.version == "v2.10.0")
    }
}
