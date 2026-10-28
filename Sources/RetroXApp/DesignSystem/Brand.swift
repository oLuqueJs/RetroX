import AppKit
import CoreText
import RetroXCore
import SwiftUI

/// Marca do RetroX: a Rayo e o nome com o "X" de duas hastes em gradiente. `mark` é o tile do ícone, sem a margem da grade
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

/// Geometria do X da marca num corpo: a caixa do glifo "X" (y para cima, a partir da linha de base), o avanço e
/// o raio das hastes, medido da espessura do X da fonte.
struct BrandXGeometry {
    let bounds: CGRect
    let advance: CGFloat
    let radius: CGFloat

    /// A medida varre o contorno do glifo; guardada por corpo, porque o `body` pode ser recalculado a toda hora.
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
        let path = CTFontCreatePathForGlyph(font, glyph, nil) ?? CGPath(rect: .zero, transform: nil)
        let b = path.boundingBoxOfPath
        bounds = b
        advance = CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, nil, 1)
        // Largura horizontal da haste perto do pé, convertida para a espessura perpendicular.
        let y = b.minY + 0.2 * b.height
        var x = b.minX, first: CGFloat?, last: CGFloat = 0
        while x <= b.midX {
            if path.contains(CGPoint(x: x, y: y)) { if first == nil { first = x }; last = x } else if first != nil { break }
            x += max(size / 400, 0.05)
        }
        let horizontalWidth = last - (first ?? last)
        var r = horizontalWidth * 0.35
        for _ in 0..<8 { r = horizontalWidth * sin(atan2(b.height - 2 * r, b.width - 2 * r)) / 2 }
        radius = r
    }
}

/// O X da marca (docs/design/logo/README.md): duas hastes em cápsula, a "/" passando sobre a "\\" com um vão em
/// volta, e o mesmo gradiente nas duas, da cor de destaque do tema até o céu da Rayo, misturado em OKLCH.
struct BrandX: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    /// Vão entre as hastes, em fração do corpo.
    private static let gap: CGFloat = 0.07

    var body: some View {
        let geometry = BrandXGeometry.of(size: size)
        let b = geometry.bounds, r = geometry.radius, height = b.height
        let dark = colorScheme == .dark
        let palette = Theme.current.theme.palette(dark: dark, retroXAccent: Theme.current.accent)
        let stops = Palette.brandXStops(palette, dark: dark).map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
        // A cor de destaque segura até 30% e então caminha até o céu.
        let gradient = Gradient(stops: [.init(color: stops[0], location: 0)] + stops.enumerated().map { index, color in
            .init(color: color, location: 0.3 + 0.7 * CGFloat(index) / CGFloat(stops.count - 1))
        })
        Canvas { context, _ in
            // Coordenadas do Canvas: x igual ao do glifo, y para baixo a partir do topo do X.
            func capsule(from start: CGPoint, to end: CGPoint, width: CGFloat) -> Path {
                Path { $0.move(to: start); $0.addLine(to: end) }
                    .strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
            }
            let back = (CGPoint(x: b.minX + r, y: r), CGPoint(x: b.maxX - r, y: height - r))
            let front = (CGPoint(x: b.minX + r, y: height - r), CGPoint(x: b.maxX - r, y: r))
            let shading = GraphicsContext.Shading.linearGradient(
                gradient, startPoint: CGPoint(x: b.minX, y: 0), endPoint: CGPoint(x: b.maxX, y: height))
            context.drawLayer { layer in
                layer.fill(capsule(from: back.0, to: back.1, width: 2 * r), with: shading)
                layer.blendMode = .clear
                layer.fill(capsule(from: front.0, to: front.1, width: 2 * r + Self.gap * size), with: .color(.black))
                layer.blendMode = .normal
                layer.fill(capsule(from: front.0, to: front.1, width: 2 * r), with: shading)
            }
        }
        .frame(width: geometry.advance, height: height)
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
