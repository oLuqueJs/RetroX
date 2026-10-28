import Foundation

/// O que cada perfil personaliza além do tema: tela inicial, texto e movimento.
/// Campos novos entram com valor padrão, para arquivos antigos continuarem abrindo.
public struct ProfilePreferences: Codable, Sendable, Equatable, Hashable {
    public enum HomeStyle: String, Codable, CaseIterable, Sendable, Identifiable {
        /// Palco com o jogo em foco e prateleira embaixo.
        case shelf
        /// Capas grandes no centro, vizinhas inclinadas dos lados.
        case carousel
        /// Grade de capas com o jogo em foco no topo.
        case grid

        public var id: Self { self }

        public var title: String {
            switch self {
            case .shelf: String(localized: "Prateleira")
            case .carousel: String(localized: "Carrossel")
            case .grid: String(localized: "Grade")
            }
        }
    }

    public enum TileSize: String, Codable, CaseIterable, Sendable, Identifiable {
        case small, medium, large

        public var id: Self { self }

        public var title: String {
            switch self {
            case .small: String(localized: "Pequenas")
            case .medium: String(localized: "Médias")
            case .large: String(localized: "Grandes")
            }
        }

        public var scale: Double {
            switch self {
            case .small: 0.8
            case .medium: 1
            case .large: 1.25
            }
        }
    }

    public enum StartShelf: String, Codable, CaseIterable, Sendable, Identifiable {
        /// Recentes quando houver; senão, Todos.
        case automatic, recent, all, favorites

        public var id: Self { self }

        public var title: String {
            switch self {
            case .automatic: String(localized: "Automática")
            case .recent: String(localized: "Recentes")
            case .all: String(localized: "Todos")
            case .favorites: String(localized: "Favoritos")
            }
        }
    }

    public enum FontStyle: String, Codable, CaseIterable, Sendable, Identifiable {
        case rounded, standard, serif, mono

        public var id: Self { self }

        public var title: String {
            switch self {
            case .rounded: String(localized: "Arredondada")
            case .standard: String(localized: "Padrão")
            case .serif: String(localized: "Serifada")
            case .mono: String(localized: "Monoespaçada")
            }
        }
    }

    public enum TextSize: String, Codable, CaseIterable, Sendable, Identifiable {
        case small, standard, large, extraLarge

        public var id: Self { self }

        public var title: String {
            switch self {
            case .small: String(localized: "Pequeno")
            case .standard: String(localized: "Padrão")
            case .large: String(localized: "Grande")
            case .extraLarge: String(localized: "Extra grande")
            }
        }

        public var scale: Double {
            switch self {
            case .small: 0.9
            case .standard: 1
            case .large: 1.12
            case .extraLarge: 1.25
            }
        }
    }

    public enum AnimationLevel: String, Codable, CaseIterable, Sendable, Identifiable {
        /// Tudo: elevação, deslizes, carrossel inclinado, fundo ambiente se movendo.
        case full
        /// Só esmaecimentos e trocas curtas (como o Reduzir Movimento do macOS).
        case reduced
        /// Sem animação.
        case off

        public var id: Self { self }

        public var title: String {
            switch self {
            case .full: String(localized: "Completas")
            case .reduced: String(localized: "Reduzidas")
            case .off: String(localized: "Desligadas")
            }
        }
    }

    public enum AnimationSpeed: String, Codable, CaseIterable, Sendable, Identifiable {
        case calm, normal, fast

        public var id: Self { self }

        public var title: String {
            switch self {
            case .calm: String(localized: "Calma")
            case .normal: String(localized: "Normal")
            case .fast: String(localized: "Rápida")
            }
        }

        /// Multiplica as durações: maior é mais lento.
        public var durationFactor: Double {
            switch self {
            case .calm: 1.35
            case .normal: 1
            case .fast: 0.7
            }
        }
    }

    public var homeStyle: HomeStyle = .shelf
    public var tileSize: TileSize = .medium
    public var startShelf: StartShelf = .automatic
    public var fontStyle: FontStyle = .rounded
    public var textSize: TextSize = .standard
    /// Capa do jogo em foco, desfocada, atrás da tela.
    public var ambientBackground = true
    public var animationLevel: AnimationLevel = .full
    public var animationSpeed: AnimationSpeed = .normal
    public var startupAnimation = true
    public var showsFavoriteBadge = true
    public var showsClock = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ProfilePreferences()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        homeStyle = value(.homeStyle, defaults.homeStyle)
        tileSize = value(.tileSize, defaults.tileSize)
        startShelf = value(.startShelf, defaults.startShelf)
        fontStyle = value(.fontStyle, defaults.fontStyle)
        textSize = value(.textSize, defaults.textSize)
        ambientBackground = value(.ambientBackground, defaults.ambientBackground)
        animationLevel = value(.animationLevel, defaults.animationLevel)
        animationSpeed = value(.animationSpeed, defaults.animationSpeed)
        startupAnimation = value(.startupAnimation, defaults.startupAnimation)
        showsFavoriteBadge = value(.showsFavoriteBadge, defaults.showsFavoriteBadge)
        showsClock = value(.showsClock, defaults.showsClock)
    }
}
