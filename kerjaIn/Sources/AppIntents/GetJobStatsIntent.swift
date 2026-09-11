import AppIntents

struct GetJobStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Job Application Stats"
    static var description = IntentDescription(
        "Return a summary of job application counts by status.",
        categoryName: "Job Tracking"
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let all       = HistoryRepositoryImpl(dataSource: LocalDataSource()).getAll()
        let applied   = all.filter { $0.status == .applied   }.count
        let interview = all.filter { $0.status == .interview }.count
        let offer     = all.filter { $0.status == .offer || $0.status == .hired }.count
        let rejected  = all.filter { $0.status == .rejected  }.count

        let summary = "Total: \(all.count) · Applied: \(applied) · Interviewing: \(interview) · Offer/Hired: \(offer) · Rejected: \(rejected)"
        return .result(value: summary)
    }
}
