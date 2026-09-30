import Foundation
import WidgetKit

final class LocalDataSource {
    private let defaults: UserDefaults = {
        let group = UserDefaults(suiteName: "group.com.tiara.kerjaIn") ?? .standard
        // One-time migration: copy existing data from .standard into the App Group
        if group.data(forKey: "jobHistory") == nil,
           let legacy = UserDefaults.standard.data(forKey: "jobHistory") {
            group.set(legacy, forKey: "jobHistory")
        }
        if group.data(forKey: "userProfile") == nil,
           let legacy = UserDefaults.standard.data(forKey: "userProfile") {
            group.set(legacy, forKey: "userProfile")
        }
        group.synchronize()
        DispatchQueue.main.async { WidgetCenter.shared.reloadAllTimelines() }
        return group
    }()
    private let profileKey    = "userProfile"
    private let cvKey         = "cvData"
    private let historyKey    = "jobHistory"
    private let cvHistoryKey  = "generatedCVHistory"
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
        defaults.synchronize()
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func getGeneratedCVs() -> [GeneratedCV] {
        guard let data = defaults.data(forKey: cvHistoryKey),
              let list = try? decoder.decode([GeneratedCV].self, from: data)
        else { return [] }
        return list
    }

    func saveGeneratedCV(_ cv: GeneratedCV) {
        var list = getGeneratedCVs()
        if let idx = list.firstIndex(where: { $0.id == cv.id }) {
            list[idx] = cv
        } else {
            list.insert(cv, at: 0)
            if list.count > 30 { list = Array(list.prefix(30)) }
        }
        if let data = try? encoder.encode(list) {
            defaults.set(data, forKey: cvHistoryKey)
        }
    }

    func deleteGeneratedCV(id: String) {
        var list = getGeneratedCVs()
        list.removeAll { $0.id == id }
        if let data = try? encoder.encode(list) {
            defaults.set(data, forKey: cvHistoryKey)
        }
    }
}
