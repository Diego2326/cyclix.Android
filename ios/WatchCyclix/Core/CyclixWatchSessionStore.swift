import Foundation

final class CyclixWatchSessionStore {
    private enum Keys {
        static let token = "cyclix.watch.token"
        static let email = "cyclix.watch.email"
        static let profile = "cyclix.watch.profile"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var token: String? {
        defaults.string(forKey: Keys.token)
    }

    var email: String? {
        defaults.string(forKey: Keys.email)
    }

    var profile: CyclixUserProfile? {
        guard let data = defaults.data(forKey: Keys.profile),
              let object = try? JSONSerialization.jsonObject(with: data),
              let json = cyclixMap(object)
        else {
            return nil
        }
        return CyclixUserProfile(json: json)
    }

    var hasSession: Bool {
        guard let token, !token.isEmpty else { return false }
        return true
    }

    func save(token: String, email: String, profile: CyclixUserProfile?) {
        defaults.set(token, forKey: Keys.token)
        defaults.set(email, forKey: Keys.email)

        if let profile,
           let data = try? JSONSerialization.data(withJSONObject: profile.storageDictionary, options: []) {
            defaults.set(data, forKey: Keys.profile)
        } else {
            defaults.removeObject(forKey: Keys.profile)
        }
    }

    func save(profile: CyclixUserProfile?) {
        if let profile,
           let data = try? JSONSerialization.data(withJSONObject: profile.storageDictionary, options: []) {
            defaults.set(data, forKey: Keys.profile)
        } else {
            defaults.removeObject(forKey: Keys.profile)
        }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.token)
        defaults.removeObject(forKey: Keys.email)
        defaults.removeObject(forKey: Keys.profile)
    }
}
