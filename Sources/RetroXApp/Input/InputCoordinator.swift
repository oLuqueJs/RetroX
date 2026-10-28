import GameController
import Observation
import RetroXCore
 
/// Ações semânticas da interface. Teclado e controle produzem as mesmas ações (ADR-0007).
enum InputAction: Hashable, Sendable {
    case up, down, left, right
    case confirm, back, details, favorite
    case previousShelf, nextShelf
    /// Gatilhos (LT/RT, L2/R2, ZL/ZR) e `[` `]`: trocam a aba de cima.
    case previousTab, nextTab
    /// Start / Options / +: Ajustes.
    case menu
    /// View / Create / −: Emuladores.
    case options
}

/// Velocidade da repetição ao segurar uma direção.
enum RepeatSpeed: String, CaseIterable, Identifiable {
    case slow, normal, fast

    var id: Self { self }

    var title: String {
        switch self {
        case .slow: String(localized: "Lenta")
        case .normal: String(localized: "Normal")
        case .fast: String(localized: "Rápida")
        }
    }

    var initialDelay: Duration {
        switch self {
        case .slow: .milliseconds(480)
        case .normal: .milliseconds(380)
        case .fast: .milliseconds(280)
        }
    }

    var interval: Duration {
        switch self {
        case .slow: .milliseconds(140)
        case .normal: .milliseconds(90)
        case .fast: .milliseconds(55)
        }
    }
}

/// Quando mostrar glifos de controle na barra de comandos.
enum HintsMode: String, CaseIterable, Identifiable {
    case automatic, keyboard, controller

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: String(localized: "Automático")
        case .keyboard: String(localized: "Teclado")
        case .controller: String(localized: "Controle")
        }
    }
}

/// Traduz o controle de jogo em `InputAction`, com repetição ao segurar uma direção.
/// O teclado chega pelas views (`onKeyPress`) e é roteado para o mesmo lugar.
@MainActor
@Observable
final class InputCoordinator {
    private(set) var controllerName: String?
    /// Família detectada do controle conectado (para o preset automático).
    private(set) var detectedPreset: ControllerPreset?
    private(set) var preset: ControllerPreset
    /// Inverte confirmar e voltar em relação ao preset.
    private(set) var swapsConfirmAndBack: Bool
    private(set) var repeatSpeed: RepeatSpeed
    private(set) var hintsMode: HintsMode
    /// Última ação recebida do controle e um contador, para o teste nos Ajustes.
    private(set) var lastAction: InputAction?
    private(set) var actionCount = 0

    @ObservationIgnored var onAction: ((InputAction) -> Void)?
    @ObservationIgnored private var heldDirection: InputAction?
    @ObservationIgnored private var repeatTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var controllerGlyphs: [ControllerControl: String] = [:]
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        preset = UserDefaults.standard.string(forKey: "input.preset").flatMap(ControllerPreset.init(rawValue:)) ?? .automatic
        swapsConfirmAndBack = UserDefaults.standard.bool(forKey: "input.swapConfirmBack")
        repeatSpeed = UserDefaults.standard.string(forKey: "input.repeatSpeed").flatMap(RepeatSpeed.init(rawValue:)) ?? .normal
        hintsMode = UserDefaults.standard.string(forKey: "input.hints").flatMap(HintsMode.init(rawValue:)) ?? .automatic
        // Com o emulador na frente, o RetroX não deve receber nada do controle (é o default; fica explícito).
        GCController.shouldMonitorBackgroundEvents = false
        let center = NotificationCenter.default
        // As notificações chegam na fila principal; o controle é relido de lá, sem atravessar isolamento.
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCurrentController() }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCurrentController() }
        })
        refreshCurrentController()
    }

    // MARK: Ajustes

    func setPreset(_ preset: ControllerPreset) {
        self.preset = preset
        defaults.set(preset.rawValue, forKey: "input.preset")
        refreshCurrentController()
    }

    func setSwapsConfirmAndBack(_ swaps: Bool) {
        swapsConfirmAndBack = swaps
        defaults.set(swaps, forKey: "input.swapConfirmBack")
        refreshCurrentController()
    }

    func setRepeatSpeed(_ speed: RepeatSpeed) {
        repeatSpeed = speed
        defaults.set(speed.rawValue, forKey: "input.repeatSpeed")
    }

    func setHintsMode(_ mode: HintsMode) {
        hintsMode = mode
        defaults.set(mode.rawValue, forKey: "input.hints")
    }

    // MARK: Glifos

    /// O preset que vale agora: o escolhido, ou o detectado no automático.
    var effectivePreset: ControllerPreset {
        preset == .automatic ? (detectedPreset ?? .xbox) : preset
    }

    /// Confirmar fica no botão da direita no layout Nintendo, ou quando o usuário inverte.
    var confirmsWithEastButton: Bool {
        effectivePreset.confirmsWithEastButton != swapsConfirmAndBack
    }

    /// Mostrar glifos de controle (e não teclas) na barra de comandos.
    var showsControllerGlyphs: Bool {
        switch hintsMode {
        case .automatic: controllerName != nil
        case .keyboard: false
        case .controller: true
        }
    }

    /// Símbolos SF para cada ação, conforme o preset (ou o próprio controle, no automático).
    var glyphs: [InputAction: String] {
        guard showsControllerGlyphs else { return [:] }
        var result: [InputAction: String] = [:]
        for (action, control) in controls {
            let symbol = preset == .automatic
                ? (controllerGlyphs[control] ?? effectivePreset.glyph(for: control))
                : preset.glyph(for: control)
            result[action] = symbol
        }
        return result
    }

    /// Qual controle físico dispara cada ação.
    private var controls: [InputAction: ControllerControl] {
        [
            .confirm: confirmsWithEastButton ? .east : .south,
            .back: confirmsWithEastButton ? .south : .east,
            .details: .west,
            .favorite: .north,
            .previousShelf: .leftShoulder,
            .nextShelf: .rightShoulder,
            .previousTab: .leftTrigger,
            .nextTab: .rightTrigger,
            .menu: .menu,
            .options: .options,
        ]
    }

    // MARK: Controle

    private func attach(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        // O GameController entrega os eventos na fila principal (handlerQueue padrão).
        pad.dpad.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated { self?.hold(Self.direction(x: x, y: y, threshold: 0.5)) }
        }
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated { self?.hold(Self.direction(x: x, y: y, threshold: 0.6)) }
        }
        let east = confirmsWithEastButton
        let buttons: [(GCControllerButtonInput?, ControllerControl, InputAction)] = [
            (pad.buttonA, .south, east ? .back : .confirm),
            (pad.buttonB, .east, east ? .confirm : .back),
            (pad.buttonX, .west, .details),
            (pad.buttonY, .north, .favorite),
            (pad.leftShoulder, .leftShoulder, .previousShelf),
            (pad.rightShoulder, .rightShoulder, .nextShelf),
            (pad.leftTrigger, .leftTrigger, .previousTab),
            (pad.rightTrigger, .rightTrigger, .nextTab),
            (pad.buttonMenu, .menu, .menu),
            (pad.buttonOptions, .options, .options),
        ]
        for (button, _, action) in buttons {
            button?.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                MainActor.assumeIsolated { self?.send(action) }
            }
        }
        controllerName = controller.vendorName ?? String(localized: "Controle")
        detectedPreset = ControllerPreset.detect(productCategory: controller.productCategory)
        controllerGlyphs = Dictionary(uniqueKeysWithValues: buttons.compactMap { button, control, _ in
            button?.sfSymbolsName.map { (control, $0) }
        })
    }

    private func refreshCurrentController() {
        hold(nil)
        if let next = GCController.controllers().first(where: { $0.extendedGamepad != nil }) {
            attach(next)
        } else {
            controllerName = nil
            detectedPreset = nil
            controllerGlyphs = [:]
        }
    }

    private func send(_ action: InputAction) {
        lastAction = action
        actionCount += 1
        onAction?(action)
    }

    /// Envia a direção na hora e, se ela continuar segurada, repete depois de um atraso.
    private func hold(_ direction: InputAction?) {
        guard direction != heldDirection else { return }
        heldDirection = direction
        repeatTask?.cancel()
        guard let direction else { return }
        send(direction)
        let speed = repeatSpeed
        repeatTask = Task { [weak self] in
            try? await Task.sleep(for: speed.initialDelay)
            while !Task.isCancelled {
                self?.send(direction)
                try? await Task.sleep(for: speed.interval)
            }
        }
    }

    nonisolated static func direction(x: Float, y: Float, threshold: Float) -> InputAction? {
        if abs(x) < threshold, abs(y) < threshold { return nil }
        if abs(x) >= abs(y) { return x > 0 ? .right : .left }
        return y > 0 ? .up : .down
    }
}
