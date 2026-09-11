import SwiftUI

// Converts any stored date token to abbreviated "Mon YYYY" style.
// Handles: full month names ("September 2020" → "Sept 2020"),
//          numeric slash/dash ("09/2020" or "2020-09" → "Sept 2020"),
//          already-abbreviated ("Sept 2020" → unchanged),
//          year-only ("2020" → "2020"), "Present" → "Present".
private func fmtDate(_ raw: String) -> String {
    let s = raw.trimmingCharacters(in: .whitespaces)
    guard !s.isEmpty else { return "" }

    let abbrevs = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sept","Oct","Nov","Dec"]
    let monthMap: [String: String] = [
        "january":"Jan","february":"Feb","march":"Mar","april":"Apr",
        "may":"May","june":"Jun","july":"Jul","august":"Aug",
        "september":"Sept","sept":"Sept","sep":"Sept",
        "october":"Oct","november":"Nov","december":"Dec",
        "jan":"Jan","feb":"Feb","mar":"Mar","apr":"Apr",
        "jun":"Jun","jul":"Jul","aug":"Aug",
        "oct":"Oct","nov":"Nov","dec":"Dec",
    ]

    // Numeric "MM/YYYY", "M/YYYY", "MM-YYYY", "YYYY/MM", "YYYY-MM"
    let sep = CharacterSet(charactersIn: "/-")
    let parts = s.components(separatedBy: sep)
    if parts.count == 2 {
        let a = parts[0].trimmingCharacters(in: .whitespaces)
        let b = parts[1].trimmingCharacters(in: .whitespaces)
        if a.count <= 2, a.allSatisfy(\.isNumber), b.count == 4, b.allSatisfy(\.isNumber),
           let m = Int(a), m >= 1, m <= 12 {
            return "\(abbrevs[m-1]) \(b)"
        }
        if a.count == 4, a.allSatisfy(\.isNumber), b.count <= 2, b.allSatisfy(\.isNumber),
           let m = Int(b), m >= 1, m <= 12 {
            return "\(abbrevs[m-1]) \(a)"
        }
    }

    // Word-by-word: replace full/common month names with abbreviations
    let words = s.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    let mapped = words.map { monthMap[$0.lowercased()] ?? $0 }
    return mapped.joined(separator: " ")
}

// Builds a "Mon YYYY - Mon YYYY" range, formatting each token individually.
private func dateRange(_ start: String, _ end: String) -> String {
    [fmtDate(start), fmtDate(end)].filter { !$0.isEmpty }.joined(separator: " - ")
}

// Converts a date string to a sortable Double so sections can be ordered most-recent-first.
// "Present" → ∞, "Dec 2024" → 2024.12, "2020" → 2020.0, "" → 0.
private func dateScore(_ raw: String) -> Double {
    let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
    guard !s.isEmpty else { return 0 }
    if s == "present" { return .infinity }

    let monthNums: [String: Double] = [
        "jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
        "jul":7,"aug":8,"sep":9,"sept":9,"oct":10,"nov":11,"dec":12,
        "january":1,"february":2,"march":3,"april":4,"june":6,
        "july":7,"august":8,"september":9,"october":10,"november":11,"december":12
    ]
    let parts = s.components(separatedBy: CharacterSet(charactersIn: "/-"))
    if parts.count == 2 {
        let a = parts[0].trimmingCharacters(in: .whitespaces)
        let b = parts[1].trimmingCharacters(in: .whitespaces)
        if b.count == 4, let yr = Double(b), let m = Double(a), m >= 1, m <= 12 { return yr + m/100 }
        if a.count == 4, let yr = Double(a), let m = Double(b), m >= 1, m <= 12 { return yr + m/100 }
    }
    var year: Double?; var month: Double?
    for w in s.components(separatedBy: .whitespaces).filter({ !$0.isEmpty }) {
        if let y = Double(w), y > 1900, y < 2200 { year = y }
        else if let m = monthNums[w] { month = m }
    }
    if let y = year, let m = month { return y + m/100 }
    if let y = year { return y }
    return 0
}

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

struct CVDocumentView: View {
    let cvData: CVData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── HEADER ───────────────────────────────────────────────
            VStack(spacing: 3) {
                Text(cvData.profile.name)
                    .font(.custom("Arial", size: 18)).bold()
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)

                // Subtitle: most-recent experience role
                if let subtitle = cvData.experiences.first?.role, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.custom("Arial", size: 11)).bold()
                        .foregroundStyle(Color.inkPrimary)
                        .multilineTextAlignment(.center)
                }

                // Contact line — uses onTapGesture so links fire inside ScrollView
                CVContactLine(profile: cvData.profile)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)

            // ── SUMMARY ──────────────────────────────────────────────
            if !cvData.profile.summary.isEmpty {
                CVDocSection("SUMMARY") {
                    Text(cvData.profile.summary)
                        .font(.custom("Arial", size: 10))
                        .foregroundStyle(Color.inkPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // ── EDUCATION ────────────────────────────────────────────
            if !cvData.educations.isEmpty {
                CVDocSection("EDUCATION") {
                    ForEach(cvData.educations.sorted { dateScore($0.year) > dateScore($1.year) }) { edu in
                        VStack(alignment: .leading, spacing: 2) {
                            // Institution (left) + date range (right)
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 1) {
                                    if !edu.institution.isEmpty {
                                        Text(edu.institution)
                                            .font(.custom("Arial", size: 10.5)).bold()
                                            .foregroundStyle(Color.inkPrimary)
                                    }
                                    let degreeLine = [edu.degree, edu.fieldOfStudy]
                                        .filter { !$0.isEmpty }.joined(separator: " ")
                                    if !degreeLine.isEmpty {
                                        Text(degreeLine)
                                            .font(.custom("Arial", size: 10))
                                            .italic()
                                            .foregroundStyle(Color.inkSecondary)
                                    }
                                }
                                Spacer()
                                let dr = dateRange(edu.startYear, edu.year)
                                if !dr.isEmpty {
                                    Text(dr)
                                        .font(.custom("Arial", size: 10))
                                        .italic()
                                        .foregroundStyle(Color.inkSecondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            // GPA bullet
                            if !edu.gpa.isEmpty {
                                CVDashRow(text: "GPA (\(edu.gpa))")
                            }
                            // Additional highlights
                            ForEach(edu.highlights.filter { !$0.isEmpty }, id: \.self) { h in
                                CVDashRow(text: h)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            // ── PROFESSIONAL EXPERIENCE ───────────────────────────────
            if !cvData.experiences.isEmpty {
                CVDocSection("PROFESSIONAL EXPERIENCE") {
                    ForEach(cvData.experiences.sorted { dateScore($0.duration) > dateScore($1.duration) }) { exp in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                Text(exp.company.isEmpty ? exp.role : exp.company)
                                    .font(.custom("Arial", size: 10.5)).bold()
                                    .foregroundStyle(Color.inkPrimary)
                                Spacer()
                                let dr = dateRange(exp.startDate, exp.duration)
                                if !dr.isEmpty {
                                    Text(dr)
                                        .font(.custom("Arial", size: 10))
                                        .italic()
                                        .foregroundStyle(Color.inkSecondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            if !exp.role.isEmpty && !exp.company.isEmpty {
                                Text(exp.role)
                                    .font(.custom("Arial", size: 10))
                                    .italic()
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            let bullets = exp.highlights.filter { !$0.isEmpty }
                            if bullets.isEmpty && !exp.description.isEmpty {
                                CVDashRow(text: exp.description)
                            } else {
                                ForEach(bullets, id: \.self) { h in CVDashRow(text: h) }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }

            // ── RELATED PROJECTS ──────────────────────────────────────
            if !cvData.projects.isEmpty {
                CVDocSection("RELATED PROJECTS") {
                    ForEach(cvData.projects) { proj in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top) {
                                Text(proj.name.isEmpty ? "Project" : proj.name)
                                    .font(.custom("Arial", size: 10.5)).bold()
                                    .foregroundStyle(Color.inkPrimary)
                                Spacer()
                                if !proj.role.isEmpty {
                                    Text(proj.role)
                                        .font(.custom("Arial", size: 10))
                                        .italic()
                                        .foregroundStyle(Color.inkSecondary)
                                }
                            }
                            if !proj.techStack.isEmpty {
                                Text(proj.techStack)
                                    .font(.custom("Arial", size: 10))
                                    .italic()
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            ForEach(proj.highlights.filter { !$0.isEmpty }, id: \.self) { h in
                                CVDashRow(text: h)
                            }
                            if !proj.links.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(proj.links, id: \.url) { link in
                                        Text("[\(link.label.isEmpty ? link.url : link.label)]")
                                            .font(.custom("Arial", size: 9.5))
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

            // ── HONORS, AWARDS & SKILLS ───────────────────────────────
            let hasCerts  = !cvData.certifications.isEmpty
            let hasOrgs   = !cvData.organizations.isEmpty
            let hasAchiev = !cvData.achievements.isEmpty
            if hasCerts || hasOrgs || hasAchiev {
                CVDocSection("HONORS, AWARDS & SKILLS") {
                    // Certifications grouped bullet
                    if hasCerts {
                        CVHonorsBullet(
                            category: "Certifications",
                            items: cvData.certifications
                                .sorted { dateScore($0.issueDate) > dateScore($1.issueDate) }
                                .map { HonorsItem(text: $0.name, date: $0.issueDate, credentialURL: $0.credentialURL) }
                        )
                    }
                    // Organizations as Volunteering grouped bullet
                    if hasOrgs {
                        CVHonorsBullet(
                            category: "Volunteering",
                            items: cvData.organizations
                                .sorted { dateScore($0.endDate) > dateScore($1.endDate) }
                                .map {
                                    let period = dateRange($0.startDate, $0.endDate)
                                    return HonorsItem(text: $0.name, date: period, credentialURL: $0.credentialURL)
                                }
                        )
                    }
                    // Achievements grouped bullet
                    if hasAchiev {
                        CVHonorsBullet(
                            category: "Achievement",
                            items: cvData.achievements
                                .sorted { dateScore($0.date) > dateScore($1.date) }
                                .map { HonorsItem(text: $0.title, date: $0.date, credentialURL: $0.credentialURL) }
                        )
                    }
                }
            }

            // ── SKILLS ───────────────────────────────────────────────
            if !cvData.profile.skills.isEmpty {
                CVDocSection("SKILLS") {
                    Text(cvData.profile.skills.joined(separator: " · "))
                        .font(.custom("Arial", size: 10))
                        .foregroundStyle(Color.inkPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Supporting types

struct HonorsItem {
    let text: String
    let date: String
    let credentialURL: String
}

// MARK: - Private sub-views

private struct CVHonorsBullet: View {
    let category: String
    let items: [HonorsItem]

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("-")
                .font(.custom("Arial", size: 10))
                .foregroundStyle(Color.inkPrimary)
            Text(attributedText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 3)
    }

    private var attributedText: AttributedString {
        var result = AttributedString()
        var label = AttributedString("\(category): ")
        label.font = Font.custom("Arial", size: 10).bold()
        result += label

        for (i, item) in items.enumerated() {
            var name = AttributedString(item.text)
            name.font = Font.custom("Arial", size: 10)
            result += name

            if !item.credentialURL.isEmpty {
                var cred = AttributedString(" [Credential]")
                cred.font = Font.custom("Arial", size: 10)
                cred.foregroundColor = Color(hex: "0a66c2")
                result += cred
            }

            if !item.date.isEmpty {
                var date = AttributedString(" (\(item.date))")
                date.font = Font.custom("Arial", size: 10)
                result += date
            }

            if i < items.count - 1 {
                var sep = AttributedString(", ")
                sep.font = Font.custom("Arial", size: 10)
                result += sep
            }
        }
        return result
    }
}

private struct CVDashRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("-")
                .font(.custom("Arial", size: 10))
                .foregroundStyle(Color.inkPrimary)
            Text(text)
                .font(.custom("Arial", size: 10))
                .foregroundStyle(Color.inkPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 1)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Arial", size: 11)).bold()
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            // NSViewRepresentable: AppKit calls draw(_:) on every NSView subclass
            // during dataWithPDF, so this line always renders in PDF export.
            // Pure SwiftUI shapes (Rectangle/Color/Canvas) are CALayer-backed and
            // can be skipped by the AppKit PDF renderer.
            CVSectionDivider()
                .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                .padding(.bottom, 2)
            content
        }
        .padding(.bottom, 14)
    }
}

// Renders the contact header line. Uses onTapGesture so link clicks are NOT
// swallowed by the enclosing macOS ScrollView (AttributedString .link attribute
// is consumed by NSScrollView before reaching the Text hit-test area).
private struct CVContactLine: View {
    let profile: UserProfile

    private let font  = Font.custom("Arial", size: 9.5)
    private let sep   = Color.inkSecondary
    private let blue  = Color(red: 0.039, green: 0.4, blue: 0.761)

    // Pre-compute segments: plain text parts have url == nil, link parts have url set.
    private var segments: [(text: String, url: URL?)] {
        var result: [(String, URL?)] = []
        let plain = [profile.address, profile.phone, profile.email].filter { !$0.isEmpty }
        if !plain.isEmpty {
            result.append((plain.joined(separator: " | "), nil))
        }
        for link in profile.links where !link.label.isEmpty {
            let raw = link.url.trimmingCharacters(in: .whitespaces)
            let urlStr = raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)"
            result.append((link.label, raw.isEmpty ? nil : URL(string: urlStr)))
        }
        return result
    }

    var body: some View {
        if !segments.isEmpty {
            HStack(spacing: 0) {
                ForEach(segments.indices, id: \.self) { i in
                    let seg = segments[i]
                    if i > 0 {
                        Text(" | ").font(font).foregroundStyle(sep)
                    }
                    if let url = seg.url {
                        Text(seg.text)
                            .font(font).foregroundStyle(blue).underline()
                            .onTapGesture { NSWorkspace.shared.open(url) }
                    } else {
                        Text(seg.text).font(font).foregroundStyle(sep)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// NSViewRepresentable divider whose draw(_:) is always called by AppKit during
// dataWithPDF, guaranteeing the line appears in exported PDFs.
private struct CVSectionDivider: NSViewRepresentable {
    func makeNSView(context: Context) -> DividerLineView { DividerLineView() }
    func updateNSView(_ nsView: DividerLineView, context: Context) {}

    class DividerLineView: NSView {
        override var isFlipped: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.black.setFill()
            // Snap to pixel boundaries so the line never straddles two pixels
            // and appears a different thickness in different sections.
            let aligned = backingAlignedRect(bounds, options: .alignAllEdgesNearest)
            NSBezierPath.fill(aligned)
        }
    }
}
