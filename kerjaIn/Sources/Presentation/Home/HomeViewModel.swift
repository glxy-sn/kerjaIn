import Foundation
import SwiftUI
import Observation

@Observable
final class HomeViewModel {
    var profile: UserProfile = .empty
    var recentHistory: [JobHistory] = []
    private var allHistory: [JobHistory] = []
    var editingEntry: JobHistory? = nil

    private let profileRepository: any ProfileRepository
    private let historyRepository: any HistoryRepository

    init(profileRepository: any ProfileRepository, historyRepository: any HistoryRepository) {
        self.profileRepository = profileRepository
        self.historyRepository = historyRepository
    }

    func load() {
        profile = profileRepository.getProfile()
        allHistory = historyRepository.getAll()
        recentHistory = Array(allHistory.suffix(3).reversed())
    }

    var applications: [JobHistory] { Array(allHistory.reversed()) }

    var appliedCount: Int   { allHistory.count }
    var interviewCount: Int { allHistory.filter { $0.status == .interview }.count }
    var hiredCount: Int     { allHistory.filter { $0.status == .offer || $0.status == .hired }.count }

    func addApplication(_ entry: JobHistory) {
        historyRepository.add(entry)
        load()
    }

    func deleteApplication(id: String) {
        historyRepository.delete(id: id)
        load()
    }

    func updateStatus(id: String, status: ApplicationStatus) {
        guard var entry = allHistory.first(where: { $0.id == id }) else { return }
        entry.status = status
        historyRepository.update(entry)
        load()
    }

    func startEditing(_ entry: JobHistory) {
        editingEntry = entry
    }

    func updateApplication(_ entry: JobHistory) {
        historyRepository.update(entry)
        editingEntry = nil
        load()
    }
}
