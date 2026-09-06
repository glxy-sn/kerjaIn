import SwiftUI

struct HomeView: View {
    var viewModel: HomeViewModel
    @State private var searchText = ""
    @State private var showingAdd = false
    @Environment(Router.self) private var router

    private var filtered: [JobHistory] {
        guard !searchText.isEmpty else { return viewModel.applications }
        return viewModel.applications.filter {
            $0.company.localizedCaseInsensitiveContains(searchText) ||
            $0.position.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            // Stat cards
            HStack(spacing: 14) {
                HomeStatCard(value: viewModel.appliedCount, label: "Total\napplications")
                HomeStatCard(value: viewModel.interviewCount, label: "Interviews\nscheduled")
                HomeStatCard(value: viewModel.hiredCount, label: "Offers\nreceived")
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 24, leading: 26, bottom: 0, trailing: 26))
            .selectionDisabled()

            // Section header
            HStack {
                Text("Recent applications")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Button {
                    showingAdd = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("New Application")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(Color.inkPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
            .padding(.bottom, 10)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 26, bottom: 0, trailing: 26))
            .selectionDisabled()

            // Column headers
            HStack(spacing: 14) {
                Color.clear.frame(width: 44, height: 1)
                Text("Role")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
                Spacer()
                Text("Applied")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
                    .frame(width: 110, alignment: .leading)
                Text("Status")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
                    .frame(width: 150, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.lightSeparator).frame(height: 1)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 26, bottom: 0, trailing: 26))
            .selectionDisabled()

            // Application rows
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Applications",
                    systemImage: "doc.text",
                    description: Text("Tap New Application to start tracking.")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .selectionDisabled()
            } else {
                ForEach(filtered) { entry in
                    NavigationLink(value: entry) {
                        HomeApplicationRow(
                            entry: entry,
                            onStatusChange: { newStatus in
                                viewModel.updateStatus(id: entry.id, status: newStatus)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteApplication(id: entry.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            viewModel.startEditing(entry)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .listRowBackground(Color.white)
                    .listRowSeparatorTint(Color.lightSeparator)
                    .listRowInsets(EdgeInsets(top: 0, leading: 26, bottom: 0, trailing: 26))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Home")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search applications")
        .navigationDestination(for: JobHistory.self) { entry in
            JobDetailView(
                entry: entry,
                onUpdate: { viewModel.updateApplication($0) },
                onDelete: { viewModel.deleteApplication(id: entry.id) }
            )
        }
        .onAppear { viewModel.load() }
        .sheet(isPresented: $showingAdd) {
            AddHistorySheet(
                onSave: { viewModel.addApplication($0) },
                onSaveAndGenerate: { entry in
                    viewModel.addApplication(entry)
                    router.selectedTab = .cvGenerator
                }
            )
        }
        .sheet(item: $viewModel.editingEntry) { entry in
            AddHistorySheet(editing: entry) { viewModel.updateApplication($0) }
        }
    }
}

// MARK: - Stat Card

private struct HomeStatCard: View {
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 16) {
            Text("\(value)")
                .font(.system(size: 32, weight: .heavy))
                .kerning(-1)
                .foregroundStyle(Color.inkPrimary)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.05), radius: 20, y: 6)
    }
}

// MARK: - Application Row

private struct HomeApplicationRow: View {
    let entry: JobHistory
    let onStatusChange: (ApplicationStatus) -> Void
    @State private var showStatusPicker = false

    private var logoColor: Color {
        let palette: [Color] = [.statusApplied, Color(hex: "111111"), Color(hex: "1db954"),
                                Color(hex: "635bff"), Color(hex: "e67e22"), Color(hex: "e91e63")]
        return palette[abs(entry.company.hashValue) % palette.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(logoColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(entry.company.prefix(2)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.position)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(entry.location.isEmpty ? entry.company : "\(entry.company) · \(entry.location)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
            }

            Spacer()

            Text(entry.appliedDate, style: .date)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.inkSecondary)
                .frame(width: 110, alignment: .leading)

            Button {
                showStatusPicker = true
            } label: {
                StatusBadge(status: entry.status, showChevron: true)
            }
            .buttonStyle(.plain)
            .frame(width: 150, alignment: .leading)
            .popover(isPresented: $showStatusPicker, arrowEdge: .bottom) {
                StatusPickerPopover(current: entry.status) { newStatus in
                    onStatusChange(newStatus)
                    showStatusPicker = false
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Status Picker Popover

private struct StatusPickerPopover: View {
    let current: ApplicationStatus
    let onSelect: (ApplicationStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ApplicationStatus.allCases, id: \.self) { status in
                Button {
                    onSelect(status)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(dotColor(status))
                            .frame(width: 9, height: 9)
                        Text(status.rawValue)
                            .font(.system(size: 13, weight: status == current ? .bold : .regular))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        if status == current {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 190)
    }

    private func dotColor(_ status: ApplicationStatus) -> Color {
        switch status {
        case .applied:           return .statusApplied
        case .interview:         return .statusInterview
        case .offer, .hired:     return .statusOffer
        case .rejected:          return .statusRejected
        case .closed:            return .statusClosed
        }
    }
}
