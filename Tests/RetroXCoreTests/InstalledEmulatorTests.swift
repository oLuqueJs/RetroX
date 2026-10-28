import Foundation
import Testing
@testable import RetroXCore

/// Opt-in e somente leitura. Não abre emuladores nem acessa jogos/configurações pessoais.
struct InstalledEmulatorTests {
    @Test("Instalação real do PCSX2 e preparo de launch", .enabled(if: path("RX_PCSX2_APP") != nil))
    func pcsx2() throws {
        let app = try inspect("RX_PCSX2_APP")
        let folder = try TemporaryFolder()
        let rom = try folder.file("Jogos Ação 日本/-Teste (USA).iso")
        let profile = EmulatorProfile(name: "PCSX2", adapterID: .pcsx2, appURL: app.bundleURL, options: PCSX2Adapter().defaultOptions)
        let prepared = try GameLauncher(runningApplications: FakeRunningApplications()).prepare(
            LaunchRequest(romURL: rom, systemID: .ps2, profile: profile)
        )
        #expect(prepared.plan.executableURL == app.executableURL)
        #expect(prepared.plan.arguments == ["-batch", "--", rom.path(percentEncoded: false)])
        #expect(!prepared.warnings.contains { if case .unexpectedBundleIdentifier = $0 { true } else { false } })
    }

    @Test("Inspeção do bundle instalado do Azahar", .enabled(if: path("RX_AZAHAR_APP") != nil))
    func azahar() throws { _ = try inspect("RX_AZAHAR_APP") }

    @Test("Inspeção do bundle instalado do Ryujinx", .enabled(if: path("RX_RYUJINX_APP") != nil))
    func ryujinx() throws { _ = try inspect("RX_RYUJINX_APP") }

    private static func path(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key].flatMap { $0.isEmpty ? nil : $0 }
    }

    private func inspect(_ key: String) throws -> AppBundleInfo {
        let path = try #require(Self.path(key))
        let app = try AppBundleInspector().inspect(URL(filePath: path))
        #expect(app.bundleIdentifier?.isEmpty == false)
        #expect(!app.architectures.isEmpty)
        switch HostEnvironment.current().compatibility(with: app.architectures) {
        case .native, .rosetta: break
        case .unknown, .incompatible: Issue.record("Arquitetura incompatível com este Mac: \(app.architectures)")
        }
        return app
    }
}
