import Foundation
@testable import RetroXCore

/// Disco em memória: caminho → entrada. Caminhos fictícios, nada da máquina real.
struct FakeFileSystem: FileSystemProbing {
    enum Entry {
        case directory
        case file(Data = Data(), readable: Bool = true, executable: Bool = false)
    }

    var entries: [String: Entry] = [:]

    subscript(path: String) -> Entry? {
        get { entries[Self.normalize(path)] }
        set { entries[Self.normalize(path)] = newValue }
    }

    func kind(of url: URL) -> FileItemKind {
        switch self[url.path(percentEncoded: false)] {
        case nil: .missing
        case .directory: .directory
        case .file: .regularFile
        }
    }

    func isReadable(_ url: URL) -> Bool {
        if case .file(_, let readable, _) = self[url.path(percentEncoded: false)] { return readable }
        return false
    }

    func isExecutable(_ url: URL) -> Bool {
        if case .file(_, _, let executable) = self[url.path(percentEncoded: false)] { return executable }
        return false
    }

    func readPrefix(of url: URL, maxLength: Int) throws -> Data {
        guard case .file(let data, true, _) = self[url.path(percentEncoded: false)] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return data.prefix(maxLength)
    }

    func contentsOfDirectory(at url: URL) -> [URL] {
        let parent = Self.normalize(url.path(percentEncoded: false))
        return entries.keys
            .filter { ($0 as NSString).deletingLastPathComponent == parent && !($0 as NSString).lastPathComponent.hasPrefix(".") }
            .sorted()
            .map { URL(filePath: $0) }
    }

    /// Cria um `.app` mínimo: Info.plist e executável com o cabeçalho Mach-O dado.
    mutating func addAppBundle(
        at path: String,
        executable: String = "Emu",
        bundleIdentifier: String? = "net.pcsx2.pcsx2",
        version: String? = "v2.9.144",
        header: Data = MachOSamples.thinX86_64,
        executableIsExecutable: Bool = true
    ) {
        var plist: [String: Any] = ["CFBundleExecutable": executable]
        plist["CFBundleIdentifier"] = bundleIdentifier
        plist["CFBundleShortVersionString"] = version
        let plistData = try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        self[path] = .directory
        self["\(path)/Contents"] = .directory
        self["\(path)/Contents/Info.plist"] = .file(plistData)
        self["\(path)/Contents/MacOS"] = .directory
        self["\(path)/Contents/MacOS/\(executable)"] = .file(header, executable: executableIsExecutable)
    }

    private static func normalize(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}

enum MachOSamples {
    /// MH_MAGIC_64 em little-endian + cputype.
    static let thinX86_64 = Data([0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01, 0x03, 0x00, 0x00, 0x00])
    static let thinARM64 = Data([0xCF, 0xFA, 0xED, 0xFE, 0x0C, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])

    /// FAT_MAGIC com duas entradas de 20 bytes: x86_64 e arm64.
    static let universal: Data = {
        var bytes: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x00, 0x00, 0x02]
        bytes += [0x01, 0x00, 0x00, 0x07] + [UInt8](repeating: 0, count: 16)
        bytes += [0x01, 0x00, 0x00, 0x0C] + [UInt8](repeating: 0, count: 16)
        return Data(bytes)
    }()

    /// FAT_MAGIC_64 com uma entrada de 32 bytes: arm64.
    static let universal64: Data = {
        var bytes: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBF, 0x00, 0x00, 0x00, 0x01]
        bytes += [0x01, 0x00, 0x00, 0x0C] + [UInt8](repeating: 0, count: 28)
        return Data(bytes)
    }()

    /// Cabeçalho de um .class Java: CAFEBABE seguido de versão, não de contagem de arquiteturas.
    static let javaClass = Data([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x00, 0x00, 0x41])
    static let shellScript = Data("#!/bin/sh\n".utf8)
}
