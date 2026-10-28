import AppKit
import Observation
import RetroXCore

/// Capas já reduzidas, decodificadas fora da main thread e guardadas em memória (ADR-0008).
@MainActor
@Observable
final class CoverImageStore {
    private var images: [URL: NSImage] = [:]
    /// Versões minúsculas para o fundo ambiente: ampliadas, já ficam desfocadas sem filtro caro.
    private var ambientImages: [URL: NSImage] = [:]
    @ObservationIgnored private var inFlight: Set<URL> = []
    @ObservationIgnored private var ambientInFlight: Set<URL> = []

    nonisolated static let maxPixelSize = 900

    func image(for url: URL?) -> NSImage? {
        url.flatMap { images[$0] }
    }

    func ambientImage(for url: URL?) -> NSImage? {
        url.flatMap { ambientImages[$0] }
    }

    func loadAmbient(_ url: URL) async {
        guard ambientImages[url] == nil, ambientInFlight.insert(url).inserted else { return }
        let cgImage = await Task.detached(priority: .utility) {
            CoverThumbnailer.thumbnail(of: url, maxPixelSize: 36)
        }.value
        ambientInFlight.remove(url)
        if let cgImage {
            ambientImages[url] = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }

    /// Esquece a imagem guardada (a capa foi trocada no mesmo endereço).
    func invalidate(_ url: URL) {
        images[url] = nil
        ambientImages[url] = nil
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
