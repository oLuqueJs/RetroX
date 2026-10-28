import GameController
import Observation

/// Ações semânticas da interface. Teclado e controle produzem as mesmas ações (ADR-0007).
enum InputAction: Hashable, Sendable {
    case up, down, left, right
    case confirm, back, details, favorite
    case previousShelf, nextShelf
    case menu
}

/// Traduz o controle de jogo em `InputAction`, com repetição ao segurar uma direção.
/// O teclado chega pelas views (`onKeyPress`) e é roteado para o mesmo lugar.
@MainActor
@Observable
final class InputCoordinator {
    private(set) var controllerName: String?
    /// Símbolos SF do controle conectado para cada ação (ex.: "xmark.circle" num controle PlayStation).
    private(set) var glyphs: [InputAction: String] = [:]
    /// Layout estilo Nintendo: o botão da direita confirma e o de baixo volta.
    private(set) var swapsConfirmAndBack: Bool
    /// Última ação recebida do controle e um contador, para o teste nos Ajustes.
    private(set) var lastAction: InputAction?
    private(set) var actionCount = 0

    @ObservationIgnored var onAction: ((InputAction) -> Void)?
    @ObservationIgnored private var heldDirection: InputAction?
    @ObservationIgnored private var repeatTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    static let initialRepeatDelay: Duration = .milliseconds(400)
    static let repeatInterval: Duration = .milliseconds(90)

    init() {
        swapsConfirmAndBack = UserDefaults.standard.bool(forKey: "input.swapConfirmBack")
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

    private func attach(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        // O GameController entrega os eventos na fila principal (handlerQueue padrão).
        pad.dpad.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated { self?.hold(Self.direction(x: x, y: y, threshold: 0.5)) }
        }
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated { self?.hold(Self.direction(x: x, y: y, threshold: 0.6)) }
        }
        let (south, east): (InputAction, InputAction) = swapsConfirmAndBack ? (.back, .confirm) : (.confirm, .back)
        let buttons: [(GCControllerButtonInput?, InputAction)] = [
            (pad.buttonA, south), (pad.buttonB, east), (pad.buttonX, .details), (pad.buttonY, .favorite),
            (pad.leftShoulder, .previousShelf), (pad.rightShoulder, .nextShelf), (pad.buttonMenu, .menu),
        ]
        for (button, action) in buttons {
            button?.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                MainActor.assumeIsolated { self?.send(action) }
            }
        }
        controllerName = controller.vendorName ?? String(localized: "Controle")
        glyphs = Dictionary(uniqueKeysWithValues: buttons.compactMap { button, action in
            button?.sfSymbolsName.map { (action, $0) }
        })
    }

    private func refreshCurrentController() {
        hold(nil)
        if let next = GCController.controllers().first(where: { $0.extendedGamepad != nil }) {
            attach(next)
        } else {
            controllerName = nil
            glyphs = [:]
        }
    }

    func setSwapsConfirmAndBack(_ swaps: Bool) {
        swapsConfirmAndBack = swaps
        UserDefaults.standard.set(swaps, forKey: "input.swapConfirmBack")
        refreshCurrentController()
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
        repeatTask = Task { [weak self] in
            try? await Task.sleep(for: Self.initialRepeatDelay)
            while !Task.isCancelled {
                self?.send(direction)
                try? await Task.sleep(for: Self.repeatInterval)
            }
        }
    }

    nonisolated static func direction(x: Float, y: Float, threshold: Float) -> InputAction? {
        if abs(x) < threshold, abs(y) < threshold { return nil }
        if abs(x) >= abs(y) { return x > 0 ? .right : .left }
        return y > 0 ? .up : .down
    }
}
