import AppIntents

extension ApplicationStatus: AppEnum {
    public nonisolated(unsafe) static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Application Status")
    public nonisolated(unsafe) static let caseDisplayRepresentations: [ApplicationStatus: DisplayRepresentation] = [
        .applied:   DisplayRepresentation(title: "Applied"),
        .interview: DisplayRepresentation(title: "Interviewing"),
        .offer:     DisplayRepresentation(title: "Offer"),
        .hired:     DisplayRepresentation(title: "Hired"),
        .rejected:  DisplayRepresentation(title: "Rejected"),
        .closed:    DisplayRepresentation(title: "Closed")
    ]
}
