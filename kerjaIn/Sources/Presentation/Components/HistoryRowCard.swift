import SwiftUI

struct HistoryRowCard: View {
    let entry: JobHistory

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(entry.company)
                    .appFont(.subheading)
                Text(entry.position)
                    .appFont(.body)
                    .foregroundStyle(.secondary)
                Text(entry.appliedDate, style: .date)
                    .appFont(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            StatusBadge(status: entry.status)
        }
        .padding(AppSpacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
