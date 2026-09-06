import SwiftUI

struct JobDetailView: View {
    let entry: JobHistory
    let onUpdate: (JobHistory) -> Void
    let onDelete: () -> Void

    @State private var showingEdit = false
    @Environment(\.dismiss) private var dismiss

    private var logoColor: Color {
        let palette: [Color] = [.statusApplied, Color(hex: "111111"), Color(hex: "1db954"),
                                Color(hex: "635bff"), Color(hex: "e67e22"), Color(hex: "e91e63")]
        return palette[abs(entry.company.hashValue) % palette.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header card
                HStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(logoColor)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(String(entry.company.prefix(2)).uppercased())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.position)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                        Text(entry.location.isEmpty ? entry.company : "\(entry.company) · \(entry.location)")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Spacer()
                    StatusBadge(status: entry.status)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 1)
                .shadow(color: .black.opacity(0.05), radius: 20, y: 6)

                // Application details
                DetailCard(title: "Application Info") {
                    DetailRow(label: "Applied",  value: entry.appliedDate.formatted(date: .long, time: .omitted))
                    DetailRow(label: "Status",   value: entry.status.rawValue)
                    DetailRow(label: "Company",  value: entry.company)
                    if !entry.location.isEmpty {
                        DetailRow(label: "Location", value: entry.location)
                    }
                    DetailRow(label: "Role",     value: entry.position)
                }

                // Notes / Job description
                if !entry.notes.isEmpty {
                    DetailCard(title: "Job Description / Notes") {
                        Text(entry.notes)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkSecondary)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground)
        .navigationTitle(entry.position)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddHistorySheet(editing: entry, onSave: onUpdate)
        }
    }
}

private struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.05), radius: 20, y: 6)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.inkTertiary)
                .frame(width: 75, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lightSeparator).frame(height: 1)
        }
    }
}
