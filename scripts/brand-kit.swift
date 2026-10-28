// Gera o kit da marca a partir de docs/design/rayo/rayo.png. Uso: swift scripts/brand-kit.swift
//
// Escreve docs/design/logo/ (ícone, tile, assinaturas, X e prancha), Support/RetroX.icns e o tile usado pelo app
// (Sources/RetroXApp/Resources/RayoMark.png). As regras estão em docs/design/logo/README.md; o alinhamento é o
// mesmo de BrandLockup no app.
import AppKit
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("docs/design/rayo/rayo.png")
let logo = root.appendingPathComponent("docs/design/logo")

func hex(_ value: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

func hexString(_ color: NSColor) -> String {
    let c = color.usingColorSpace(.sRGB)!
    return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()),
                  Int((c.blueComponent * 255).rounded()))
}

enum Palette {
    static let rose = hex(0xFEB5B8)       // cabelo da Rayo: início do X sobre o escuro
    static let sky = hex(0x7BADFD)        // fundo do tile: fim do X sobre o escuro
    static let raspberry = hex(0xD63A62)  // início do X sobre o claro
    static let electric = hex(0x2F6BDF)   // fim do X sobre o claro
    static let ink = hex(0x1E1B18), paper = hex(0xF3EEE7)
    static let night = hex(0x1B1916), day = hex(0xF4F0EA)
    static let board = hex(0x262320), muted = hex(0xADA59B)
}

/// Cores de uma assinatura: o "Retro" e as duas pontas do gradiente do X.
struct Tone {
    let text, from, to: NSColor
    static let onDark = Tone(text: Palette.paper, from: Palette.rose, to: Palette.sky)
    static let onLight = Tone(text: Palette.ink, from: Palette.raspberry, to: Palette.electric)
}

// MARK: Gradiente em OKLCH

/// Mistura em OKLCH (espaço perceptual): o meio do gradiente fica vivo, sem o cinza da mistura em RGB.
enum OKLCH {
    private static func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    private static func gamma(_ c: CGFloat) -> CGFloat {
        let c = min(max(c, 0), 1)
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    static func lch(_ color: NSColor) -> (l: CGFloat, c: CGFloat, h: CGFloat) {
        let s = color.usingColorSpace(.sRGB)!
        let r = linear(s.redComponent), g = linear(s.greenComponent), b = linear(s.blueComponent)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let q = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * q
        let A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * q
        let B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * q
        return (L, hypot(A, B), atan2(B, A))
    }

    static func color(l: CGFloat, c: CGFloat, h: CGFloat) -> NSColor {
        let A = c * cos(h), B = c * sin(h)
        let l3 = pow(l + 0.3963377774 * A + 0.2158037573 * B, 3)
        let m3 = pow(l - 0.1055613458 * A - 0.0638541728 * B, 3)
        let q3 = pow(l - 0.0894841775 * A - 1.2914855480 * B, 3)
        let r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * q3
        let g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * q3
        let b = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * q3
        return NSColor(srgbRed: gamma(r), green: gamma(g), blue: gamma(b), alpha: 1)
    }

    /// `count` paradas de `from` a `to`, pelo caminho mais curto no círculo de matiz.
    static func stops(from: NSColor, to: NSColor, count: Int = 9) -> [NSColor] {
        let a = lch(from), b = lch(to)
        var dh = b.h - a.h
        if dh > .pi { dh -= 2 * .pi } else if dh < -.pi { dh += 2 * .pi }
        return (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(count - 1)
            return color(l: a.l + (b.l - a.l) * t, c: a.c + (b.c - a.c) * t, h: a.h + dh * t)
        }
    }
}

// MARK: Tile da Rayo

let sourceRep = NSBitmapImageRep(data: try! Data(contentsOf: source))!
let sourceImage = NSImage(size: NSSize(width: sourceRep.pixelsWide, height: sourceRep.pixelsHigh))
sourceImage.addRepresentation(sourceRep)

/// O tile claro sobre o fundo escuro do original, recuado alguns pixels para não pegar a borda.
let tileCrop: NSRect = {
    var minX = sourceRep.pixelsWide, maxX = 0, minY = sourceRep.pixelsHigh, maxY = 0
    for y in stride(from: 0, to: sourceRep.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: sourceRep.pixelsWide, by: 2) {
            guard let c = sourceRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  c.redComponent + c.greenComponent + c.blueComponent > 0.6 else { continue }
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    let inset = 6
    return NSRect(x: minX + inset, y: sourceRep.pixelsHigh - maxY + inset,
                  width: maxX - minX - 2 * inset, height: maxY - minY - 2 * inset)
}()

/// Raio do tile em fração do lado: o mesmo da grade de ícone do macOS (185/824).
let tileRadius: CGFloat = 185.0 / 824.0

func drawTile(in rect: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: rect.width * tileRadius, yRadius: rect.width * tileRadius).addClip()
    NSGraphicsContext.current?.imageInterpolation = .high
    sourceImage.draw(in: rect, from: tileCrop, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: O X

/// O X da marca: duas hastes em cápsula, na caixa e na espessura do X da fonte, com um vão em volta da haste da
/// frente (lê como uma passando sobre a outra) e o mesmo gradiente nas duas. As hastes do X da fonte afinam no
/// cruzamento; por isso ele é construído, e não recortado do glifo.
enum BrandX {
    /// Vão entre as hastes, em fração do corpo.
    static let gap: CGFloat = 0.07

    static func draw(glyph: CGPath, size: CGFloat, tone: Tone, in ctx: CGContext) {
        let b = glyph.boundingBoxOfPath
        // Largura horizontal da haste perto do pé, convertida para a espessura perpendicular.
        let y = b.minY + 0.2 * b.height
        var x = b.minX, first: CGFloat?, last: CGFloat = 0
        while x <= b.midX {
            if glyph.contains(CGPoint(x: x, y: y)) { if first == nil { first = x }; last = x } else if first != nil { break }
            x += 0.25
        }
        let horizontalWidth = last - (first ?? last)
        var r = horizontalWidth * 0.35
        for _ in 0..<8 { r = horizontalWidth * sin(atan2(b.height - 2 * r, b.width - 2 * r)) / 2 }

        let back = CGMutablePath(), front = CGMutablePath()
        back.move(to: CGPoint(x: b.minX + r, y: b.maxY - r)); back.addLine(to: CGPoint(x: b.maxX - r, y: b.minY + r))
        front.move(to: CGPoint(x: b.minX + r, y: b.minY + r)); front.addLine(to: CGPoint(x: b.maxX - r, y: b.maxY - r))
        func capsule(_ path: CGPath, _ width: CGFloat) -> CGPath {
            path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        }
        let backShape = capsule(back, 2 * r), frontShape = capsule(front, 2 * r)

        // O rosa segura até 30% e então caminha até o azul, do canto de cima à esquerda ao de baixo à direita.
        let stops = OKLCH.stops(from: tone.from, to: tone.to)
        let colors = [stops[0]] + stops
        let locations: [CGFloat] = [0] + (0..<stops.count).map { 0.3 + 0.7 * CGFloat($0) / CGFloat(stops.count - 1) }
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: colors.map(\.cgColor) as CFArray, locations: locations)!
        func fill(_ shape: CGPath) {
            ctx.saveGState(); ctx.addPath(shape); ctx.clip()
            ctx.drawLinearGradient(gradient, start: CGPoint(x: b.minX, y: b.maxY), end: CGPoint(x: b.maxX, y: b.minY), options: [])
            ctx.restoreGState()
        }
        fill(backShape)
        ctx.saveGState(); ctx.addPath(backShape); ctx.clip()
        ctx.addPath(capsule(front, 2 * r + gap * size)); ctx.setBlendMode(.clear); ctx.fillPath()
        ctx.restoreGState()
        fill(frontShape)
    }
}

// MARK: Nome

/// SF Pro Rounded Heavy, como no app.
func brandFont(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded)!, size: size)!
}

struct Wordmark {
    /// Aperto extra entre "o" e "X", em fração do corpo (o app usa o mesmo valor).
    static let oxKern: CGFloat = -0.045
    let size: CGFloat
    let tone: Tone
    let line: CTLine
    let font: NSFont
    /// Largura da tinta, do primeiro ao último traço (sem os recuos laterais das letras).
    let inkWidth: CGFloat
    let leftBearing: CGFloat
    /// Contorno do glifo "X", na posição dele dentro da linha.
    let xGlyph: CGPath

    init(size: CGFloat, tone: Tone) {
        self.size = size
        self.tone = tone
        font = brandFont(size)
        let tracking = -0.015 * size
        let string = NSMutableAttributedString(string: "RetroX", attributes: [
            .font: font, .foregroundColor: tone.text, .kern: tracking,
        ])
        // O X é desenhado à parte (BrandX); na linha ele só ocupa o lugar.
        string.addAttribute(.foregroundColor, value: NSColor.clear, range: NSRange(location: 5, length: 1))
        // O X tem recuo lateral largo: sem isso, o vão "o→X" fica o dobro dos outros.
        string.addAttribute(.kern, value: tracking + Wordmark.oxKern * size, range: NSRange(location: 4, length: 1))
        string.addAttribute(.kern, value: 0, range: NSRange(location: 5, length: 1))
        line = CTLineCreateWithAttributedString(string)
        let ink = CTLineGetImageBounds(line, nil)
        inkWidth = ink.width
        leftBearing = ink.minX

        var glyphPath: CGPath?
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count), positions = [CGPoint](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRange(), &glyphs); CTRunGetPositions(run, CFRange(), &positions)
            CTRunGetStringIndices(run, CFRange(), &indices)
            let runFont = (CTRunGetAttributes(run) as NSDictionary)[NSAttributedString.Key.font] as! NSFont
            for i in 0..<count where indices[i] == 5 {
                var move = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                glyphPath = CTFontCreatePathForGlyph(runFont as CTFont, glyphs[i], &move)
            }
        }
        xGlyph = glyphPath!
    }

    var capHeight: CGFloat { font.capHeight }

    /// Desenha com a tinta começando em `x` e a linha de base em `baseline`.
    func draw(x: CGFloat, baseline: CGFloat) {
        let ctx = NSGraphicsContext.current!.cgContext
        let origin = CGPoint(x: x - leftBearing, y: baseline)
        ctx.textPosition = origin
        CTLineDraw(line, ctx)
        var move = CGAffineTransform(translationX: origin.x, y: origin.y)
        BrandX.draw(glyph: xGlyph.copy(using: &move)!, size: size, tone: tone, in: ctx)
    }
}

// MARK: Regras de composição (iguais às do app)

/// Horizontal: tile = 2 × altura das maiúsculas, vão = 0,75 × altura das maiúsculas, faixa das maiúsculas
/// centrada no tile. Respiro em volta = 1 × altura das maiúsculas.
func horizontal(fontSize: CGFloat, tone: Tone) -> NSBitmapImageRep {
    let word = Wordmark(size: fontSize, tone: tone)
    let cap = word.capHeight, tile = 2 * cap, gap = 0.75 * cap, pad = cap
    return render(width: pad + tile + gap + word.inkWidth + pad, height: pad + tile + pad) {
        drawTile(in: NSRect(x: pad, y: pad, width: tile, height: tile))
        word.draw(x: pad + tile + gap, baseline: pad + (tile - cap) / 2)
    }
}

/// Empilhada: tile = 3 × altura das maiúsculas, vão até o topo das maiúsculas = 1 × altura das maiúsculas,
/// os dois centrados pela tinta.
func stacked(fontSize: CGFloat, tone: Tone) -> NSBitmapImageRep {
    let word = Wordmark(size: fontSize, tone: tone)
    let cap = word.capHeight, tile = 3 * cap, gap = cap, pad = cap
    let width = pad + max(tile, word.inkWidth) + pad
    return render(width: width, height: pad + cap + gap + tile + pad) {
        drawTile(in: NSRect(x: (width - tile) / 2, y: pad + cap + gap, width: tile, height: tile))
        word.draw(x: (width - word.inkWidth) / 2, baseline: pad)
    }
}

func wordmark(fontSize: CGFloat, tone: Tone) -> NSBitmapImageRep {
    let word = Wordmark(size: fontSize, tone: tone)
    let pad = word.capHeight * 0.5
    return render(width: word.inkWidth + 2 * pad, height: word.capHeight + 2 * pad) {
        word.draw(x: pad, baseline: pad)
    }
}

/// Só o X, centrado num quadrado transparente.
func xMark(side: CGFloat, tone: Tone) -> NSBitmapImageRep {
    let size = side * 0.62 / brandFont(100).capHeight * 100
    let font = brandFont(size)
    var glyph = CGGlyph()
    var character = UniChar(("X" as Character).asciiValue!)
    CTFontGetGlyphsForCharacters(font as CTFont, &character, &glyph, 1)
    let path = CTFontCreatePathForGlyph(font as CTFont, glyph, nil)!
    let b = path.boundingBoxOfPath
    var center = CGAffineTransform(translationX: (side - b.width) / 2 - b.minX, y: (side - b.height) / 2 - b.minY)
    return render(width: side, height: side) {
        BrandX.draw(glyph: path.copy(using: &center)!, size: size, tone: tone, in: NSGraphicsContext.current!.cgContext)
    }
}

// MARK: Saída

func render(width: CGFloat, height: CGFloat, background: NSColor? = nil, draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width.rounded(.up)), pixelsHigh: Int(height.rounded(.up)),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    if let background {
        background.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
    }
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Ícone na grade do macOS: corpo de 824/1024, cantos transparentes.
func icon(side: Int) -> NSBitmapImageRep {
    let k = CGFloat(side) / 1024
    return render(width: CGFloat(side), height: CGFloat(side)) {
        drawTile(in: NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k))
    }
}

func tileOnly(side: Int) -> NSBitmapImageRep {
    render(width: CGFloat(side), height: CGFloat(side)) {
        drawTile(in: NSRect(x: 0, y: 0, width: side, height: side))
    }
}

func write(_ rep: NSBitmapImageRep, _ url: URL) {
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print(url.path.replacingOccurrences(of: root.path + "/", with: ""))
}

func image(_ rep: NSBitmapImageRep) -> NSImage {
    let image = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
    image.addRepresentation(rep)
    return image
}

try? FileManager.default.createDirectory(at: logo, withIntermediateDirectories: true)

write(icon(side: 1024), logo.appendingPathComponent("retrox-icon-1024.png"))
write(tileOnly(side: 512), logo.appendingPathComponent("retrox-tile-512.png"))
write(tileOnly(side: 384), root.appendingPathComponent("Sources/RetroXApp/Resources/RayoMark.png"))

let lockupDark = horizontal(fontSize: 160, tone: .onDark)
let lockupLight = horizontal(fontSize: 160, tone: .onLight)
let stackDark = stacked(fontSize: 120, tone: .onDark)
let stackLight = stacked(fontSize: 120, tone: .onLight)
let xDark = xMark(side: 512, tone: .onDark)
let xLight = xMark(side: 512, tone: .onLight)
write(lockupDark, logo.appendingPathComponent("retrox-lockup-on-dark.png"))
write(lockupLight, logo.appendingPathComponent("retrox-lockup-on-light.png"))
write(stackDark, logo.appendingPathComponent("retrox-stacked-on-dark.png"))
write(stackLight, logo.appendingPathComponent("retrox-stacked-on-light.png"))
write(wordmark(fontSize: 160, tone: .onDark), logo.appendingPathComponent("retrox-wordmark-on-dark.png"))
write(wordmark(fontSize: 160, tone: .onLight), logo.appendingPathComponent("retrox-wordmark-on-light.png"))
write(xDark, logo.appendingPathComponent("retrox-x-on-dark.png"))
write(xLight, logo.appendingPathComponent("retrox-x-on-light.png"))

// Iconset → .icns
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("RetroX-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for side in [16, 32, 128, 256, 512] {
    try! icon(side: side).representation(using: .png, properties: [:])!
        .write(to: iconset.appendingPathComponent("icon_\(side)x\(side).png"))
    try! icon(side: side * 2).representation(using: .png, properties: [:])!
        .write(to: iconset.appendingPathComponent("icon_\(side)x\(side)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Support/RetroX.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("Support/RetroX.icns")

// MARK: Prancha

/// Assinaturas sobre o escuro e o claro; embaixo, o X, as cores e o ícone em tamanhos reais.
let boardWidth: CGFloat = 2400, band: CGFloat = 620, base: CGFloat = 680
let boardHeight = band * 2 + base
let board = render(width: boardWidth, height: boardHeight, background: Palette.board) {
    func place(_ rep: NSBitmapImageRep, centerX: CGFloat, centerY: CGFloat, scale: CGFloat = 1) {
        let w = CGFloat(rep.pixelsWide) * scale, h = CGFloat(rep.pixelsHigh) * scale
        image(rep).draw(in: NSRect(x: (centerX - w / 2).rounded(), y: (centerY - h / 2).rounded(), width: w, height: h))
    }
    func caption(_ text: String, x: CGFloat, y: CGFloat, color: NSColor = Palette.muted, size: CGFloat = 22,
                 weight: NSFont.Weight = .semibold, tracking: CGFloat = 2) {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: tracking,
        ]).draw(at: NSPoint(x: x, y: y))
    }

    // Assinaturas
    let darkTop = boardHeight, lightTop = boardHeight - band
    Palette.night.setFill(); NSRect(x: 0, y: darkTop - band, width: boardWidth, height: band).fill()
    Palette.day.setFill(); NSRect(x: 0, y: lightTop - band, width: boardWidth, height: band).fill()
    caption("SOBRE O ESCURO", x: 64, y: darkTop - 72, color: hex(0x7A7268))
    caption("SOBRE O CLARO", x: 64, y: lightTop - 72, color: hex(0x8C8378))
    place(lockupDark, centerX: 760, centerY: darkTop - band / 2, scale: 0.9)
    place(stackDark, centerX: 1880, centerY: darkTop - band / 2, scale: 0.85)
    place(lockupLight, centerX: 760, centerY: lightTop - band / 2, scale: 0.9)
    place(stackLight, centerX: 1880, centerY: lightTop - band / 2, scale: 0.85)

    // O X
    let titleY = base - 92
    caption("O X", x: 64, y: titleY)
    let square: CGFloat = 270, squareY: CGFloat = 150
    Palette.night.setFill(); NSBezierPath(roundedRect: NSRect(x: 64, y: squareY, width: square, height: square), xRadius: 24, yRadius: 24).fill()
    Palette.day.setFill(); NSBezierPath(roundedRect: NSRect(x: 64 + square + 24, y: squareY, width: square, height: square), xRadius: 24, yRadius: 24).fill()
    place(xDark, centerX: 64 + square / 2, centerY: squareY + square / 2, scale: square / 512)
    place(xLight, centerX: 64 + square * 1.5 + 24, centerY: squareY + square / 2, scale: square / 512)
    caption("Duas hastes, gradiente em OKLCH", x: 64, y: squareY - 56, color: Palette.paper, size: 20, weight: .regular, tracking: 0)

    // Cores
    let colorsX: CGFloat = 740
    caption("CORES", x: colorsX, y: titleY)
    func gradientBar(_ tone: Tone, y: CGFloat, label: String) {
        let rect = NSRect(x: colorsX, y: y, width: 620, height: 64)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: 32, yRadius: 32).addClip()
        NSGradient(colors: OKLCH.stops(from: tone.from, to: tone.to))!.draw(in: rect, angle: 0)
        NSGraphicsContext.restoreGraphicsState()
        caption("\(hexString(tone.from)) → \(hexString(tone.to))", x: colorsX + 644, y: y + 30, color: Palette.paper, size: 20, weight: .semibold, tracking: 0)
        caption(label, x: colorsX + 644, y: y + 4, size: 18, weight: .regular, tracking: 0)
    }
    gradientBar(.onDark, y: 430, label: "X sobre o escuro")
    gradientBar(.onLight, y: 330, label: "X sobre o claro")
    let chips: [(NSColor, String)] = [(Palette.ink, "Tinta"), (Palette.paper, "Papel"), (Palette.night, "Noite"), (Palette.day, "Dia")]
    for (i, chip) in chips.enumerated() {
        let x = colorsX + CGFloat(i) * 235
        chip.0.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: 170, width: 72, height: 72), xRadius: 16, yRadius: 16).fill()
        hex(0x3B3632).setStroke()
        let outline = NSBezierPath(roundedRect: NSRect(x: x + 0.5, y: 170.5, width: 71, height: 71), xRadius: 16, yRadius: 16)
        outline.lineWidth = 1; outline.stroke()
        caption(chip.1, x: x + 88, y: 212, color: Palette.paper, size: 20, weight: .semibold, tracking: 0)
        caption(hexString(chip.0), x: x + 88, y: 184, size: 18, weight: .regular, tracking: 0)
    }

    // Ícone
    let iconX: CGFloat = 1700
    caption("ÍCONE", x: iconX, y: titleY)
    var x = iconX
    for side in [256, 128, 64, 32, 16] {
        place(icon(side: side), centerX: x + CGFloat(side) / 2, centerY: squareY + square / 2)
        x += CGFloat(side) + 36
    }
}
write(board, logo.appendingPathComponent("retrox-kit.png"))
