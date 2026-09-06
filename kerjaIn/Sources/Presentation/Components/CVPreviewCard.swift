import SwiftUI

struct CVPreviewCard: View {
    let cvData: CVData
    var forceEmpty: Bool = false

    private var isEmpty: Bool {
        forceEmpty || (cvData.profile.name.isEmpty && cvData.educations.isEmpty && cvData.experiences.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEmpty ? "CV Preview" : cvData.profile.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isEmpty ? Color.inkTertiary : Color.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.fieldBackground)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.lightSeparator).frame(height: 1)
            }

            if isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "diamond")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.inkTertiary)
                    Text("Generate a CV to see\nthe preview here.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    CVDocumentView(cvData: cvData)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 22)
                }
            }
        }
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

private struct CVDocumentView: View {
    let cvData: CVData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
                Text(cvData.profile.name)
                    .font(.custom("Georgia", size: 19)).bold()
                    .foregroundStyle(Color.inkPrimary)
                if !cvData.profile.email.isEmpty {
                    Text(cvData.profile.email)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.statusApplied)
                }
                let contact = [cvData.profile.phone, cvData.profile.address]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !contact.isEmpty {
                    Text(contact)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)

            if !cvData.profile.summary.isEmpty {
                CVDocSection("PROFESSIONAL SUMMARY") {
                    Text(cvData.profile.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.inkPrimary.opacity(0.8))
                        .lineSpacing(3)
                }
            }

            if !cvData.educations.isEmpty {
                CVDocSection("EDUCATION") {
                    ForEach(cvData.educations) { edu in
                        VStack(alignment: .leading, spacing: 1) {
                            Text([edu.degree, edu.institution].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 11, weight: .bold))
                            if !edu.year.isEmpty {
                                Text(edu.year)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.inkSecondary)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }

            if !cvData.experiences.isEmpty {
                CVDocSection("EXPERIENCE") {
                    ForEach(cvData.experiences) { exp in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                Text(exp.role.isEmpty ? exp.company : exp.role)
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                Text(exp.duration)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            if !exp.company.isEmpty && !exp.role.isEmpty {
                                Text(exp.company)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            if !exp.description.isEmpty {
                                Text(exp.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.inkPrimary.opacity(0.7))
                                    .lineSpacing(2)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            if !cvData.projects.isEmpty {
                CVDocSection("RELATED PROJECTS") {
                    ForEach(cvData.projects) { proj in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                Text(proj.name.isEmpty ? "Project" : proj.name)
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                if !proj.role.isEmpty {
                                    Text(proj.role)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.inkSecondary)
                                }
                            }
                            if !proj.techStack.isEmpty {
                                Text(proj.techStack)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.inkSecondary)
                                    .italic()
                            }
                            ForEach(proj.highlights.filter { !$0.isEmpty }, id: \.self) { h in
                                Text("• \(h)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.inkPrimary.opacity(0.8))
                                    .lineSpacing(2)
                            }
                            if !proj.links.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(proj.links, id: \.url) { link in
                                        Text("[\(link.label.isEmpty ? link.url : link.label)]")
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(Color.statusApplied)
                                    }
                                }
                                .padding(.top, 1)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            if !cvData.organizations.isEmpty {
                CVDocSection("ORGANIZATION") {
                    ForEach(cvData.organizations) { org in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                Text([org.role, org.name].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                let period = [org.startDate, org.endDate].filter { !$0.isEmpty }.joined(separator: " – ")
                                if !period.isEmpty {
                                    Text(period)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.inkSecondary)
                                }
                            }
                            ForEach(org.highlights.filter { !$0.isEmpty }, id: \.self) { h in
                                Text("• \(h)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.inkPrimary.opacity(0.8))
                                    .lineSpacing(2)
                            }
                            if !org.credentialURL.isEmpty {
                                Text("[credential]")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(Color.statusApplied)
                                    .padding(.top, 1)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            if !cvData.certifications.isEmpty {
                CVDocSection("CERTIFICATIONS") {
                    ForEach(cvData.certifications) { cert in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                Text([cert.name, cert.issuer].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                if !cert.issueDate.isEmpty {
                                    Text(cert.issueDate)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.inkSecondary)
                                }
                            }
                            if !cert.credentialId.isEmpty {
                                Text("ID: \(cert.credentialId)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            if !cert.credentialURL.isEmpty {
                                Text("[credential]")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(Color.statusApplied)
                                    .padding(.top, 1)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            if !cvData.achievements.isEmpty {
                CVDocSection("ACHIEVEMENTS") {
                    ForEach(cvData.achievements) { ach in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                Text([ach.title, ach.issuer].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                if !ach.date.isEmpty {
                                    Text(ach.date)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.inkSecondary)
                                }
                            }
                            if !ach.notes.isEmpty {
                                Text(ach.notes)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.inkPrimary.opacity(0.7))
                                    .lineSpacing(2)
                            }
                            if !ach.credentialURL.isEmpty {
                                Text("[credential]")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(Color.statusApplied)
                                    .padding(.top, 1)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            if !cvData.profile.skills.isEmpty {
                CVDocSection("SKILLS") {
                    Text(cvData.profile.skills.joined(separator: " · "))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }
}

private struct CVDocSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.inkSecondary)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 3)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.appSeparator).frame(height: 1)
                }
            content
        }
        .padding(.bottom, 16)
    }
}
