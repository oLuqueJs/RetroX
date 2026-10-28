import AppKit

// Emulador falso para os testes de integração: grava o argv recebido em JSON ao lado do .app
// (`argv-<pid>.json`) e fica aberto alguns segundos, para os testes simularem "emulador já aberto".

let outputURL = Bundle.main.bundleURL.deletingLastPathComponent().appending(path: "argv-\(getpid()).json")
do {
    try JSONEncoder().encode(Array(CommandLine.arguments.dropFirst())).write(to: outputURL)
} catch {
    FileHandle.standardError.write(Data("rx-fake-emulator: \(error)\n".utf8))
    exit(1)
}

// Integração de processos no CI: termina sem acessar WindowServer/LaunchServices.
if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--rx-headless-exit=") }),
   let status = Int32(argument.dropFirst("--rx-headless-exit=".count)) {
    exit(status)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
DispatchQueue.main.asyncAfter(deadline: .now() + 4) { exit(0) }
app.run()
