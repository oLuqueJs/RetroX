import Testing
@testable import RetroXCore

struct PCSX2AdapterTests {
    let adapter = PCSX2Adapter()

    @Test("Padrão: -batch, --, caminho")
    func defaultArguments() throws {
        let arguments = try adapter.arguments(romPath: "/Jogos/GT4.iso", options: adapter.defaultOptions, extraArguments: [])
        #expect(arguments == ["-batch", "--", "/Jogos/GT4.iso"])
    }

    @Test("Opções tipadas viram flags na ordem esperada")
    func typedOptions() throws {
        let options = PCSX2Options(batch: false, fullscreen: .on, bigPicture: true, boot: .fast)
        let arguments = try adapter.arguments(romPath: "/j.iso", options: .pcsx2(options), extraArguments: ["-portable"])
        #expect(arguments == ["-fullscreen", "-bigpicture", "-fastboot", "-portable", "--", "/j.iso"])
    }

    @Test("Tela cheia e boot desligáveis")
    func offVariants() throws {
        let options = PCSX2Options(fullscreen: .off, boot: .slow)
        let arguments = try adapter.arguments(romPath: "/j.iso", options: .pcsx2(options), extraArguments: [])
        #expect(arguments == ["-batch", "-nofullscreen", "-slowboot", "--", "/j.iso"])
    }

    /// Caminhos que quebrariam uma linha de shell. Aqui cada um tem que chegar como um único elemento, byte a byte.
    @Test("O caminho da ROM chega inteiro, byte a byte", arguments: [
        "/Volumes/Jogos Ação/Test Drive Unlimited (USA).iso",
        "/Volumes/Jogos Ac\u{0327}a\u{0303}o/NFD (Brasil).iso",
        "/Jogos/-começa-com-hifen.iso",
        "/Jogos/a=b.iso",
        "/Jogos/\"aspas\" e 'apóstrofo'.iso",
        "/Jogos/$(rm -rf ~); `x` & | > <.iso",
        "/Jogos/quebra\nde linha.iso",
        "/Jogos/🎮 日本語 ñ.iso",
        "/Jogos/" + String(repeating: "longo ", count: 200) + ".iso",
    ])
    func romPathIsSingleExactElement(path: String) throws {
        let arguments = try adapter.arguments(romPath: path, options: adapter.defaultOptions, extraArguments: [])
        #expect(arguments.count == 3)
        #expect(arguments[1] == "--")
        // String do Swift compara por equivalência canônica (NFC == NFD); aqui a forma exata importa.
        #expect(Array(arguments[2].utf8) == Array(path.utf8))
    }

    @Test("Recusa argumentos extras que colidem com flags gerenciadas", arguments: [
        "--", "-batch", "-fullscreen", "-elf", "-bios", "-help", "", "-x\0y",
    ])
    func rejectsManagedExtraArguments(extra: String) {
        #expect(throws: LaunchError.invalidExtraArgument(extra)) {
            try adapter.arguments(romPath: "/j.iso", options: adapter.defaultOptions, extraArguments: [extra])
        }
    }

    @Test("Aceita argumentos extras legítimos")
    func acceptsUserExtraArguments() throws {
        let arguments = try adapter.arguments(
            romPath: "/j.iso", options: adapter.defaultOptions, extraArguments: ["-datapath", "/Dados PCSX2"]
        )
        #expect(arguments == ["-batch", "-datapath", "/Dados PCSX2", "--", "/j.iso"])
    }

    @Test("Formatos do MVP só para PS2")
    func supportedExtensions() {
        #expect(adapter.supportedExtensions(for: .ps2) == ["iso", "chd", "cso", "zso"])
        #expect(adapter.supportedExtensions(for: GameSystemID(rawValue: "wii")).isEmpty)
    }
}

struct LaunchErrorTests {
    @Test("Todo erro oferece ao menos uma ação de correção e uma mensagem", arguments: [
        LaunchError.emulatorNotConfigured(.ps2), .emulatorDoesNotSupportSystem(.ps2), .emulatorNotFound,
        .emulatorBundleInvalid, .emulatorNotExecutable, .architectureUnsupported(rosettaMissing: true),
        .architectureUnsupported(rosettaMissing: false), .romNotFound, .romIsDirectory, .romUnreadable,
        .unsupportedFormat("zip"), .emulatorAlreadyRunning(bundleID: "net.pcsx2.pcsx2"),
        .invalidExtraArgument("--"), .launchFailed("x"), .exitedEarly(status: 1, after: .seconds(1)),
    ])
    func everyErrorIsActionable(error: LaunchError) {
        #expect(!error.recoveryActions.isEmpty)
        #expect(!error.message.isEmpty)
    }

    @Test("Mapeamentos principais")
    func keyMappings() {
        #expect(LaunchError.romNotFound.recoveryActions == [.locateROM])
        #expect(LaunchError.emulatorAlreadyRunning(bundleID: "x").recoveryActions == [.bringEmulatorToFront])
        #expect(LaunchError.architectureUnsupported(rosettaMissing: true).recoveryActions.first == .showRosettaHelp)
        #expect(LaunchError.emulatorNotConfigured(.ps2).message.contains("PS2"))
    }
}
