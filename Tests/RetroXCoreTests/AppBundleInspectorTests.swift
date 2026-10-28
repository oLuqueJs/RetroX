import Foundation
import Testing
@testable import RetroXCore

private let recognizedHeaders: [(Data, Set<CPUArchitecture>)] = [
    (MachOSamples.thinX86_64, [.x86_64]),
    (MachOSamples.thinARM64, [.arm64]),
    (MachOSamples.universal, [.x86_64, .arm64]),
    (MachOSamples.universal64, [.arm64]),
]

struct MachOHeaderTests {
    @Test("Lê arquiteturas de cabeçalhos thin e universais", arguments: recognizedHeaders)
    func readsArchitectures(header: Data, expected: Set<CPUArchitecture>) {
        #expect(MachOHeader.architectures(in: header) == expected)
    }

    @Test("Não reconhece script, .class Java, dados truncados ou vazios", arguments: [
        MachOSamples.shellScript, MachOSamples.javaClass, Data([0xCF, 0xFA, 0xED]), Data(),
        MachOSamples.universal.prefix(12),
    ])
    func rejectsUnknownFormats(header: Data) {
        #expect(MachOHeader.architectures(in: header).isEmpty)
    }

    @Test("Funciona com Data fatiada (índice inicial diferente de zero)")
    func handlesSlices() {
        let padded = Data([0xFF, 0xFF]) + MachOSamples.thinARM64
        #expect(MachOHeader.architectures(in: padded.dropFirst(2)) == [.arm64])
    }
}

struct AppBundleInspectorTests {
    @Test("Lê executável, bundle ID, versão e arquitetura")
    func inspectsBundle() throws {
        var disk = FakeFileSystem()
        disk.addAppBundle(at: "/Apps/PCSX2.app", executable: "PCSX2")
        let info = try AppBundleInspector(fileSystem: disk).inspect(URL(filePath: "/Apps/PCSX2.app/"))
        #expect(info.executableURL.path(percentEncoded: false) == "/Apps/PCSX2.app/Contents/MacOS/PCSX2")
        #expect(info.bundleIdentifier == "net.pcsx2.pcsx2")
        #expect(info.version == "v2.9.144")
        #expect(info.architectures == [.x86_64])
    }

    @Test("App inexistente")
    func missingApp() {
        #expect(throws: LaunchError.emulatorNotFound) {
            try AppBundleInspector(fileSystem: FakeFileSystem()).inspect(URL(filePath: "/Apps/Nada.app"))
        }
    }

    @Test("Arquivo comum no lugar do .app")
    func plainFile() {
        var disk = FakeFileSystem()
        disk["/Apps/PCSX2.app"] = .file()
        #expect(throws: LaunchError.emulatorBundleInvalid) {
            try AppBundleInspector(fileSystem: disk).inspect(URL(filePath: "/Apps/PCSX2.app"))
        }
    }

    @Test("Pasta sem Info.plist")
    func missingInfoPlist() {
        var disk = FakeFileSystem()
        disk["/Apps/PCSX2.app"] = .directory
        #expect(throws: LaunchError.emulatorBundleInvalid) {
            try AppBundleInspector(fileSystem: disk).inspect(URL(filePath: "/Apps/PCSX2.app"))
        }
    }

    @Test("Info.plist aponta para executável que não existe")
    func missingExecutable() {
        var disk = FakeFileSystem()
        disk.addAppBundle(at: "/Apps/PCSX2.app", executable: "PCSX2")
        disk.entries["/Apps/PCSX2.app/Contents/MacOS/PCSX2"] = nil
        #expect(throws: LaunchError.emulatorBundleInvalid) {
            try AppBundleInspector(fileSystem: disk).inspect(URL(filePath: "/Apps/PCSX2.app"))
        }
    }

    @Test("Executável sem permissão de execução")
    func notExecutable() {
        var disk = FakeFileSystem()
        disk.addAppBundle(at: "/Apps/PCSX2.app", executableIsExecutable: false)
        #expect(throws: LaunchError.emulatorNotExecutable) {
            try AppBundleInspector(fileSystem: disk).inspect(URL(filePath: "/Apps/PCSX2.app"))
        }
    }
}

struct HostEnvironmentTests {
    let appleSilicon = HostEnvironment(architecture: .arm64, isRosettaInstalled: true)
    let appleSiliconWithoutRosetta = HostEnvironment(architecture: .arm64, isRosettaInstalled: false)
    let intel = HostEnvironment(architecture: .x86_64, isRosettaInstalled: false)

    @Test("Compatibilidade por arquitetura do executável")
    func compatibility() {
        #expect(appleSilicon.compatibility(with: [.arm64]) == .native)
        #expect(appleSilicon.compatibility(with: [.x86_64, .arm64]) == .native)
        #expect(appleSilicon.compatibility(with: [.x86_64]) == .rosetta)
        #expect(appleSiliconWithoutRosetta.compatibility(with: [.x86_64]) == .incompatible(rosettaMissing: true))
        #expect(intel.compatibility(with: [.x86_64]) == .native)
        #expect(intel.compatibility(with: [.arm64]) == .incompatible(rosettaMissing: false))
        #expect(appleSilicon.compatibility(with: []) == .unknown)
    }
}
