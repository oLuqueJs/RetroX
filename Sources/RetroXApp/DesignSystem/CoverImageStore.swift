import AppKit
import Observation
import RetroXCore

/// Capas já reduzidas, decodificadas fora da main thread e guardadas em memória (ADR-0008).
@MainActor
@Observable
final class CoverImageStore {
    private var images: [URL: NSImage] = [:]
    @ObservationIgnored private var inFlight: Set<URL> = []

    nonisolated static let maxPixelSize = 900

    func image(for url: URL?) -> NSImage? {
        url.flatMap { images[$0] }
    }

    func load(_ url: URL) async {
        guard images[url] == nil, inFlight.insert(url).inserted else { return }
        let cgImage = await Task.detached(priority: .utility) {
            CoverThumbnailer.thumbnail(of: url, maxPixelSize: Self.maxPixelSize)
        }.value
        inFlight.remove(url)
        if let cgImage {
            images[url] = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
}
