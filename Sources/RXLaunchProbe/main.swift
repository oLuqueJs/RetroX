import Foundation
import RetroXCore

// Ferramenta de diagnóstico do spike de launch: usa o mesmo GameLauncher do app,
// mostra o plano validado e, sem --dry-run, abre o emulador.

// Saída por linha mesmo redirecionada para arquivo: scripts leem o "pid:" enquanto o emulador roda.
setvbuf(stdout, nil, _IOLBF, 0)

let usage = """
    uso: rx-launch-probe --app <Emulador.app> --rom <arquivo> [opções]

      --strategy workspace|process   como criar o processo (padrão: o do adapter)
      --dry-run                      só valida e mostra o argv, sem abrir nada
      --new-instance                 abre outra instância mesmo com o emulador aberto
      --fullscreen on|off            força ou desliga a tela cheia (padrão: config do emulador)
      --no-batch                     não passa -batch (o emulador não fecha ao parar o jogo)
      --log <arquivo>                grava stdout/stderr do emulador (só com --strategy process)
      --wait <segundos>              espera o emulador fechar e informa como a sessão terminou
    """

func fail(_ message: String, code: Int32 = 64) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(code)
}

var appPath: String?
var romPath: String?
var strategy: LaunchStrategy?
var dryRun = false
var newInstance = false
var waitSeconds: Int?
var logPath: String?
var pcsx2 = PCSX2Options()

var input = CommandLine.arguments.dropFirst().makeIterator()
@MainActor func value(for flag: String) -> String {
    guard let next = input.next() else { fail("\(flag) precisa de um valor.\n\n\(usage)") }
    return next
}
while let flag = input.next() {
    switch flag {
    case "--app": appPath = value(for: flag)
    case "--rom": romPath = value(for: flag)
    case "--strategy":
        guard let parsed = LaunchStrategy(rawValue: value(for: flag)) else { fail("Estratégia inválida.\n\n\(usage)") }
        strategy = parsed
    case "--dry-run": dryRun = true
    case "--new-instance": newInstance = true
    case "--fullscreen":
        switch value(for: flag) {
        case "on": pcsx2.fullscreen = .on
        case "off": pcsx2.fullscreen = .off
        default: fail("--fullscreen aceita on ou off.")
        }
    case "--no-batch": pcsx2.batch = false
    case "--log": logPath = value(for: flag)
    case "--wait":
        guard let seconds = Int(value(for: flag)), seconds > 0 else { fail("--wait precisa de segundos > 0.") }
        waitSeconds = seconds
    case "-h", "--help": print(usage); exit(0)
    default: fail("Opção desconhecida: \(flag)\n\n\(usage)")
    }
}
guard let appPath, let romPath else { fail(usage) }

let profile = EmulatorProfile(
    name: "PCSX2",
    adapterID: .pcsx2,
    appURL: URL(filePath: appPath),
    options: .pcsx2(pcsx2),
    strategy: strategy
)
let request = LaunchRequest(
    romURL: URL(filePath: romPath),
    systemID: .ps2,
    profile: profile,
    alreadyRunningPolicy: newInstance ? .launchNewInstance : .refuse
)
let launcher = GameLauncher(launchers: [
    .workspace: WorkspaceLauncher(),
    .process: FoundationProcessLauncher(outputLogURL: logPath.map { URL(filePath: $0) }),
])

do {
    let prepared = try launcher.prepare(request)
    let app = prepared.app
    let architectures = app.architectures.map(\.description).sorted().joined(separator: ", ")
    print("emulador: \(app.bundleIdentifier ?? "?") \(app.version ?? "?") [\(architectures)]")
    print("executável: \(prepared.plan.executableURL.path(percentEncoded: false))")
    for warning in prepared.warnings {
        print("aviso: \(warning.message)")
    }
    print("estratégia: \(prepared.plan.strategy.rawValue)")
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    print("argv: \(String(decoding: try! encoder.encode(prepared.plan.arguments), as: UTF8.self))")
    if dryRun {
        print("modo simulado: nada foi aberto.")
        exit(0)
    }

    let launched = try await launcher.launch(prepared)
    print("pid: \(launched.pid)")
    guard let waitSeconds else { exit(0) }

    let exit = await withTaskGroup(of: ProcessExit?.self) { group in
        group.addTask { await launched.waitForExit() }
        group.addTask {
            try? await Task.sleep(for: .seconds(waitSeconds))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
    guard let exit else {
        print("o emulador continua aberto após \(waitSeconds) s.")
        Foundation.exit(0)
    }
    let status = exit.status.map(String.init) ?? "n/d"
    switch SessionOutcome.classify(launchedAt: launched.launchedAt, exit: exit) {
    case .ended(let after):
        print("término: sessão normal após \(after.formatted(.units(allowed: [.minutes, .seconds]))) (status \(status))")
    case .exitedEarly(_, let after):
        print("término: fechou cedo, após \(after.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))) (status \(status))")
    }
} catch {
    fail("erro: \(error.message)\nações: \(error.recoveryActions.map(\.title).joined(separator: ", "))", code: 1)
}
