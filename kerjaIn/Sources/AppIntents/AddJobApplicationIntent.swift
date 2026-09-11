import AppIntents
import Foundation

struct AddJobApplicationIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Job Application"
    static var description = IntentDescription(
        "Add a new job application to kerjaIn.",
        categoryName: "Job Tracking"
    )

    @Parameter(title: "Company")
    var company: String

    @Parameter(title: "Position / Role")
    var position: String

    @Parameter(title: "Location")
    var location: String?

    @Parameter(title: "Status")
    var status: ApplicationStatus?

    @Parameter(title: "Job Description", requestValueDialog: "What's the job description? (optional — leave blank to skip)")
    var jobDescription: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$position) at \(\.$company) — \(\.$jobDescription)") {
            \.$location
            \.$status
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let entry = JobHistory(
            id: UUID().uuidString,
            company: company,
            position: position,
            location: location ?? "",
            appliedDate: Date(),
            status: status ?? .applied,
            notes: jobDescription ?? ""
        )
        HistoryRepositoryImpl(dataSource: LocalDataSource()).add(entry)
        return .result(value: "Added \(position) at \(company)")
    }
}
