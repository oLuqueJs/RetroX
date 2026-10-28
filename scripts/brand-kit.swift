// Gera o kit da marca a partir de docs/design/rayo/rayo.png. Uso: swift scripts/brand-kit.swift
//
// Escreve docs/design/logo/ (ícone, tile, assinaturas e prancha), Support/RetroX.icns e o tile usado pelo app
// (Sources/RetroXApp/Resources/RayoMark.png). As regras de alinhamento estão em docs/design/logo/README.md e são
// as mesmas de BrandLockup no app.
import AppKit
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("docs/design/rayo/rayo.png")
let logo = root.appendingPathComponent("docs/design/logo")

func hex(_ value: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

enum Palette {
    static let rose = hex(0xFEB5B8)      // cabelo da Rayo: o "X" sobre fundo escuro
    static let roseDeep = hex(0xB83A55)  // o "X" sobre fundo claro (AA no claro e no branco)
    static let sky = hex(0x7BADFD)       // fundo do tile
    static let ink = hex(0x1E1B18), paper = hex(0xF3EEE7)
    static let night = hex(0x1B1916), day = hex(0xF4F0EA)
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

// MARK: Nome

/// SF Pro Rounded Heavy, como no app.
func brandFont(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded)!, size: size)!
}

struct Wordmark {
    /// Aperto extra entre "o" e "X", em fração do corpo (o app usa o mesmo valor).
    static let oxKern: CGFloat = -0.045
    let line: CTLine
    let font: NSFont
    /// Largura da tinta, do primeiro ao último traço (sem os recuos laterais das letras).
    let inkWidth: CGFloat
    let leftBearing: CGFloat

    init(size: CGFloat, text: NSColor, x: NSColor) {
        font = brandFont(size)
        let tracking = -0.015 * size
        let string = NSMutableAttributedString(string: "RetroX", attributes: [
            .font: font, .foregroundColor: text, .kern: tracking,
        ])
        string.addAttribute(.foregroundColor, value: x, range: NSRange(location: 5, length: 1))
        // O X tem recuo lateral largo: sem isso, o vão "o→X" fica o dobro dos outros.
        string.addAttribute(.kern, value: tracking + Wordmark.oxKern * size, range: NSRange(location: 4, length: 1))
        string.addAttribute(.kern, value: 0, range: NSRange(location: 5, length: 1))
        line = CTLineCreateWithAttributedString(string)
        let ink = CTLineGetImageBounds(line, nil)
        inkWidth = ink.width
        leftBearing = ink.minX
    }

    var capHeight: CGFloat { font.capHeight }

    /// Desenha com a tinta começando em `x` e a linha de base em `baseline`.
    func draw(x: CGFloat, baseline: CGFloat) {
        let context = NSGraphicsContext.current!.cgContext
        context.textPosition = CGPoint(x: x - leftBearing, y: baseline)
        CTLineDraw(line, context)
    }
}

// MARK: Regras de composição (iguais às do app)

/// Horizontal: tile = 2 × altura das maiúsculas, vão = 0,75 × altura das maiúsculas, faixa das maiúsculas
/// centrada no tile. Respiro em volta = 1 × altura das maiúsculas.
func horizontal(fontSize: CGFloat, text: NSColor, x: NSColor, background: NSColor?) -> NSBitmapImageRep {
    let word = Wordmark(size: fontSize, text: text, x: x)
    let cap = word.capHeight, tile = 2 * cap, gap = 0.75 * cap, pad = cap
    let width = pad + tile + gap + word.inkWidth + pad
    let height = pad + tile + pad
    return render(width: width, height: height, background: background) {
        drawTile(in: NSRect(x: pad, y: pad, width: tile, height: tile))
        word.draw(x: pad + tile + gap, baseline: pad + (tile - cap) / 2)
    }
}

/// Empilhada: tile = 3 × altura das maiúsculas, vão até o topo das maiúsculas = 1 × altura das maiúsculas,
/// os dois centrados pela tinta.
func stacked(fontSize: CGFloat, text: NSColor, x: NSColor, background: NSColor?) -> NSBitmapImageRep {
    let word = Wordmark(size: fontSize, text: text, x: x)
    let cap = word.capHeight, tile = 3 * cap, gap = cap, pad = cap
    let width = pad + max(tile, word.inkWidth) + pad
    let height = pad + cap + gap + tile + pad
    return render(width: width, height: height, background: background) {
        drawTile(in: NSRect(x: (width - tile) / 2, y: pad + cap + gap, width: tile, height: tile))
        word.draw(x: (width - word.inkWidth) / 2, baseline: pad)
    }
}

func wordmark(fontSize: CGFloat, text: NSColor, x: NSColor) -> NSBitmapImageRep {
    let word = Wordmark(size: fontSize, text: text, x: x)
    let pad = word.capHeight * 0.5
    return render(width: word.inkWidth + 2 * pad, height: word.capHeight + 2 * pad, background: nil) {
        word.draw(x: pad, baseline: pad)
    }
}

// MARK: Saída

func render(width: CGFloat, height: CGFloat, background: NSColor?, draw: () -> Void) -> NSBitmapImageRep {
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
    return render(width: CGFloat(side), height: CGFloat(side), background: nil) {
        drawTile(in: NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k))
    }
}

func tileOnly(side: Int) -> NSBitmapImageRep {
    render(width: CGFloat(side), height: CGFloat(side), background: nil) {
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

let onDark = (text: Palette.paper, x: Palette.rose)
let onLight = (text: Palette.ink, x: Palette.roseDeep)
let lockupDark = horizontal(fontSize: 160, text: onDark.text, x: onDark.x, background: nil)
let lockupLight = horizontal(fontSize: 160, text: onLight.text, x: onLight.x, background: nil)
let stackDark = stacked(fontSize: 120, text: onDark.text, x: onDark.x, background: nil)
let stackLight = stacked(fontSize: 120, text: onLight.text, x: onLight.x, background: nil)
write(lockupDark, logo.appendingPathComponent("retrox-lockup-on-dark.png"))
write(lockupLight, logo.appendingPathComponent("retrox-lockup-on-light.png"))
write(stackDark, logo.appendingPathComponent("retrox-stacked-on-dark.png"))
write(stackLight, logo.appendingPathComponent("retrox-stacked-on-light.png"))
write(wordmark(fontSize: 160, text: onDark.text, x: onDark.x), logo.appendingPathComponent("retrox-wordmark-on-dark.png"))
write(wordmark(fontSize: 160, text: onLight.text, x: onLight.x), logo.appendingPathComponent("retrox-wordmark-on-light.png"))

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

// Prancha: assinaturas sobre o escuro e o claro, e o ícone em tamanhos reais.
let sheetWidth: CGFloat = 2000, half: CGFloat = 640
let sheet = render(width: sheetWidth, height: half * 2 + 360, background: nil) {
    Palette.night.setFill(); NSRect(x: 0, y: half + 360, width: sheetWidth, height: half).fill()
    Palette.day.setFill(); NSRect(x: 0, y: 360, width: sheetWidth, height: half).fill()
    hex(0x262320).setFill(); NSRect(x: 0, y: 0, width: sheetWidth, height: 360).fill()
    func place(_ rep: NSBitmapImageRep, centerX: CGFloat, centerY: CGFloat, scale: CGFloat) {
        let w = CGFloat(rep.pixelsWide) * scale, h = CGFloat(rep.pixelsHigh) * scale
        image(rep).draw(in: NSRect(x: centerX - w / 2, y: centerY - h / 2, width: w, height: h))
    }
    place(lockupDark, centerX: 620, centerY: half + 360 + half / 2, scale: 0.75)
    place(stackDark, centerX: 1560, centerY: half + 360 + half / 2, scale: 0.85)
    place(lockupLight, centerX: 620, centerY: 360 + half / 2, scale: 0.75)
    place(stackLight, centerX: 1560, centerY: 360 + half / 2, scale: 0.85)
    var x: CGFloat = 160
    for side in [256, 128, 64, 32, 16] {
        place(icon(side: side), centerX: x + CGFloat(side) / 2, centerY: 180, scale: 1)
        x += CGFloat(side) + 120
    }
}
write(sheet, logo.appendingPathComponent("retrox-kit.png"))
