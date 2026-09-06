import Foundation
import SwiftUI
import Observation

struct DayGroup: Identifiable {
    let day: String
    var entries: [JobHistory]
    var id: String { day }
}

@Observable
final class HistoryViewModel {
    var entries: [JobHistory] = []
    var showingAddSheet = false
    var filterStatus: ApplicationStatus? = nil
    var searchQuery: String = ""

    private let repository: any HistoryRepository

    init(repository: any HistoryRepository) {
        self.repository = repository
    }

    func load() {
        entries = Array(repository.getAll().reversed())
    }

    var filteredEntries: [JobHistory] {
        var result = filterStatus.map { f in entries.filter { $0.status == f } } ?? entries
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.company.localizedCaseInsensitiveContains(searchQuery) ||
                $0.position.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        return result
    }

    var groupedEntries: [DayGroup] {
        var groups: [DayGroup] = []
        for entry in filteredEntries {
            let day = entry.appliedDate.dayLabel
            if groups.last?.day == day {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append(DayGroup(day: day, entries: [entry]))
            }
        }
        return groups
    }

    func add(_ entry: JobHistory) {
        repository.add(entry)
        load()
    }

    func update(_ entry: JobHistory) {
        repository.update(entry)
        load()
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.map { entries[$0].id }
        ids.forEach { repository.delete(id: $0) }
        load()
    }
}

private extension Date {
    var dayLabel: String {
        if Calendar.current.isDateInToday(self)     { return "Today" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        return self.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
