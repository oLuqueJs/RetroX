import AppKit
import CoreText
import RetroXCore
import SwiftUI

/// Marca do RetroX: a Rayo e o nome com o "X" em gradiente. `mark` é o tile do ícone, sem a margem da grade
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

/// O nome: "Retro" na cor do texto e o X da marca, com o vão "o→X" corrigido.
struct BrandWordmark: View {
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Retro")
                .foregroundStyle(Theme.textPrimary)
                .font(Brand.font(size))
                .kerning(-0.015 * size)
            BrandX(size: size)
                .padding(.leading, Brand.oxKern * size)
        }
    }
}

/// O glifo "X" num corpo: o contorno já nas coordenadas do Canvas (y para baixo, a partir do topo do X), a caixa
/// original (y para cima, a partir da linha de base) e o avanço.
struct BrandXGeometry {
    let path: Path
    let bounds: CGRect
    let advance: CGFloat

    /// Guardada por corpo, porque o `body` pode ser recalculado a toda hora.
    @MainActor private static var cache: [CGFloat: BrandXGeometry] = [:]

    @MainActor static func of(size: CGFloat) -> BrandXGeometry {
        if let cached = cache[size] { return cached }
        let geometry = BrandXGeometry(size: size)
        cache[size] = geometry
        return geometry
    }

    private init(size: CGFloat) {
        let base = NSFont.systemFont(ofSize: size, weight: .heavy)
        let font = (base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base) as CTFont
        var character = UniChar(88) // "X"
        var glyph = CGGlyph()
        CTFontGetGlyphsForCharacters(font, &character, &glyph, 1)
        let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil) ?? CGPath(rect: .zero, transform: nil)
        let b = glyphPath.boundingBoxOfPath
        bounds = b
        advance = CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, nil, 1)
        path = Path(glyphPath).applying(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: b.maxY))
    }
}

/// O X da marca (docs/design/logo/README.md): a letra com a cor de destaque do tema. No escuro leva um gradiente
/// até o céu da Rayo, misturado em OKLCH, do canto de cima à esquerda ao de baixo à direita; no claro é sólido.
struct BrandX: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let geometry = BrandXGeometry.of(size: size)
        let b = geometry.bounds
        let dark = colorScheme == .dark
        let palette = Theme.current.theme.palette(dark: dark, retroXAccent: Theme.current.accent)
        let stops = Palette.brandXStops(palette, dark: dark).map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
        // A cor de destaque segura até 30% e então caminha até o céu.
        let gradient = Gradient(stops: [.init(color: stops[0], location: 0)] + stops.enumerated().map { index, color in
            .init(color: color, location: 0.3 + 0.7 * CGFloat(index) / CGFloat(stops.count - 1))
        })
        Canvas { context, _ in
            context.fill(geometry.path, with: .linearGradient(
                gradient, startPoint: CGPoint(x: b.minX, y: 0), endPoint: CGPoint(x: b.maxX, y: b.height)))
        }
        .frame(width: geometry.advance, height: b.height)
        .alignmentGuide(.firstTextBaseline) { _ in b.maxY }
        .accessibilityHidden(true)
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
