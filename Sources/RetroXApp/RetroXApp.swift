import AppKit
import SwiftUI

@main
struct RetroXApp: App {
    // Constante em vez de `@State`: ver o comentário em `LaunchViewModel.importer`.
    private let model = LaunchViewModel()

    init() {
        // Rodando fora de um .app (swift run), o processo nasceria sem ícone no Dock nem foco.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("RetroX", id: "main") {
            LaunchView(model: model)
        }
        .windowResizability(.contentMinSize)
    }
}
