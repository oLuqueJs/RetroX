import AppKit
import CoreText
import SwiftUI

/// Marca do RetroX: a Rayo e o nome com o "X" na cor de tema. `mark` é o tile do ícone, sem a margem da grade
/// do macOS. As regras de composição são as do kit (docs/design/logo/README.md, scripts/brand-kit.swift).
enum Brand {
    @MainActor static let mark = load("RayoMark")

    /// Raio do tile em fração do lado: o mesmo da grade de ícone do macOS (185/824).
    static let tileRadius: CGFloat = 185.0 / 824.0
    /// Aperto extra entre "o" e "X", em fração do corpo: o X tem recuo lateral largo.
    static let oxKern: CGFloat = -0.045

    static func font(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    /// Medidas do nome num corpo: altura das maiúsculas, espaço entre a caixa do texto e o topo das maiúsculas,
    /// e o recuo à esquerda do "R" (para o vão até o tile ser medido da tinta).
    struct Metrics {
        let capHeight: CGFloat
        let aboveCaps: CGFloat
        let leftBearing: CGFloat

        init(size: CGFloat) {
            let base = NSFont.systemFont(ofSize: size, weight: .heavy)
            let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
            capHeight = font.capHeight
            aboveCaps = font.ascender - font.capHeight
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "R", attributes: [.font: font]))
            leftBearing = CTLineGetImageBounds(line, nil).minX
        }
    }

    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources") else { return nil }
        return NSImage(contentsOf: url)
    }
}

/// O nome: "Retro" na cor do texto e "X" na cor de tema, com o vão "o→X" corrigido.
struct BrandWordmark: View {
    let size: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text("Retro")
                .foregroundStyle(Theme.textPrimary)
            Text("X")
                .foregroundStyle(Theme.accent)
                .padding(.leading, Brand.oxKern * size)
        }
        .font(Brand.font(size))
        .kerning(-0.015 * size)
    }
}

/// Assinatura horizontal: tile = 2 × altura das maiúsculas, vão = 0,75 × altura das maiúsculas (medido da
/// tinta do "R"), e a faixa das maiúsculas centrada no tile.
struct BrandLockup: View {
    let size: CGFloat

    var body: some View {
        let metrics = Brand.Metrics(size: size)
        HStack(alignment: .center, spacing: 0.75 * metrics.capHeight - metrics.leftBearing) {
            BrandMark(size: 2 * metrics.capHeight)
            BrandWordmark(size: size)
                .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - metrics.capHeight / 2 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RetroX")
    }
}

/// O tile da Rayo; sem o recurso (build sem o bundle de recursos), cai num "R" provisório.
struct BrandMark: View {
    let size: CGFloat

    var body: some View {
        if let mark = Brand.mark {
            Image(nsImage: mark)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.18), radius: max(1, size * 0.08), y: size * 0.04)
        } else {
            RoundedRectangle(cornerRadius: size * Brand.tileRadius, style: .continuous)
                .fill(Theme.accent)
                .frame(width: size, height: size)
                .overlay {
                    Text("R")
                        .font(Brand.font(size * 0.58))
                        .foregroundStyle(Theme.onAccent)
                }
        }
    }
}
