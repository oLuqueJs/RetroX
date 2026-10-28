import AppKit
import SwiftUI

/// Marca do RetroX: a Rayo. `mark` é o tile do ícone, sem a margem da grade do macOS. Originais em
/// docs/design/rayo/.
enum Brand {
    static let mark = load("RayoMark")

    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources") else { return nil }
        return NSImage(contentsOf: url)
    }
}
