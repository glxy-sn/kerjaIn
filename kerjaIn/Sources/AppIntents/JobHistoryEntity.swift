import AppIntents
import Foundation

struct JobHistoryEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Job Application")
    static var defaultQuery = JobHistoryEntityQuery()

    var id: String
    var company: String
    var position: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(company) – \(position)")
    }
}

struct JobHistoryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [JobHistoryEntity] {
        HistoryRepositoryImpl(dataSource: LocalDataSource())
            .getAll()
            .filter { identifiers.contains($0.id) }
            .map { JobHistoryEntity(id: $0.id, company: $0.company, position: $0.position) }
    }

    func suggestedEntities() async throws -> [JobHistoryEntity] {
        HistoryRepositoryImpl(dataSource: LocalDataSource())
            .getAll()
            .sorted { $0.appliedDate > $1.appliedDate }
            .map { JobHistoryEntity(id: $0.id, company: $0.company, position: $0.position) }
    }
}
