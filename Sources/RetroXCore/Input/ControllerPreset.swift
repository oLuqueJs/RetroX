import Foundation

/// Controles físicos, por posição (o GameController nomeia os botões pela posição do layout Xbox).
public enum ControllerControl: String, CaseIterable, Sendable {
    case south, east, west, north
    case leftShoulder, rightShoulder, leftTrigger, rightTrigger
    case menu, options
}

/// Como mostrar e interpretar os botões: glifos de cada família de controle e qual botão confirma.
public enum ControllerPreset: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Usa os glifos do próprio controle conectado; confirma com o botão de baixo.
    case automatic
    case xbox
    /// DualSense e DualShock.
    case playStation
    /// Switch Pro e Joy-Con: confirma com o botão da direita (A).
    case nintendo

    public var id: Self { self }

    public var title: String {
        switch self {
        case .automatic: String(localized: "Automático")
        case .xbox: "Xbox"
        case .playStation: "PlayStation (DualSense)"
        case .nintendo: "Nintendo Switch"
        }
    }

    /// No layout Nintendo, A fica à direita e é o botão de confirmar.
    public var confirmsWithEastButton: Bool {
        self == .nintendo
    }

    /// Símbolo SF do botão nesta família; `nil` no automático (usa o do controle conectado).
    public func glyph(for control: ControllerControl) -> String? {
        switch self {
        case .automatic:
            return nil
        case .xbox:
            return [
                .south: "a.circle", .east: "b.circle", .west: "x.circle", .north: "y.circle",
                .leftShoulder: "lb.rectangle.roundedbottom", .rightShoulder: "rb.rectangle.roundedbottom",
                .leftTrigger: "lt.rectangle.roundedtop", .rightTrigger: "rt.rectangle.roundedtop",
                .menu: "line.3.horizontal.circle", .options: "rectangle.on.rectangle.circle",
            ][control]
        case .playStation:
            return [
                .south: "xmark.circle", .east: "circle.circle", .west: "square.circle", .north: "triangle.circle",
                .leftShoulder: "l1.rectangle.roundedbottom", .rightShoulder: "r1.rectangle.roundedbottom",
                .leftTrigger: "l2.rectangle.roundedtop", .rightTrigger: "r2.rectangle.roundedtop",
                .menu: "line.3.horizontal.circle", .options: "rectangle.on.rectangle.circle",
            ][control]
        case .nintendo:
            return [
                .south: "b.circle", .east: "a.circle", .west: "y.circle", .north: "x.circle",
                .leftShoulder: "l.rectangle.roundedbottom", .rightShoulder: "r.rectangle.roundedbottom",
                .leftTrigger: "zl.rectangle.roundedtop", .rightTrigger: "zr.rectangle.roundedtop",
                .menu: "plus.circle", .options: "minus.circle",
            ][control]
        }
    }

    /// Família do controle conectado, pela categoria que o GameController informa ("DualSense", "Xbox One"…).
    public static func detect(productCategory: String) -> ControllerPreset {
        let category = productCategory.lowercased()
        if category.contains("dualsense") || category.contains("dualshock") || category.contains("playstation") {
            return .playStation
        }
        if category.contains("switch") || category.contains("joy-con") || category.contains("nintendo") {
            return .nintendo
        }
        return .xbox
    }
}
