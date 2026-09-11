import WidgetKit
import SwiftUI

struct RecentEntry: TimelineEntry {
    let date: Date
    let jobs: [WidgetJobHistory]
}

struct RecentProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: Date(), jobs: [
            WidgetJobHistory(id: "1", company: "Apple Inc", position: "iOS Engineer", status: "Interviewing", appliedDate: Date()),
            WidgetJobHistory(id: "2", company: "Google", position: "SWE Intern", status: "Applied", appliedDate: Date()),
            WidgetJobHistory(id: "3", company: "Meta", position: "Android Dev", status: "Rejected", appliedDate: Date()),
        ])
    }
    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        completion(RecentEntry(date: Date(), jobs: Array(widgetHistory().prefix(5))))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        let entry = RecentEntry(date: Date(), jobs: Array(widgetHistory().prefix(5)))
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct RecentAppsWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: RecentEntry

    private var maxItems: Int { family == .systemLarge ? 5 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Applications")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)

            if entry.jobs.isEmpty {
                Spacer()
                Text("No applications yet.\nAdd one in kerjaIn.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                let displayed = Array(entry.jobs.prefix(maxItems))
                ForEach(Array(displayed.enumerated()), id: \.element.id) { index, job in
                    JobRowView(job: job)
                    if index < displayed.count - 1 {
                        Divider().padding(.vertical, 6)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct JobRowView: View {
    let job: WidgetJobHistory

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(job.position)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(job.company)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            StatusChip(status: job.status)
        }
    }
}

private struct StatusChip: View {
    let status: String

    private var color: Color {
        switch status {
        case "Applied":            return .blue
        case "Interviewing":       return .orange
        case "Offer", "Hired":     return .green
        case "Rejected":           return .red
        default:                   return .gray
        }
    }

    private var label: String {
        status == "Interviewing" ? "Interview" : status
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct RecentAppsWidget: Widget {
    let kind = "KerjaInRecentWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentProvider()) { entry in
            RecentAppsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Recent Applications")
        .description("Your latest job applications at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
