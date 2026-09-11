import Foundation

let kerjaInAppGroup = "group.com.tiara.kerjaIn"

struct WidgetJobHistory: Codable {
    var id: String
    var company: String
    var position: String
    var status: String
    var appliedDate: Date
}

struct JobStats {
    var total: Int
    var applied: Int
    var interview: Int
    var offer: Int
    var rejected: Int

    static let placeholder = JobStats(total: 8, applied: 3, interview: 2, offer: 2, rejected: 1)
    static let empty = JobStats(total: 0, applied: 0, interview: 0, offer: 0, rejected: 0)
}

func widgetHistory() -> [WidgetJobHistory] {
    guard let ud = UserDefaults(suiteName: kerjaInAppGroup),
          let data = ud.data(forKey: "jobHistory"),
          let list = try? JSONDecoder().decode([WidgetJobHistory].self, from: data)
    else { return [] }
    return list.sorted { $0.appliedDate > $1.appliedDate }
}

func widgetStats() -> JobStats {
    let h = widgetHistory()
    return JobStats(
        total: h.count,
        applied: h.filter { $0.status == "Applied" }.count,
        interview: h.filter { $0.status == "Interviewing" }.count,
        offer: h.filter { $0.status == "Offer" || $0.status == "Hired" }.count,
        rejected: h.filter { $0.status == "Rejected" }.count
    )
}
