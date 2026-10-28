import Foundation
import Testing
@testable import RetroXCore

struct PreferencesTests {
    @Test("Perfil antigo (sem preferências) abre com os padrões")
    func olderProfileDecodes() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Ana","theme":"nord","retroAchievementsUsername":"x"}"#
        let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
        #expect(profile.theme == .nord)
        #expect(profile.preferences == ProfilePreferences())
    }

    @Test("Preferências parciais mantêm o resto no padrão")
    func partialPreferences() throws {
        let json = #"{"homeStyle":"carousel","textSize":"large","valorDesconhecido":true}"#
        let preferences = try JSONDecoder().decode(ProfilePreferences.self, from: Data(json.utf8))
        #expect(preferences.homeStyle == .carousel)
        #expect(preferences.textSize == .large)
        #expect(preferences.fontStyle == .rounded)
        #expect(preferences.ambientBackground)
    }

    @Test("Ida e volta em JSON")
    func roundTrip() throws {
        var profile = Profile(name: "Bia")
        profile.preferences.fontStyle = .serif
        profile.preferences.animationLevel = .reduced
        let decoded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        #expect(decoded == profile)
    }
}

struct ControllerPresetTests {
    @Test("Presets fixos têm glifo para todos os botões", arguments: [ControllerPreset.xbox, .playStation, .nintendo])
    func glyphs(preset: ControllerPreset) {
        for control in ControllerControl.allCases {
            #expect(preset.glyph(for: control) != nil, "\(preset) \(control)")
        }
    }

    @Test("Só o layout Nintendo confirma com o botão da direita")
    func confirmButton() {
        #expect(ControllerPreset.nintendo.confirmsWithEastButton)
        #expect(!ControllerPreset.xbox.confirmsWithEastButton)
        #expect(!ControllerPreset.playStation.confirmsWithEastButton)
        #expect(ControllerPreset.nintendo.glyph(for: .east) == "a.circle")
        #expect(ControllerPreset.playStation.glyph(for: .south) == "xmark.circle")
    }

    @Test("Detecta a família pelo nome da categoria", arguments: [
        ("DualSense", ControllerPreset.playStation), ("DualShock 4", .playStation),
        ("Xbox One", .xbox), ("Xbox Series X", .xbox), ("Switch Pro Controller", .nintendo),
        ("Nintendo Switch Joy-Con (L/R)", .nintendo), ("8BitDo", .xbox),
    ])
    func detects(category: String, expected: ControllerPreset) {
        #expect(ControllerPreset.detect(productCategory: category) == expected)
    }
}
