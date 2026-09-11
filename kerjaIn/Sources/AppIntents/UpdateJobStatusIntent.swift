import AppIntents

struct UpdateJobStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Job Application Status"
    static var description = IntentDescription(
        "Change the status of an existing job application in kerjaIn.",
        categoryName: "Job Tracking"
    )

    @Parameter(title: "Job Application")
    var job: JobHistoryEntity

    @Parameter(title: "New Status")
    var status: ApplicationStatus

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$job) to \(\.$status)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let repo = HistoryRepositoryImpl(dataSource: LocalDataSource())
        guard var entry = repo.getAll().first(where: { $0.id == job.id }) else {
            throw KerjaInIntentError.notFound
        }
        entry.status = status
        repo.update(entry)
        return .result(value: "Updated \(job.company) – \(job.position) to \(status.rawValue)")
    }
}

enum KerjaInIntentError: Error, LocalizedError {
    case notFound
    var errorDescription: String? {
        switch self {
        case .notFound: return "Job application not found."
        }
    }
}
