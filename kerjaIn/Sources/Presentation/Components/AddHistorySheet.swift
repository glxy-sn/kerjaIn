import SwiftUI

struct AddHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    private let editing: JobHistory?
    private let onSave: (JobHistory) -> Void
    private let onSaveAndGenerate: ((JobHistory) -> Void)?

    @State private var position: String
    @State private var company: String
    @State private var location: String
    @State private var status: ApplicationStatus
    @State private var jobDescription: String
    @State private var appliedDate: Date

    // Compatibility init for HistoryView: AddHistorySheet { entry in ... }
    init(_ onSave: @escaping (JobHistory) -> Void) {
        self.editing = nil
        self.onSave = onSave
        self.onSaveAndGenerate = nil
        _position = State(initialValue: "")
        _company = State(initialValue: "")
        _location = State(initialValue: "")
        _status = State(initialValue: .applied)
        _jobDescription = State(initialValue: "")
        _appliedDate = State(initialValue: Date())
    }

    // HomeView new application with CV generation option
    init(onSave: @escaping (JobHistory) -> Void, onSaveAndGenerate: @escaping (JobHistory) -> Void) {
        self.editing = nil
        self.onSave = onSave
        self.onSaveAndGenerate = onSaveAndGenerate
        _position = State(initialValue: "")
        _company = State(initialValue: "")
        _location = State(initialValue: "")
        _status = State(initialValue: .applied)
        _jobDescription = State(initialValue: "")
        _appliedDate = State(initialValue: Date())
    }

    // Edit mode
    init(editing: JobHistory, onSave: @escaping (JobHistory) -> Void) {
        self.editing = editing
        self.onSave = onSave
        self.onSaveAndGenerate = nil
        _position = State(initialValue: editing.position)
        _company = State(initialValue: editing.company)
        _location = State(initialValue: editing.location)
        _status = State(initialValue: editing.status)
        _jobDescription = State(initialValue: editing.notes)
        _appliedDate = State(initialValue: editing.appliedDate)
    }

    private var isEditMode: Bool { editing != nil }
    private var canSave: Bool { !position.isEmpty && !company.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(isEditMode ? "Edit application" : "New application")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text("Track a role you're applying to.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.top, 32)
            .padding(.horizontal, 32)

            // Form fields
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    SheetFormField(label: "Role *", placeholder: "e.g. iOS Engineer", text: $position)
                    SheetFormField(label: "Company *", placeholder: "e.g. KerjaIn", text: $company)
                }
                HStack(spacing: 16) {
                    SheetFormField(label: "Location", placeholder: "Remote / city", text: $location)
                    SheetStatusField(status: $status)
                }
                // Job description
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 4) {
                        Text("Job description")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("(optional — enables Generate CV)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.fieldBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.appSeparator, lineWidth: 1)
                            )
                        if jobDescription.isEmpty {
                            Text("Fill the Job Description to make the CV")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.inkTertiary)
                                .padding(.horizontal, 14)
                                .padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $jobDescription)
                            .font(.system(size: 14))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .frame(minHeight: 110)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 32)

            Spacer(minLength: 24)

            Divider()

            // Footer buttons
            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(SheetOutlineStyle())

                Spacer()

                Button("Save") {
                    onSave(makeEntry())
                    dismiss()
                }
                .buttonStyle(SheetOutlineStyle())
                .disabled(!canSave)

                if let generate = onSaveAndGenerate {
                    Button("Save & Generate CV →") {
                        generate(makeEntry())
                        dismiss()
                    }
                    .buttonStyle(SheetPrimaryStyle())
                    .disabled(!canSave)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .frame(width: 560)
    }

    private func makeEntry() -> JobHistory {
        JobHistory(
            id: editing?.id ?? UUID().uuidString,
            company: company,
            position: position,
            location: location,
            appliedDate: appliedDate,
            status: status,
            notes: jobDescription
        )
    }
}

private struct SheetFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SheetStatusField: View {
    @Binding var status: ApplicationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Status")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
            Menu {
                ForEach(ApplicationStatus.allCases, id: \.self) { s in
                    Button(s.rawValue) { status = s }
                }
            } label: {
                HStack {
                    Text(status.rawValue)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SheetOutlineStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isEnabled ? Color.inkPrimary : Color.inkTertiary)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? Color.appSeparator : Color.appSeparator.opacity(0.4), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct SheetPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isEnabled ? .white : Color.inkTertiary)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(isEnabled ? Color.inkPrimary : Color.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
