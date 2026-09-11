import WidgetKit
import SwiftUI

struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: JobStats
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), stats: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(StatsEntry(date: Date(), stats: widgetStats()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let entry = StatsEntry(date: Date(), stats: widgetStats())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct StatsWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: StatsEntry

    var body: some View {
        switch family {
        case .systemSmall: smallView
        default: mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("kerjaIn")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(entry.stats.total)")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.primary)
            Text("applications")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if entry.stats.interview > 0 {
                HStack(spacing: 5) {
                    Circle().fill(.orange).frame(width: 7, height: 7)
                    Text("\(entry.stats.interview) interviewing")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("kerjaIn")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.stats.total) total")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 0) {
                StatPill(label: "Applied", count: entry.stats.applied, color: .blue)
                StatPill(label: "Interview", count: entry.stats.interview, color: .orange)
                StatPill(label: "Offer", count: entry.stats.offer, color: .green)
                StatPill(label: "Rejected", count: entry.stats.rejected, color: .red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct StatPill: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatsWidget: Widget {
    let kind = "KerjaInStatsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            StatsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Job Stats")
        .description("Overview of your job application statuses.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
