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

    // MARK: - Small

    private var smallView: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("kerjaIn")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(entry.stats.total)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.primary)
                Text("applications")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Image("computer")
                .resizable()
                .scaledToFit()
                .frame(width: 52)
                .offset(x: 6, y: 6)
        }
    }

    // MARK: - Medium

    private var mediumView: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text("kerjaIn")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(entry.stats.total) total")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, 14)

                // Stats row
                HStack(spacing: 0) {
                    StatItem(
                        icon: "document.on.document.fill",
                        label: "Applied",
                        count: entry.stats.applied
                    )
                    StatItem(
                        icon: "person.fill",
                        label: "Interview",
                        count: entry.stats.interview
                    )
                    StatItem(
                        icon: "briefcase.fill",
                        label: "Offer",
                        count: entry.stats.offer
                    )
                    StatItem(
                        icon: "x.circle.fill",
                        label: "Rejected",
                        count: entry.stats.rejected
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Mascot peeking from bottom-right
            Image("computer")
                .resizable()
                .scaledToFit()
                .frame(width: 72)
                .offset(x: 8, y: 8)
        }
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let icon: String
    let label: String
    let count: Int

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
            Text("\(count)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget

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
