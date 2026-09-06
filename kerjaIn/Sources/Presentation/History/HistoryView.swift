import SwiftUI

struct HistoryView: View {
    var viewModel: HistoryViewModel

    private let filters: [(label: String, status: ApplicationStatus?)] = [
        ("All", nil),
        ("Applied", .applied),
        ("Interview", .interview),
        ("Offer", .offer),
        ("Rejected", .rejected),
    ]

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Filter tabs
                HStack(spacing: 4) {
                    ForEach(filters, id: \.label) { f in
                        Button(f.label) {
                            viewModel.filterStatus = f.status
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(
                            viewModel.filterStatus == f.status ? Color.inkPrimary : Color.inkSecondary
                        )
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background {
                            if viewModel.filterStatus == f.status {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Timeline
                if viewModel.groupedEntries.isEmpty {
                    ContentUnavailableView(
                        "No Activity",
                        systemImage: "clock",
                        description: Text("Add an application to start tracking.")
                    )
                    .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.groupedEntries) { group in
                            Text(group.day)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.inkTertiary)
                                .tracking(2)
                                .padding(.bottom, 12)
                                .padding(.top, group.id == viewModel.groupedEntries.first?.id ? 0 : 14)

                            ForEach(group.entries) { entry in
                                TimelineItemRow(entry: entry)
                            }
                        }
                    }
                    .padding(.leading, 26)
                    .overlay(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color.appSeparator)
                            .frame(width: 2)
                            .padding(.leading, 7)
                            .padding(.top, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground)
        .navigationTitle("History")
        .searchable(text: $viewModel.searchQuery, placement: .toolbar, prompt: "Search applications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddHistorySheet { viewModel.add($0) }
        }
        .onAppear { viewModel.load() }
    }
}

private struct TimelineItemRow: View {
    let entry: JobHistory

    private var nodeColor: Color {
        switch entry.status {
        case .applied:             return .statusApplied
        case .interview:           return .statusInterview
        case .offer, .hired:       return .statusOffer
        case .rejected:            return .statusRejected
        case .closed:              return .statusClosed
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(nodeColor)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .offset(x: -20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.appliedDate, style: .time)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
                Text("Applied — \(entry.position) at \(entry.company)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 8) {
                    StatusBadge(status: entry.status)
                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.bottom, 20)
        }
        .offset(x: -7)
    }
}
