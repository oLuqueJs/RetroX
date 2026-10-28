import Testing
@testable import RetroXCore

private let allPalettes: [(String, ThemePalette)] = ThemeID.allCases.flatMap { theme in
    [false, true].flatMap { dark in
        let accents: [Palette.Accent] = theme == .retrox ? Palette.Accent.allCases : [.coral]
        return accents.map { accent in
            ("\(theme.title) \(theme.variantName(dark: dark)) \(theme == .retrox ? accent.rawValue : "")", theme.palette(dark: dark, retroXAccent: accent))
        }
    }
}

struct ThemeTests {
    @Test("Há pelo menos 10 temas, cada um com claro e escuro")
    func count() {
        #expect(ThemeID.allCases.count >= 10)
    }

    @Test("Contraste AA em todos os temas e modos", arguments: allPalettes)
    func contrast(name: String, palette: ThemePalette) {
        for background in [palette.background, palette.surface, palette.raised] {
            #expect(HexColor.contrast(palette.textPrimary, background) >= 4.5, "\(name): texto")
            #expect(HexColor.contrast(palette.textSecondary, background) >= 4.5, "\(name): texto secundário")
        }
        #expect(HexColor.contrast(palette.onAccent, palette.accent) >= 4.5, "\(name): texto sobre o acento")
        #expect(HexColor.contrast(palette.accent, palette.background) >= 3, "\(name): anel sobre o fundo")
        #expect(HexColor.contrast(palette.accent, palette.surface) >= 3, "\(name): anel sobre a superfície")
    }

    @Test("Texto principal se destaca mais que o secundário", arguments: allPalettes)
    func hierarchy(name: String, palette: ThemePalette) {
        #expect(
            HexColor.contrast(palette.textPrimary, palette.background) > HexColor.contrast(palette.textSecondary, palette.background),
            "\(name)"
        )
    }

    @Test("Capas geradas legíveis para todos os sistemas do catálogo", arguments: SystemCatalog.all.map(\.id))
    func coverTones(system: GameSystemID) {
        #expect(HexColor.contrast(Palette.onCover.light, Palette.coverTone(for: system).light) >= 4.5)
    }
}
