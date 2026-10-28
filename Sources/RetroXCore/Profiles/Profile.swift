import Foundation

/// Um perfil de jogador: nome, foto, tema e o próprio histórico de favoritos e partidas.
public struct Profile: Codable, Identifiable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    /// Nome do arquivo da foto dentro de `Avatars/`.
    public var avatarFile: String?
    public var theme: ThemeID
    /// Acento do tema RetroX; os outros temas têm acento próprio.
    public var accent: Palette.Accent
    public var appearance: AppearancePreference
    public var preferences: ProfilePreferences

    public init(
        id: UUID = UUID(),
        name: String,
        avatarFile: String? = nil,
        theme: ThemeID = .retrox,
        accent: Palette.Accent = .coral,
        appearance: AppearancePreference = .system,
        preferences: ProfilePreferences = ProfilePreferences()
    ) {
        self.id = id
        self.name = name
        self.avatarFile = avatarFile
        self.theme = theme
        self.accent = accent
        self.appearance = appearance
        self.preferences = preferences
    }

    /// Campos novos entram com valor padrão, para arquivos de versões anteriores continuarem abrindo.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarFile = try container.decodeIfPresent(String.self, forKey: .avatarFile)
        theme = (try? container.decodeIfPresent(ThemeID.self, forKey: .theme)) ?? .retrox
        accent = (try? container.decodeIfPresent(Palette.Accent.self, forKey: .accent)) ?? .coral
        appearance = (try? container.decodeIfPresent(AppearancePreference.self, forKey: .appearance)) ?? .system
        preferences = (try? container.decodeIfPresent(ProfilePreferences.self, forKey: .preferences)) ?? ProfilePreferences()
    }

    /// Iniciais para o avatar sem foto: "Ana Souza" → "AS", "Jogador 1" → "J1", "léo" → "L".
    public var initials: String {
        let words = name.split(whereSeparator: \.isWhitespace)
        let letters = words.prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}

public struct ProfilesState: Codable, Sendable, Equatable {
    public var profiles: [Profile]
    public var lastUsedID: UUID?

    public init(profiles: [Profile] = [], lastUsedID: UUID? = nil) {
        self.profiles = profiles
        self.lastUsedID = lastUsedID
    }
}

/// Arquivos dos perfis em `Application Support/RetroX`: `profiles.json`, `Avatars/` e `History/<id>.json`.
public struct ProfileStorage: Sendable {
    public let root: URL

    public init(root: URL = RetroXDirectories.applicationSupport) {
        self.root = root
    }

    public var state: JSONFileStore<ProfilesState> {
        JSONFileStore(url: root.appending(path: "profiles.json"))
    }

    public var avatarsDirectory: URL {
        root.appending(path: "Avatars", directoryHint: .isDirectory)
    }

    public func avatarURL(for profile: Profile) -> URL? {
        profile.avatarFile.map { avatarsDirectory.appending(path: $0) }
    }

    public func history(for profileID: UUID) -> JSONFileStore<[String: GameHistory]> {
        JSONFileStore(url: root.appending(path: "History/\(profileID.uuidString).json"))
    }

    /// Antes dos perfis, o histórico era um arquivo só (`history.json`). Na primeira vez, ele passa a
    /// pertencer ao primeiro perfil, e o arquivo antigo fica guardado como `history.legacy.json`.
    public func migrateLegacyHistory(into profileID: UUID) throws {
        let legacy = root.appending(path: "history.json")
        let destination = history(for: profileID)
        guard FileManager.default.fileExists(atPath: legacy.path(percentEncoded: false)),
              destination.load() == nil
        else { return }
        let entries = JSONFileStore<[String: GameHistory]>(url: legacy).load() ?? [:]
        try destination.save(entries)
        let backup = root.appending(path: "history.legacy.json")
        try? FileManager.default.removeItem(at: backup)
        try FileManager.default.moveItem(at: legacy, to: backup)
    }
}
