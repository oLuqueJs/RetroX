import AppKit

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
        let response = await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        return response == .OK ? panel.url : nil
    }
}
