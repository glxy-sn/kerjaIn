import Foundation

struct JobHistory: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var company: String
    var position: String
    var location: String
    var appliedDate: Date
    var status: ApplicationStatus
    var notes: String

    init(id: String, company: String, position: String, location: String = "",
         appliedDate: Date, status: ApplicationStatus, notes: String) {
        self.id = id
        self.company = company
        self.position = position
        self.location = location
        self.appliedDate = appliedDate
        self.status = status
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        company = try c.decode(String.self, forKey: .company)
        position = try c.decode(String.self, forKey: .position)
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        appliedDate = try c.decode(Date.self, forKey: .appliedDate)
        status = try c.decode(ApplicationStatus.self, forKey: .status)
        notes = try c.decode(String.self, forKey: .notes)
    }
}

enum ApplicationStatus: String, Codable, CaseIterable {
    case applied   = "Applied"
    case interview = "Interviewing"
    case offer     = "Offer"
    case hired     = "Hired"
    case rejected  = "Rejected"
    case closed    = "Closed"
}
