import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ProfileView: View {
    var viewModel: ProfileViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                ProfileHeader(profile: viewModel.profile) {
                    viewModel.startEditingProfile()
                } onPhotoTap: {
                    pickPhoto(viewModel: viewModel)
                }
                .padding(.horizontal, 26)
                .padding(.top, 28)
                .padding(.bottom, 24)

                // AI import review notice
                if viewModel.showReviewNotice {
                    AIReviewNoticeBanner {
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewModel.showReviewNotice = false
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Two-column body
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 18) {
                        EducationSection(viewModel: viewModel)
                        ExperienceSection(viewModel: viewModel)
                        ProjectSection(viewModel: viewModel)
                        OrganizationSection(viewModel: viewModel)
                        CertificationSection(viewModel: viewModel)
                        AchievementSection(viewModel: viewModel)
                        SkillsSection(viewModel: viewModel)
                    }
                    .frame(maxWidth: .infinity)

                    DocumentsCard(isImporting: viewModel.isImporting) { url in
                        importCVFile(from: url, viewModel: viewModel)
                    }
                    .frame(width: 280)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Color.clear.frame(width: 1, height: 22)
            }
        }
        .sheet(isPresented: $viewModel.isEditingProfile) {
            EditProfileSheet(
                profile: $viewModel.editingProfile,
                onSave: { viewModel.commitProfileEdit() },
                onCancel: { viewModel.cancelProfileEdit() }
            )
        }
        .alert("Import CV?", isPresented: $viewModel.showImportConfirm) {
            Button("Import", role: .destructive) { viewModel.confirmImport() }
            Button("Cancel", role: .cancel)      { viewModel.cancelImport() }
        } message: {
            let detail = viewModel.importSummaryLine.isEmpty
                ? ""
                : "\nFound: \(viewModel.importSummaryLine)\n"
            Text("\(detail)\nImporting will replace all current profile data. This cannot be undone.\n\nAI extraction may not be 100% accurate, please review each section after import.")
        }
        .alert("Import Failed", isPresented: $viewModel.showImportError) {
            Button("OK") { viewModel.showImportError = false; viewModel.importError = nil }
        } message: {
            Text(viewModel.importError ?? "")
        }
        .onAppear { viewModel.load() }
    }

    // Called by DocumentsCard after NSOpenPanel closes — text extracted synchronously
    // while the file-access grant from NSOpenPanel is still valid.
    private func importCVFile(from url: URL, viewModel: ProfileViewModel) {
        guard #available(macOS 26.0, *) else {
            viewModel.importError = "CV import requires macOS 26 or later (Apple Intelligence)."
            viewModel.showImportError = true
            return
        }
        guard let text = CVImportService.extractText(from: url) else {
            viewModel.importError = "Could not read the file. Make sure it is a text-based PDF (not a scanned image) or a plain .txt file."
            viewModel.showImportError = true
            return
        }
        viewModel.importCV(fromText: text)
    }

    private func pickPhoto(viewModel: ProfileViewModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.updatePhoto(url: url)
        }
    }
}

// MARK: - Profile Header

private struct ProfileHeader: View {
    let profile: UserProfile
    let onEdit: () -> Void
    let onPhotoTap: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            // Avatar — clickable to change photo
            Button(action: onPhotoTap) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let data = profile.photoData, let img = NSImage(data: data) {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.inkPrimary.overlay(
                                Text(profile.name.prefix(1).uppercased())
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())

                    Image(systemName: "camera.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.inkSecondary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appBackground, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.name.isEmpty ? "Your Name" : profile.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 14) {
                    if !profile.address.isEmpty {
                        Label(profile.address, systemImage: "mappin")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    if !profile.email.isEmpty {
                        Label(profile.email, systemImage: "envelope")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                if !profile.links.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(profile.links.prefix(3), id: \.url) { link in
                            Label(link.label.isEmpty ? link.url : link.label, systemImage: "link")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color.statusApplied)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil").font(.system(size: 11))
                    Text("Edit").font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14).padding(.vertical, 7)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                .foregroundStyle(Color.inkSecondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Section Layout (header + individual item cards)

private struct SectionLayout<Content: View>: View {
    let title: String
    let onAdd: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Button { onAdd() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("Add").font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                    .foregroundStyle(Color.inkSecondary)
                }
                .buttonStyle(.plain)
            }
            content
        }
    }
}

// MARK: - Item Card (display mode — like customize sections rows)

private struct ItemCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSeparator, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.03), radius: 1)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 3)
    }
}

// MARK: - Inline Edit Card

private struct InlineEditCard<Content: View>: View {
    let onCancel: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Editing")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(6)
                        .background(Color.fieldBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            content
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSeparator, lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 1)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 3)
    }
}

// MARK: - Form helpers (profile-internal)

private struct FormRow: View {
    let label: String
    @Binding var value: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.inkSecondary)
            TextField(placeholder.isEmpty ? label : placeholder, text: $value)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.fieldBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct BulletListEditor: View {
    @Binding var highlights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Highlights (bullet points)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.inkSecondary)

            ForEach(highlights.indices, id: \.self) { idx in
                HStack(spacing: 8) {
                    Circle().fill(Color.inkTertiary).frame(width: 5, height: 5)
                    TextField("", text: $highlights[idx])
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Color.fieldBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button { highlights.remove(at: idx) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button { highlights.append("") } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 11))
                    Text("Add bullet").font(.system(size: 12))
                }
                .foregroundStyle(Color.inkSecondary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct EditFormFooter: View {
    let onSave: () -> Void
    let onCancel: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Button("Save") { onSave() }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(Color.inkPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)

            Button("Cancel") { onCancel() }
                .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, 20).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1.5))
                .buttonStyle(.plain)

            Spacer()

            if let onDelete {
                Button("Delete") { onDelete() }
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.statusRejected)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.statusRejected, lineWidth: 1.5))
                    .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Education Section

private struct EducationSection: View {
    var viewModel: ProfileViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        SectionLayout(title: "Education", onAdd: { viewModel.startAddEducation() }) {
            ForEach(viewModel.cvData.educations) { edu in
                if case .education(let id) = viewModel.editingTarget, id == edu.id {
                    InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                        HStack(spacing: 12) {
                            FormRow(label: "Degree",      value: $viewModel.draftEducation.degree)
                            FormRow(label: "Institution", value: $viewModel.draftEducation.institution)
                        }
                        HStack(spacing: 12) {
                            FormRow(label: "Start", value: $viewModel.draftEducation.startYear, placeholder: "e.g. 2019")
                            FormRow(label: "End",   value: $viewModel.draftEducation.year,      placeholder: "e.g. 2023")
                        }
                        HStack(spacing: 12) {
                            FormRow(label: "Field of Study", value: $viewModel.draftEducation.fieldOfStudy)
                            FormRow(label: "GPA",            value: $viewModel.draftEducation.gpa, placeholder: "e.g. 3.8")
                        }
                        BulletListEditor(highlights: $viewModel.draftEducation.highlights)
                        EditFormFooter(
                            onSave: { viewModel.saveEducation() },
                            onCancel: { viewModel.cancelEditing() },
                            onDelete: { viewModel.deleteEducation(id: edu.id) }
                        )
                    }
                } else {
                    let title = [edu.degree, edu.institution].filter { !$0.isEmpty }.joined(separator: " · ")
                    let subtitle = [
                        [edu.startYear, edu.year].filter { !$0.isEmpty }.joined(separator: " – "),
                        edu.gpa.isEmpty ? nil : "GPA \(edu.gpa)",
                        edu.fieldOfStudy.isEmpty ? nil : edu.fieldOfStudy
                    ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                    ItemCard(title: title.isEmpty ? "Education" : title, subtitle: subtitle) {
                        viewModel.startEditEducation(edu)
                    }
                }
            }

            if case .education(nil) = viewModel.editingTarget {
                InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                    HStack(spacing: 12) {
                        FormRow(label: "Degree",      value: $viewModel.draftEducation.degree)
                        FormRow(label: "Institution", value: $viewModel.draftEducation.institution)
                    }
                    HStack(spacing: 12) {
                        FormRow(label: "Start", value: $viewModel.draftEducation.startYear, placeholder: "e.g. 2019")
                        FormRow(label: "End",   value: $viewModel.draftEducation.year,      placeholder: "e.g. 2023")
                    }
                    HStack(spacing: 12) {
                        FormRow(label: "Field of Study", value: $viewModel.draftEducation.fieldOfStudy)
                        FormRow(label: "GPA",            value: $viewModel.draftEducation.gpa, placeholder: "e.g. 3.8")
                    }
                    BulletListEditor(highlights: $viewModel.draftEducation.highlights)
                    EditFormFooter(
                        onSave: { viewModel.saveEducation() },
                        onCancel: { viewModel.cancelEditing() }
                    )
                }
            }
        }
    }
}

// MARK: - Experience Section

private struct ExperienceSection: View {
    var viewModel: ProfileViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        SectionLayout(title: "Experience", onAdd: { viewModel.startAddExperience() }) {
            ForEach(viewModel.cvData.experiences) { exp in
                if case .experience(let id) = viewModel.editingTarget, id == exp.id {
                    InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                        HStack(spacing: 12) {
                            FormRow(label: "Role / title",  value: $viewModel.draftExperience.role,    placeholder: "Role / title")
                            FormRow(label: "Organization",  value: $viewModel.draftExperience.company, placeholder: "Organization")
                        }
                        HStack(spacing: 12) {
                            FormRow(label: "Start", value: $viewModel.draftExperience.startDate, placeholder: "Start")
                            FormRow(label: "End",   value: $viewModel.draftExperience.duration,  placeholder: "End")
                        }
                        FormRow(label: "Location", value: $viewModel.draftExperience.location, placeholder: "Location")
                        BulletListEditor(highlights: $viewModel.draftExperience.highlights)
                        EditFormFooter(
                            onSave: { viewModel.saveExperience() },
                            onCancel: { viewModel.cancelEditing() },
                            onDelete: { viewModel.deleteExperience(id: exp.id) }
                        )
                    }
                } else {
                    let title    = [exp.role, exp.company].filter { !$0.isEmpty }.joined(separator: " · ")
                    let subtitle = [[exp.startDate, exp.duration].filter { !$0.isEmpty }.joined(separator: " – "),
                                    exp.location].filter { !$0.isEmpty }.joined(separator: " · ")
                    ItemCard(title: title.isEmpty ? "Experience" : title, subtitle: subtitle) {
                        viewModel.startEditExperience(exp)
                    }
                }
            }

            if case .experience(nil) = viewModel.editingTarget {
                InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                    HStack(spacing: 12) {
                        FormRow(label: "Role / title",  value: $viewModel.draftExperience.role,    placeholder: "Role / title")
                        FormRow(label: "Organization",  value: $viewModel.draftExperience.company, placeholder: "Organization")
                    }
                    HStack(spacing: 12) {
                        FormRow(label: "Start", value: $viewModel.draftExperience.startDate, placeholder: "Start")
                        FormRow(label: "End",   value: $viewModel.draftExperience.duration,  placeholder: "End")
                    }
                    FormRow(label: "Location", value: $viewModel.draftExperience.location, placeholder: "Location")
                    BulletListEditor(highlights: $viewModel.draftExperience.highlights)
                    EditFormFooter(
                        onSave: { viewModel.saveExperience() },
                        onCancel: { viewModel.cancelEditing() }
                    )
                }
            }
        }
    }
}

// MARK: - Project Section

private struct ProjectSection: View {
    var viewModel: ProfileViewModel
    @State private var newLinkLabel = ""
    @State private var newLinkURL   = ""

    var body: some View {
        @Bindable var viewModel = viewModel
        SectionLayout(title: "Related Project", onAdd: { viewModel.startAddProject() }) {
            ForEach(viewModel.cvData.projects) { proj in
                if case .project(let id) = viewModel.editingTarget, id == proj.id {
                    InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                        FormRow(label: "Project name", value: $viewModel.draftProject.name)
                        HStack(spacing: 12) {
                            FormRow(label: "Role",       value: $viewModel.draftProject.role,      placeholder: "e.g. Personal, Lead")
                            FormRow(label: "Tech stack", value: $viewModel.draftProject.techStack, placeholder: "SwiftUI, SwiftData…")
                        }
                        BulletListEditor(highlights: $viewModel.draftProject.highlights)
                        ProjectLinksEditor(viewModel: viewModel, newLabel: $newLinkLabel, newURL: $newLinkURL)
                        EditFormFooter(
                            onSave: { viewModel.saveProject() },
                            onCancel: { viewModel.cancelEditing() },
                            onDelete: { viewModel.deleteProject(id: proj.id) }
                        )
                    }
                } else {
                    let subtitle = [proj.role, proj.techStack].filter { !$0.isEmpty }.joined(separator: " · ")
                    ItemCard(title: proj.name.isEmpty ? "Project" : proj.name, subtitle: subtitle) {
                        viewModel.startEditProject(proj)
                    }
                }
            }

            if case .project(nil) = viewModel.editingTarget {
                InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                    FormRow(label: "Project name", value: $viewModel.draftProject.name)
                    HStack(spacing: 12) {
                        FormRow(label: "Role",       value: $viewModel.draftProject.role,      placeholder: "e.g. Personal, Lead")
                        FormRow(label: "Tech stack", value: $viewModel.draftProject.techStack, placeholder: "SwiftUI, SwiftData…")
                    }
                    BulletListEditor(highlights: $viewModel.draftProject.highlights)
                    ProjectLinksEditor(viewModel: viewModel, newLabel: $newLinkLabel, newURL: $newLinkURL)
                    EditFormFooter(
                        onSave: { viewModel.saveProject() },
                        onCancel: { viewModel.cancelEditing() }
                    )
                }
            }
        }
    }
}

private struct ProjectLinksEditor: View {
    var viewModel: ProfileViewModel
    @Binding var newLabel: String
    @Binding var newURL:   String

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.inkSecondary)

            ForEach(viewModel.draftProject.links.indices, id: \.self) { idx in
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.statusApplied)
                    VStack(alignment: .leading, spacing: 1) {
                        if !viewModel.draftProject.links[idx].label.isEmpty {
                            Text(viewModel.draftProject.links[idx].label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Text(viewModel.draftProject.links[idx].url)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.statusApplied)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button { viewModel.removeProjectLink(at: idx) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.fieldBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                TextField("Label (e.g. GitHub, App Store)", text: $newLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.fieldBackground)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: 170)

                TextField("URL", text: $newURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.fieldBackground)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit { addLink(viewModel: viewModel) }
            }

            Button("+ Add link") { addLink(viewModel: viewModel) }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(newURL.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.inkTertiary : Color.statusApplied)
                .buttonStyle(.plain)
                .disabled(newURL.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addLink(viewModel: ProfileViewModel) {
        let url = newURL.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        viewModel.addProjectLink(label: newLabel.trimmingCharacters(in: .whitespaces), url: url)
        newLabel = ""; newURL = ""
    }
}

// MARK: - Certification Section

private struct CertificationSection: View {
    var viewModel: ProfileViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        SectionLayout(title: "Certification", onAdd: { viewModel.startAddCertification() }) {
            ForEach(viewModel.cvData.certifications) { cert in
                if case .certification(let id) = viewModel.editingTarget, id == cert.id {
                    InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                        HStack(spacing: 12) {
                            FormRow(label: "Name",   value: $viewModel.draftCertification.name)
                            FormRow(label: "Issuer", value: $viewModel.draftCertification.issuer)
                        }
                        HStack(spacing: 12) {
                            FormRow(label: "Issue date",    value: $viewModel.draftCertification.issueDate, placeholder: "e.g. 2024")
                            FormRow(label: "Credential ID", value: $viewModel.draftCertification.credentialId)
                        }
                        FormRow(label: "Credential URL", value: $viewModel.draftCertification.credentialURL, placeholder: "https://…")
                        EditFormFooter(
                            onSave: { viewModel.saveCertification() },
                            onCancel: { viewModel.cancelEditing() },
                            onDelete: { viewModel.deleteCertification(id: cert.id) }
                        )
                    }
                } else {
                    let title    = [cert.name, cert.issuer].filter { !$0.isEmpty }.joined(separator: " · ")
                    ItemCard(title: title.isEmpty ? "Certification" : title, subtitle: cert.issueDate) {
                        viewModel.startEditCertification(cert)
                    }
                }
            }

            if case .certification(nil) = viewModel.editingTarget {
                InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                    HStack(spacing: 12) {
                        FormRow(label: "Name",   value: $viewModel.draftCertification.name)
                        FormRow(label: "Issuer", value: $viewModel.draftCertification.issuer)
                    }
                    HStack(spacing: 12) {
                        FormRow(label: "Issue date",    value: $viewModel.draftCertification.issueDate, placeholder: "e.g. 2024")
                        FormRow(label: "Credential ID", value: $viewModel.draftCertification.credentialId)
                    }
                    FormRow(label: "Credential URL", value: $viewModel.draftCertification.credentialURL, placeholder: "https://…")
                    EditFormFooter(
                        onSave: { viewModel.saveCertification() },
                        onCancel: { viewModel.cancelEditing() }
                    )
                }
            }
        }
    }
}

// MARK: - Organization Section

private struct OrganizationSection: View {
    var viewModel: ProfileViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        SectionLayout(title: "Organization", onAdd: { viewModel.startAddOrganization() }) {
            ForEach(viewModel.cvData.organizations) { org in
                if case .organization(let id) = viewModel.editingTarget, id == org.id {
                    InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                        HStack(spacing: 12) {
                            FormRow(label: "Organization name", value: $viewModel.draftOrganization.name)
                            FormRow(label: "Role / position",   value: $viewModel.draftOrganization.role)
                        }
                        HStack(spacing: 12) {
                            FormRow(label: "Start", value: $viewModel.draftOrganization.startDate, placeholder: "e.g. 2022")
                            FormRow(label: "End",   value: $viewModel.draftOrganization.endDate,   placeholder: "e.g. 2023")
                        }
                        BulletListEditor(highlights: $viewModel.draftOrganization.highlights)
                        FormRow(label: "Credential URL", value: $viewModel.draftOrganization.credentialURL, placeholder: "https://…")
                        EditFormFooter(
                            onSave: { viewModel.saveOrganization() },
                            onCancel: { viewModel.cancelEditing() },
                            onDelete: { viewModel.deleteOrganization(id: org.id) }
                        )
                    }
                } else {
                    let title    = [org.role, org.name].filter { !$0.isEmpty }.joined(separator: " · ")
                    let subtitle = [org.startDate, org.endDate].filter { !$0.isEmpty }.joined(separator: " – ")
                    ItemCard(title: title.isEmpty ? "Organization" : title, subtitle: subtitle) {
                        viewModel.startEditOrganization(org)
                    }
                }
            }

            if case .organization(nil) = viewModel.editingTarget {
                InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                    HStack(spacing: 12) {
                        FormRow(label: "Organization name", value: $viewModel.draftOrganization.name)
                        FormRow(label: "Role / position",   value: $viewModel.draftOrganization.role)
                    }
                    HStack(spacing: 12) {
                        FormRow(label: "Start", value: $viewModel.draftOrganization.startDate, placeholder: "e.g. 2022")
                        FormRow(label: "End",   value: $viewModel.draftOrganization.endDate,   placeholder: "e.g. 2023")
                    }
                    BulletListEditor(highlights: $viewModel.draftOrganization.highlights)
                    FormRow(label: "Credential URL", value: $viewModel.draftOrganization.credentialURL, placeholder: "https://…")
                    EditFormFooter(
                        onSave: { viewModel.saveOrganization() },
                        onCancel: { viewModel.cancelEditing() }
                    )
                }
            }
        }
    }
}

// MARK: - Achievement Section

private struct AchievementSection: View {
    var viewModel: ProfileViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        SectionLayout(title: "Achievement", onAdd: { viewModel.startAddAchievement() }) {
            ForEach(viewModel.cvData.achievements) { ach in
                if case .achievement(let id) = viewModel.editingTarget, id == ach.id {
                    InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                        HStack(spacing: 12) {
                            FormRow(label: "Title",  value: $viewModel.draftAchievement.title, placeholder: "e.g. Best Paper Award")
                            FormRow(label: "From",   value: $viewModel.draftAchievement.issuer, placeholder: "e.g. IEEE")
                        }
                        FormRow(label: "Date", value: $viewModel.draftAchievement.date, placeholder: "e.g. 2023")
                        FormRow(label: "Description", value: $viewModel.draftAchievement.notes, placeholder: "Brief description…")
                        FormRow(label: "Credential URL", value: $viewModel.draftAchievement.credentialURL, placeholder: "https://…")
                        EditFormFooter(
                            onSave: { viewModel.saveAchievement() },
                            onCancel: { viewModel.cancelEditing() },
                            onDelete: { viewModel.deleteAchievement(id: ach.id) }
                        )
                    }
                } else {
                    let title    = [ach.title, ach.issuer].filter { !$0.isEmpty }.joined(separator: " · ")
                    ItemCard(title: title.isEmpty ? "Achievement" : title, subtitle: ach.date) {
                        viewModel.startEditAchievement(ach)
                    }
                }
            }

            if case .achievement(nil) = viewModel.editingTarget {
                InlineEditCard(onCancel: { viewModel.cancelEditing() }) {
                    HStack(spacing: 12) {
                        FormRow(label: "Title",  value: $viewModel.draftAchievement.title, placeholder: "e.g. Best Paper Award")
                        FormRow(label: "From",   value: $viewModel.draftAchievement.issuer, placeholder: "e.g. IEEE")
                    }
                    FormRow(label: "Date", value: $viewModel.draftAchievement.date, placeholder: "e.g. 2023")
                    FormRow(label: "Description", value: $viewModel.draftAchievement.notes, placeholder: "Brief description…")
                    FormRow(label: "Credential URL", value: $viewModel.draftAchievement.credentialURL, placeholder: "https://…")
                    EditFormFooter(
                        onSave: { viewModel.saveAchievement() },
                        onCancel: { viewModel.cancelEditing() }
                    )
                }
            }
        }
    }
}

// MARK: - Skills Section

private struct SkillsSection: View {
    var viewModel: ProfileViewModel
    @State private var newSkill = ""
    @State private var isAdding = false

    var body: some View {
        @Bindable var viewModel = viewModel
        SectionLayout(title: "Skills", onAdd: { isAdding = true }) {
            // Wrapping chip layout inside a single card
            if !viewModel.profile.skills.isEmpty || isAdding {
                VStack(alignment: .leading, spacing: 12) {
                    if !viewModel.profile.skills.isEmpty {
                        SkillFlowLayout(spacing: 8) {
                            ForEach(viewModel.profile.skills, id: \.self) { skill in
                                HStack(spacing: 6) {
                                    Text(skill)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.inkPrimary)
                                    Button {
                                        viewModel.removeSkill(skill)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.inkTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.appSeparator, lineWidth: 1.5))
                            }
                        }
                    }

                    if isAdding {
                        HStack(spacing: 8) {
                            TextField("New skill…", text: $newSkill)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.fieldBackground)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onSubmit { commitNewSkill(viewModel: viewModel) }

                            Button("Add") { commitNewSkill(viewModel: viewModel) }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(newSkill.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? Color.inkTertiary.opacity(0.3) : Color.inkPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .buttonStyle(.plain)
                                .disabled(newSkill.trimmingCharacters(in: .whitespaces).isEmpty)

                            Button { isAdding = false; newSkill = "" } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.inkTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSeparator, lineWidth: 1))
                .shadow(color: .black.opacity(0.03), radius: 1)
                .shadow(color: .black.opacity(0.03), radius: 10, y: 3)
            }
        }
    }

    private func commitNewSkill(viewModel: ProfileViewModel) {
        viewModel.addSkill(newSkill)
        newSkill = ""
    }
}

private struct SkillFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, s.height); x += s.width + spacing
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowH = max(rowH, s.height); x += s.width + spacing
        }
    }
}

// MARK: - Documents Card

private struct DocumentsCard: View {
    let isImporting: Bool
    let onImport: (URL) -> Void

    @State private var uploadedFileName: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Documents")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Rectangle().fill(Color.lightSeparator).frame(height: 1)

            VStack(spacing: 12) {
                // Upload area
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.inkTertiary)
                    Text("Upload your CV")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                    Text("PDF · auto-fills fields with AI")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.inkTertiary)

                    Button("Choose File") { pickCV() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .background(isImporting ? Color.inkTertiary : Color.inkPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .buttonStyle(.plain)
                        .disabled(isImporting)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.appSeparator, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )

                // File row — shown after a file is chosen
                if let name = uploadedFileName {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.statusRejected)
                                .frame(width: 32, height: 36)
                            Text("PDF")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                            if isImporting {
                                HStack(spacing: 5) {
                                    ProgressView().scaleEffect(0.55)
                                    Text("Parsing with AI…")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.inkTertiary)
                                }
                            } else {
                                Text("Ready to import")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.inkTertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.appSeparator))
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.04), radius: 18, y: 5)
    }

    private func pickCV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose your CV (PDF or .txt)"
        panel.prompt = "Import"
        if panel.runModal() == .OK, let url = panel.url {
            uploadedFileName = url.lastPathComponent
            onImport(url)
        }
    }
}

// MARK: - AI Review Notice Banner

private struct AIReviewNoticeBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.statusApplied)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("AI import complete — please review your data")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text("On-device AI may misclassify entries. Double-check each section before using your profile.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
        }
        .padding(14)
        .background(Color.statusApplied.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.statusApplied.opacity(0.25), lineWidth: 1))
    }
}
