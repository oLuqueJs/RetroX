import Foundation

/// Um conjunto completo de cores para um modo (claro ou escuro).
public struct ThemePalette: Sendable, Equatable {
    public let background: HexColor
    public let surface: HexColor
    public let raised: HexColor
    public let textPrimary: HexColor
    public let textSecondary: HexColor
    public let divider: HexColor
    public let accent: HexColor
    public let onAccent: HexColor

    /// Ordem: fundo, superfície, elevado, texto, texto secundário, divisória, acento, texto sobre o acento.
    init(_ hex: [String]) {
        precondition(hex.count == 8)
        background = HexColor(hex[0])
        surface = HexColor(hex[1])
        raised = HexColor(hex[2])
        textPrimary = HexColor(hex[3])
        textSecondary = HexColor(hex[4])
        divider = HexColor(hex[5])
        accent = HexColor(hex[6])
        onAccent = HexColor(hex[7])
    }
}

public enum AppearancePreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case system, light, dark

    public var id: Self { self }

    public var title: String {
        switch self {
        case .system: String(localized: "Sistema")
        case .light: String(localized: "Claro")
        case .dark: String(localized: "Escuro")
        }
    }
}

/// Temas de cor. RetroX e Rayo Paradise são próprios; os esquemas conhecidos usam as cores oficiais de cada projeto, com ajustes mínimos
/// onde a cor original não atingia o contraste AA (texto ≥ 4,5:1, anel de foco ≥ 3:1). `PaletteTests` confere.
public enum ThemeID: String, CaseIterable, Codable, Sendable, Identifiable {
    case retrox, rayoParadise, gruvbox, catppuccin, tokyoNight, nord, solarized, dracula, rosePine, everforest, kanagawa, one

    public var id: Self { self }

    public var title: String {
        switch self {
        case .retrox: "RetroX"
        case .rayoParadise: "Rayo Paradise"
        case .gruvbox: "Gruvbox"
        case .catppuccin: "Catppuccin"
        case .tokyoNight: "Tokyo Night"
        case .nord: "Nord"
        case .solarized: "Solarized"
        case .dracula: "Dracula"
        case .rosePine: "Rosé Pine"
        case .everforest: "Everforest"
        case .kanagawa: "Kanagawa"
        case .one: "One"
        }
    }

    /// Nome de cada variante, como o próprio esquema chama.
    public func variantName(dark: Bool) -> String {
        switch self {
        case .catppuccin: dark ? "Mocha" : "Latte"
        case .tokyoNight: dark ? "Night" : "Day"
        case .rosePine: dark ? "Main" : "Dawn"
        case .kanagawa: dark ? "Wave" : "Lotus"
        case .dracula: dark ? "Dracula" : "Alucard"
        default: dark ? String(localized: "Escuro") : String(localized: "Claro")
        }
    }

    /// `retroXAccent` só vale para o tema RetroX; os outros esquemas têm acento próprio.
    public func palette(dark: Bool, retroXAccent: Palette.Accent = .coral) -> ThemePalette {
        switch self {
        case .retrox:
            let pick = { (tone: Tone) in Self.hex(dark ? tone.dark : tone.light) }
            return ThemePalette([
                pick(Palette.background), pick(Palette.surface), pick(Palette.raised), pick(Palette.textPrimary),
                pick(Palette.textSecondary), pick(Palette.divider), pick(retroXAccent.fill), pick(retroXAccent.onFill),
            ])
        case .rayoParadise:
            // Cores da Rayo (docs/design/logo/README.md): noite em índigo com o rosa do cabelo; dia no céu do
            // fundo do tile com a framboesa do X.
            return dark
                ? ThemePalette(["191A2E", "22233B", "2C2D4A", "F6ECF0", "B9B6DA", "3A3B5C", "FEB5B8", "191A2E"])
                : ThemePalette(["EDF3FF", "F8FAFF", "DDE6FA", "1E1E3A", "4E5175", "CDD8F0", "D63A62", "FFFFFF"])
        case .gruvbox:
            return dark
                ? ThemePalette(["282828", "32302F", "3C3836", "EBDBB2", "BDAE93", "504945", "FE8019", "282828"])
                : ThemePalette(["FBF1C7", "F9F5D7", "EBDBB2", "3C3836", "665C54", "D5C4A1", "AF3A03", "FBF1C7"])
        case .catppuccin:
            return dark
                ? ThemePalette(["1E1E2E", "313244", "45475A", "CDD6F4", "B2B8D0", "585B70", "CBA6F7", "1E1E2E"])
                : ThemePalette(["E6E9EF", "EFF1F5", "CCD0DA", "3A3D56", "545768", "BCC0CC", "8839EF", "EFF1F5"])
        case .tokyoNight:
            return dark
                ? ThemePalette(["1A1B26", "24283B", "292E42", "C0CAF5", "A9B1D6", "3B4261", "7AA2F7", "1A1B26"])
                : ThemePalette(["E1E2E7", "EEEFF3", "D0D5E3", "2A4A94", "4C5989", "C4C8DA", "2A73D6", "FFFFFF"])
        case .nord:
            return dark
                ? ThemePalette(["2E3440", "3B4252", "434C5E", "ECEFF4", "D8DEE9", "4C566A", "88C0D0", "2E3440"])
                : ThemePalette(["E5E9F0", "ECEFF4", "D8DEE9", "2E3440", "4C566A", "C9D0DC", "4F6C90", "ECEFF4"])
        case .solarized:
            return dark
                ? ThemePalette(["002B36", "073642", "0B404D", "EEE8D5", "9CA9AB", "1E4C57", "B58900", "002B36"])
                : ThemePalette(["FDF6E3", "FFFBEF", "EEE8D5", "073642", "576A71", "E2DBC5", "BF4615", "FDF6E3"])
        case .dracula:
            return dark
                ? ThemePalette(["282A36", "343746", "44475A", "F8F8F2", "BFC3D9", "4D5066", "BD93F9", "282A36"])
                : ThemePalette(["FFFBEB", "FFFFFF", "EFEDDC", "1F1F1F", "635D97", "DCD9C6", "644AC9", "FFFBEB"])
        case .rosePine:
            return dark
                ? ThemePalette(["191724", "1F1D2E", "26233A", "E0DEF4", "908CAA", "403D52", "EBBCBA", "191724"])
                : ThemePalette(["FAF4ED", "FFFAF3", "F2E9E1", "575279", "68657E", "DFDAD9", "286983", "FAF4ED"])
        case .everforest:
            return dark
                ? ThemePalette(["2D353B", "343F44", "3D484D", "D3C6AA", "AFB8B1", "475258", "A7C080", "2D353B"])
                : ThemePalette(["F4F0D9", "FDF6E3", "E6E2CC", "3C474D", "57646B", "E0DCC7", "687701", "FDF6E3"])
        case .kanagawa:
            return dark
                ? ThemePalette(["1F1F28", "2A2A37", "363646", "DCD7BA", "C8C093", "54546D", "7E9CD8", "1F1F28"])
                : ThemePalette(["F2ECBC", "F5F0C8", "E5DDB0", "545464", "5D5D6C", "D5CEA3", "4B6798", "F2ECBC"])
        case .one:
            return dark
                ? ThemePalette(["282C34", "2C313A", "3E4451", "DCDFE4", "ADB4C0", "4B5263", "61AFEF", "282C34"])
                : ThemePalette(["FAFAFA", "FFFFFF", "EAEAEB", "383A42", "656872", "DBDBDC", "3B6EDF", "FFFFFF"])
        }
    }

    private static func hex(_ color: HexColor) -> String {
        String(format: "%02X%02X%02X", Int((color.red * 255).rounded()), Int((color.green * 255).rounded()), Int((color.blue * 255).rounded()))
    }
}
