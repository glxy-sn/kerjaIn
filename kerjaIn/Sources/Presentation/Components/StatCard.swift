import SwiftUI

struct StatCard: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("\(value)")
                .appFont(.heading)
                .foregroundStyle(color)
            Text(title)
                .appFont(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
