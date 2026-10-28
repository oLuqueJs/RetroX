import AppKit

/// Revisão visual sem permissão de Gravação de Tela: o app grava a própria janela em PNG.
/// `RetroX -RetroXSnapshot /caminho/tela.png [-RetroXInitialScreen emulators] [-RetroXSnapshotDelay 0.8]`
@MainActor
enum DebugSnapshot {
    static func captureIfRequested() async {
        guard let path = UserDefaults.standard.string(forKey: "RetroXSnapshot") else { return }
        let delay = UserDefaults.standard.object(forKey: "RetroXSnapshotDelay") == nil
            ? 3 : UserDefaults.standard.double(forKey: "RetroXSnapshotDelay")
        try? await Task.sleep(for: .seconds(delay))
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let view = window.contentView,
              let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: representation)
        try? representation.representation(using: .png, properties: [:])?.write(to: URL(filePath: path))
    }
}
