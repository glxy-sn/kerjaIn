import Foundation

final class LocalDataSource {
    private let defaults = UserDefaults.standard
    private let profileKey = "userProfile"
    private let cvKey = "cvData"
    private let historyKey = "jobHistory"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadProfile() -> UserProfile {
        guard let data = defaults.data(forKey: profileKey),
              let profile = try? decoder.decode(UserProfile.self, from: data) else {
            return .empty
        }
        return profile
    }

    func saveProfile(_ profile: UserProfile) {
        guard let data = try? encoder.encode(profile) else { return }
        defaults.set(data, forKey: profileKey)
    }

    func loadCVData() -> CVData {
        guard let data = defaults.data(forKey: cvKey),
              let cv = try? decoder.decode(CVData.self, from: data) else {
            return .empty
        }
        return cv
    }

    func saveCVData(_ cv: CVData) {
        guard let data = try? encoder.encode(cv) else { return }
        defaults.set(data, forKey: cvKey)
    }

    func loadHistory() -> [JobHistory] {
        guard let data = defaults.data(forKey: historyKey),
              let history = try? decoder.decode([JobHistory].self, from: data) else {
            return []
        }
        return history
    }

    func saveHistory(_ history: [JobHistory]) {
        guard let data = try? encoder.encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }
}
