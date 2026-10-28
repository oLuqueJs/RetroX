import Foundation

extension HexColor {
    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// `count` paradas de `from` a `to` misturadas em OKLCH (espaço perceptual), pelo caminho mais curto no
    /// círculo de matiz: o meio fica vivo, sem o cinza da mistura em RGB.
    public static func oklchStops(from: HexColor, to: HexColor, count: Int = 9) -> [HexColor] {
        let a = from.oklch, b = to.oklch
        var dh = b.h - a.h
        if dh > .pi { dh -= 2 * .pi } else if dh < -.pi { dh += 2 * .pi }
        return (0..<count).map { i in
            let t = Double(i) / Double(max(count - 1, 1))
            return HexColor(l: a.l + (b.l - a.l) * t, c: a.c + (b.c - a.c) * t, h: a.h + dh * t)
        }
    }

    private static func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    private static func gamma(_ c: Double) -> Double {
        let c = min(max(c, 0), 1)
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    private var oklch: (l: Double, c: Double, h: Double) {
        let r = Self.linear(red), g = Self.linear(green), b = Self.linear(blue)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        return (L, hypot(A, B), atan2(B, A))
    }

    private init(l: Double, c: Double, h: Double) {
        let A = c * cos(h), B = c * sin(h)
        let l3 = pow(l + 0.3963377774 * A + 0.2158037573 * B, 3)
        let m3 = pow(l - 0.1055613458 * A - 0.0638541728 * B, 3)
        let s3 = pow(l - 0.0894841775 * A - 1.2914855480 * B, 3)
        self.init(
            red: Self.gamma(4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3),
            green: Self.gamma(-1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3),
            blue: Self.gamma(-0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
        )
    }
}

extension Palette {
    /// Fim do gradiente do X da marca: o céu do fundo do tile da Rayo, mais fundo no claro (docs/design/logo).
    public static let brandXEnd = Tone(light: "2F6BDF", dark: "7BADFD")

    /// Paradas do gradiente do X: da cor de destaque do tema até o céu da Rayo.
    public static func brandXStops(_ palette: ThemePalette, dark: Bool) -> [HexColor] {
        HexColor.oklchStops(from: palette.accent, to: dark ? brandXEnd.dark : brandXEnd.light)
    }
}
