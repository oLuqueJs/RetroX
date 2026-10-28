import Foundation
import ImageIO

public enum ImageImporterError: Error, Equatable {
    case unreadableImage
    case writeFailed
}

/// Copia uma imagem escolhida pelo usuário (foto de perfil, capa) como PNG reduzido para dentro do RetroX.
/// O arquivo original nunca é alterado nem movido.
public enum ImageImporter {
    public static func importPNG(from source: URL, to destination: URL, maxPixelSize: Int) throws {
        guard let image = CoverThumbnailer.thumbnail(of: source, maxPixelSize: maxPixelSize) else {
            throw ImageImporterError.unreadableImage
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = destination.deletingLastPathComponent().appending(path: ".\(UUID().uuidString).png")
        guard let output = CGImageDestinationCreateWithURL(temporary as CFURL, "public.png" as CFString, 1, nil) else {
            throw ImageImporterError.writeFailed
        }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw ImageImporterError.writeFailed }
        // Grava num temporário e só então troca: uma falha no meio não deixa uma imagem pela metade.
        if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}
