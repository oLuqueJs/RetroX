import AppKit
import Observation
import RetroXCore

/// Perfis de jogador: quem está jogando, a foto, o tema e o histórico de cada um.
@MainActor
@Observable
final class ProfilesModel {
    private(set) var profiles: [Profile]
    private(set) var current: Profile?
    /// Muda quando uma foto é trocada, para as views recarregarem a imagem do mesmo caminho.
    private(set) var avatarRevision = 0

    @ObservationIgnored let storage: ProfileStorage
    @ObservationIgnored private var lastUsedID: UUID?

    init(storage: ProfileStorage = ProfileStorage()) {
        self.storage = storage
        let state = storage.state.load() ?? ProfilesState()
        profiles = state.profiles
        lastUsedID = state.lastUsedID
        if profiles.isEmpty { createFirstProfile() }
    }

    var lastUsed: Profile? {
        profiles.first { $0.id == lastUsedID } ?? profiles.first
    }

    func avatarURL(for profile: Profile) -> URL? {
        storage.avatarURL(for: profile)
    }

    func select(_ profile: Profile) {
        current = profile
        lastUsedID = profile.id
        save()
    }

    @discardableResult
    func create(name: String) -> Profile {
        let profile = Profile(name: name.isEmpty ? String(localized: "Jogador \(profiles.count + 1)") : name)
        profiles.append(profile)
        save()
        return profile
    }

    func update(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        if current?.id == profile.id { current = profile }
        save()
    }

    /// Apaga o perfil e o histórico dele. Os jogos e as pastas dos emuladores não são tocados.
    func delete(_ profile: Profile) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == profile.id }
        try? FileManager.default.removeItem(at: storage.history(for: profile.id).url)
        if let avatar = storage.avatarURL(for: profile) { try? FileManager.default.removeItem(at: avatar) }
        if current?.id == profile.id { current = nil }
        if lastUsedID == profile.id { lastUsedID = profiles.first?.id }
        save()
    }

    /// Copia a foto escolhida (reduzida) para dentro do RetroX.
    func setAvatar(for profile: Profile, from source: URL) throws {
        var updated = profile
        let name = "\(profile.id.uuidString).png"
        try ImageImporter.importPNG(from: source, to: storage.avatarsDirectory.appending(path: name), maxPixelSize: 512)
        updated.avatarFile = name
        update(updated)
        avatarRevision += 1
    }

    func removeAvatar(for profile: Profile) {
        guard let url = storage.avatarURL(for: profile) else { return }
        try? FileManager.default.removeItem(at: url)
        var updated = profile
        updated.avatarFile = nil
        update(updated)
        avatarRevision += 1
    }

    /// Primeiro uso dos perfis: aproveita o tema escolhido antes nos Ajustes e o histórico que já existia.
    private func createFirstProfile() {
        let defaults = UserDefaults.standard
        let fullName = NSFullUserName().split(separator: " ").first.map(String.init)
        var profile = Profile(name: fullName ?? String(localized: "Jogador 1"))
        if let accent = defaults.string(forKey: "accent").flatMap(Palette.Accent.init(rawValue:)) { profile.accent = accent }
        if let appearance = defaults.string(forKey: "appearance").flatMap(AppearancePreference.init(rawValue:)) {
            profile.appearance = appearance
        }
        profiles = [profile]
        lastUsedID = profile.id
        try? storage.migrateLegacyHistory(into: profile.id)
        save()
    }

    private func save() {
        try? storage.state.save(ProfilesState(profiles: profiles, lastUsedID: lastUsedID))
    }
}
