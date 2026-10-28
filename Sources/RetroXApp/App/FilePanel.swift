import AppKit
import UniformTypeIdentifiers

/// Seletor nativo de pasta. Usa `NSOpenPanel` diretamente: o `fileImporter` do SwiftUI fechava o seletor
/// antes de entregar a escolha, e a escolha se perdia.
@MainActor
enum FilePanel {
    static func chooseFolder(message: String, startingAt directory: URL?) async -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = String(localized: "Escolher")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = directory
        let response = await present(panel)
        return response == .OK ? panel.url : nil
    }

    static func chooseImage(message: String) async -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = String(localized: "Usar imagem")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        let response = await present(panel)
        return response == .OK ? panel.url : nil
    }

    private static func present(_ panel: NSOpenPanel) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
    }
}
