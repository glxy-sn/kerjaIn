import Foundation
import PDFKit

// MARK: - Codable output types (replaces @Generable structs)

struct ParsedLink: Codable {
    var label: String
    var url: String
}

struct ParsedBasicProfile: Codable {
    var name: String
    var email: String
    var phone: String
    var address: String
    var summary: String
    var skills: [String]
    var links: [ParsedLink]
}

struct ParsedEdu: Codable {
    var institution: String
    var degree: String
    var field: String
    var startYear: String
    var endYear: String
    var gpa: String
}

struct ParsedExp: Codable {
    var company: String
    var role: String
    var startDate: String
    var endDate: String
    var location: String
    var highlights: [String]
}

struct ParsedProj: Codable {
    var name: String
    var role: String
    var techStack: String
    var highlights: [String]
}

struct ParsedCert: Codable {
    var name: String
    var issuer: String
    var issueDate: String
    var credentialURL: String
}

struct ParsedOrg: Codable {
    var name: String
    var role: String
    var startDate: String
    var endDate: String
}

struct ParsedAward: Codable {
    var title: String
    var issuer: String
    var date: String
    var notes: String
}

struct ParsedPrimaryContent: Codable {
    var educations: [ParsedEdu]
    var experiences: [ParsedExp]
}

struct ParsedSecondaryContent: Codable {
    var projects: [ParsedProj]
    var certifications: [ParsedCert]
    var organizations: [ParsedOrg]
    var achievements: [ParsedAward]
}

// Non-Codable container assembled from all partial parse results.
struct ParsedSections {
    var educations:     [ParsedEdu]
    var experiences:    [ParsedExp]
    var projects:       [ParsedProj]
    var certifications: [ParsedCert]
    var organizations:  [ParsedOrg]
    var achievements:   [ParsedAward]
}

// MARK: - Service

enum CVImportService {

    enum ImportError: Error, LocalizedError {
        case aiUnavailable
        case textExtractionFailed

        var errorDescription: String? {
            switch self {
            case .aiUnavailable:
                return "No model is loaded. Go to the CV Generator tab, select a model, and tap \"Load Model\" — then come back to import your CV."
            case .textExtractionFailed:
                return "Could not read the file. Make sure it's a text-based PDF (not scanned) or a .txt file."
            }
        }
    }

    // MARK: - Text extraction

    static func extractText(from url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let data = try? Data(contentsOf: url),
                  let doc  = PDFDocument(data: data) else { return nil }
            let text = (0..<doc.pageCount)
                .compactMap { doc.page(at: $0)?.string }
                .joined(separator: "\n")
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Section detection helpers (unchanged from original)

    private static let boundaryHeaders = [
        "EDUCATION", "EXPERIENCE", "WORK EXPERIENCE", "EMPLOYMENT",
        "PROJECT", "PORTFOLIO",
        "CERTIF", "LICENSE", "CREDENTIAL",
        "ORGANIZATION", "EXTRACURRICULAR", "VOLUNTEER",
        "ACHIEVEMENT", "AWARD", "HONOR",
        "PUBLICATION", "REFERENCE",
        "SUMMARY", "PROFILE", "OBJECTIVE",
        // Indonesian
        "PENDIDIKAN", "PENGALAMAN", "PEKERJAAN", "RIWAYAT",
        "PROYEK", "SERTIFIK", "ORGANISASI", "KEPANITIAAN",
        "PRESTASI", "PENGHARGAAN", "KEAHLIAN", "KEMAMPUAN", "SKILL"
    ]

    private static func isSectionBoundary(_ line: String, excluding keywords: [String]) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 1, trimmed.count < 60 else { return false }
        guard !trimmed.contains(":") else { return false }
        let upper = trimmed.uppercased()
        let letters = trimmed.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let uppercaseRatio = Double(letters.filter { $0.isUppercase }.count) / Double(letters.count)
        guard uppercaseRatio >= 0.7 else { return false }
        return boundaryHeaders.contains(where: { upper.contains($0) })
            && !keywords.contains(where: { upper.contains($0) })
    }

    private static func findSectionText(from text: String, matching keywords: [String]) -> String? {
        let lines = text.components(separatedBy: CharacterSet.newlines)
        var capturing = false
        var result: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper   = trimmed.uppercased()
            if !capturing {
                let couldBeHeader = trimmed.count > 1 && trimmed.count < 60
                if couldBeHeader && keywords.contains(where: { upper.contains($0) }) {
                    capturing = true; result.append(line)
                }
            } else {
                if isSectionBoundary(line, excluding: keywords) { break }
                result.append(line)
            }
        }
        let combined = result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }

    private static func findLabeledLines(
        from text: String,
        labelPrefixes: [String],
        requireContent: Bool = false
    ) -> String? {
        let upperPrefixes = labelPrefixes.map { $0.uppercased() }
        let matched = text.components(separatedBy: CharacterSet.newlines)
            .filter { line in
                let content = line
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-–•*·").union(.whitespaces))
                    .uppercased()
                for prefix in upperPrefixes where content.hasPrefix(prefix) {
                    if requireContent {
                        let after = String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        return !after.isEmpty
                    }
                    return true
                }
                return false
            }
        return matched.isEmpty ? nil : matched.joined(separator: "\n")
    }

    private static func slice(_ text: String, from: Int, maxLength: Int) -> String {
        String(text.dropFirst(min(from, text.count)).prefix(maxLength))
    }

    // MARK: - MLX-based parsing (Qwen3 4B)

    @MainActor
    static func parseCV(
        from text: String,
        onProgress: @MainActor @escaping (Double, String) -> Void = { _, _ in }
    ) async throws -> (ParsedBasicProfile, ParsedSections) {
        let service = MLXInferenceService.shared

        // Use whatever model is already loaded — don't force a download during import.
        // If nothing is ready, fail immediately with a clear message instead of hanging.
        guard service.isReady else { throw ImportError.aiUnavailable }

        let system = "You complete JSON templates by filling in placeholder values extracted from a resume. Copy text VERBATIM — do not generate, rephrase, or invent any information."

        onProgress(0.05, "Extracting basic info…")
        let basic = await extractBasicProfile(text: text, system: system)

        onProgress(0.4, "Extracting education & experience…")
        let primary = await extractPrimaryContent(text: text, system: system)

        onProgress(0.75, "Extracting projects & other sections…")
        // Try code-based parsing first for inline-label CVs ("- Projects: ...", "- Certifications: ...").
        // Fall back to LLM only for traditional section-header CVs.
        let secondary: ParsedSecondaryContent
        if let inline = extractInlineLabels(from: text) {
            secondary = inline
        } else {
            let secondarySource = buildSecondarySource(from: text)
            secondary = await extractSecondaryContent(text: secondarySource, system: system)
        }

        onProgress(1.0, "Done")

        let sections = ParsedSections(
            educations:     primary.educations,
            experiences:    primary.experiences,
            projects:       secondary.projects,
            certifications: secondary.certifications,
            organizations:  secondary.organizations,
            achievements:   secondary.achievements
        )
        return (basic, sections)
    }

    // MARK: - Individual extraction calls

    private static func extractBasicProfile(text: String, system: String) async -> ParsedBasicProfile {
        let prompt = """
            Complete this JSON template with the candidate's basic info. \
            Use "" for missing fields, [] for missing arrays:
            {"name":"...","email":"...","phone":"...","address":"...","summary":"...","skills":["skill1","skill2"],"links":[{"label":"LinkedIn","url":"..."}]}

            Rules:
            - summary: professional summary/objective paragraph. Empty string if absent.
            - skills: every individual skill listed (1-5 words each).
            - links: only include entries that have a real URL.

            Resume:
            \(slice(text, from: 0, maxLength: 2500))

            Completed JSON:
            """
        let raw = (try? await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 600)) ?? ""
        return (try? MLXInferenceService.decode(ParsedBasicProfile.self, from: raw))
            ?? ParsedBasicProfile(name: "", email: "", phone: "", address: "", summary: "", skills: [], links: [])
    }

    private static func extractPrimaryContent(text: String, system: String) async -> ParsedPrimaryContent {
        // Focus on the relevant sections — reduces context and improves extraction accuracy
        let eduSection = findSectionText(from: text, matching: ["EDUCATION", "ACADEMIC", "PENDIDIKAN", "RIWAYAT PENDIDIKAN"])
        let expSection = findSectionText(from: text, matching: ["EXPERIENCE", "EMPLOYMENT", "WORK", "PENGALAMAN", "PEKERJAAN", "RIWAYAT KERJA"])
        var parts: [String] = []
        if let s = eduSection { parts.append(s) }
        if let s = expSection { parts.append(s) }
        let source = parts.isEmpty ? slice(text, from: 0, maxLength: 4000)
                   : parts.joined(separator: "\n\n").prefix(4000).description

        let prompt = """
            Complete this JSON template with ALL education and work experience from the resume. \
            The template shows 2 examples — add more objects for each additional entry found. Use [] if none found:
            {"educations":[{"institution":"...","degree":"...","field":"...","startYear":"...","endYear":"...","gpa":""},{"institution":"...","degree":"...","field":"...","startYear":"...","endYear":"...","gpa":""}],"experiences":[{"company":"...","role":"...","startDate":"...","endDate":"...","location":"","highlights":["...","..."]},{"company":"...","role":"...","startDate":"...","endDate":"...","location":"","highlights":["..."]}]}

            Rules:
            - educations: formal university/college degrees ONLY (Bachelor, Master, PhD, Diploma). Not bootcamps.
            - experiences: ALL jobs, internships, part-time, freelance work.
            - Copy highlight bullets VERBATIM. If no bullets for an entry, use [].
            - Include EVERY entry — do not stop after 1 or 2.

            Resume:
            \(source)

            Completed JSON:
            """
        let raw = (try? await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 1200)) ?? ""
        return (try? MLXInferenceService.decode(ParsedPrimaryContent.self, from: raw))
            ?? ParsedPrimaryContent(educations: [], experiences: [])
    }

    private static func extractSecondaryContent(text: String, system: String) async -> ParsedSecondaryContent {
        let prompt = """
            Complete this JSON template using the resume content below. \
            The template shows 2 examples per section — add more objects for each additional entry. Use [] if a section is absent:
            {"projects":[{"name":"...","role":"...","techStack":"...","highlights":["..."]},{"name":"...","role":"...","techStack":"","highlights":[]}],"certifications":[{"name":"...","issuer":"...","issueDate":"...","credentialURL":""},{"name":"...","issuer":"...","issueDate":"...","credentialURL":""}],"organizations":[{"name":"...","role":"...","startDate":"...","endDate":"..."},{"name":"...","role":"...","startDate":"...","endDate":"..."}],"achievements":[{"title":"...","issuer":"...","date":"...","notes":""},{"title":"...","issuer":"...","date":"...","notes":""}]}

            - projects: coded software, apps, or tech tools
            - certifications: certificates (name, issuer, year)
            - organizations: clubs, committees, volunteer groups
            - achievements: competition wins, scholarships, exchange programs
            Include EVERY entry — do not stop after 1 or 2.

            Resume:
            \(text)

            Completed JSON:
            """
        let raw = (try? await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 1400)) ?? ""
        return (try? MLXInferenceService.decode(ParsedSecondaryContent.self, from: raw))
            ?? ParsedSecondaryContent(projects: [], certifications: [], organizations: [], achievements: [])
    }

    // Builds the best source text for secondary section extraction.
    // Handles both traditional CVs (standalone section headers) and
    // compact CVs (inline labels like "- Certifications: Oracle Java SE 8 (2023)").
    private static func buildSecondarySource(from text: String) -> String {
        // Traditional section-header format
        let projSection  = findSectionText(from: text, matching: ["PROJECT", "PORTFOLIO", "PROYEK"])
        let certSection  = findSectionText(from: text, matching: ["CERTIF", "LICENSE", "CREDENTIAL", "SERTIFIK"])
        let orgSection   = findSectionText(from: text, matching: ["ORGANIZATION", "EXTRACURRICULAR", "VOLUNTEER", "ORGANISASI", "KEPANITIAAN", "UKM"])
        let awardSection = findSectionText(from: text, matching: ["ACHIEVEMENT", "AWARD", "HONOR", "PRESTASI", "PENGHARGAAN"])

        // Inline-label format: "- Certifications: ...", "- Projects: ..." etc.
        let inlineCert  = findLabeledLines(from: text, labelPrefixes: [
            "Certifications:", "Certification:", "Sertifikasi:", "Sertifikat:"])
        let inlineProj  = findLabeledLines(from: text, labelPrefixes: [
            "Projects:", "Project:", "Proyek:"])
        let inlineOrg   = findLabeledLines(from: text, labelPrefixes: [
            "Organizations:", "Organization:", "Extracurricular:", "Volunteer:",
            "Organisasi:", "Kepanitiaan:", "UKM:"])
        let inlineAward = findLabeledLines(from: text, labelPrefixes: [
            "Competitions:", "Competition:", "Scholarship:", "Scholarships:",
            "Exchange Programs:", "Exchange Program:", "Award:", "Awards:",
            "Achievement:", "Achievements:", "Prestasi:", "Penghargaan:", "Beasiswa:"])

        var parts: [String] = []
        for s in [projSection, certSection, orgSection, awardSection,
                  inlineProj, inlineCert, inlineOrg, inlineAward].compactMap({ $0 }) {
            if !parts.contains(s) { parts.append(s) }
        }
        // Fallback: second half of resume (secondary sections usually appear there)
        if parts.isEmpty {
            let midpoint = max(0, text.count / 2)
            parts.append(slice(text, from: midpoint, maxLength: 3500))
        }
        return parts.joined(separator: "\n\n").prefix(4000).description
    }

    // MARK: - Code-based inline-label parser (no LLM, fast)
    // Handles CVs that use "- Label: content" lines instead of section headers.
    // Supports both single-item lines ("- Projects: Artha, desc (2025)") and
    // multi-item lines ("- Projects: Wikan (2025), Lumi (2025), Paintee (2025)").

    // Known inline-label prefixes — used as entry boundaries even when no bullet is present.
    private static let inlineLabelPrefixes: [String] = [
        "certifications:", "certification:", "sertifikasi:", "sertifikat:",
        "projects:", "project:", "proyek:",
        "organizations:", "organization:", "organisasi:", "kepanitiaan:",
        "extracurricular:", "volunteer:", "volunteering:", "ukm:",
        "competitions:", "competition:", "scholarship:", "scholarships:",
        "exchange programs:", "exchange program:", "award:", "awards:",
        "achievement:", "achievements:", "prestasi:", "penghargaan:", "beasiswa:",
        "technical skills:", "interpersonal skills:", "languages:", "skills:",
        "keahlian:", "kemampuan:"
    ]

    // Merges PDF line-wrap continuations onto their parent labeled line.
    // A line is a continuation only when it is NOT a known label and NOT bullet-prefixed.
    // e.g. "- Projects: Wikan (2025), Klincong\n(2025), Siphiko (2025)"
    //   → "- Projects: Wikan (2025), Klincong (2025), Siphiko (2025)"
    private static func mergeInlineLabelContinuations(_ text: String) -> String {
        let bulletChars = CharacterSet(charactersIn: "-\u{2013}•*·\u{25AA}\u{25B8}")
        var merged: [String] = []
        for line in text.components(separatedBy: CharacterSet.newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let cleaned = trimmed.trimmingCharacters(in: bulletChars.union(.whitespaces)).lowercased()
            let hasBullet = trimmed.unicodeScalars.first.map { bulletChars.contains($0) } ?? false
            let isKnownLabel = inlineLabelPrefixes.contains(where: { cleaned.hasPrefix($0) })
            if trimmed.isEmpty || hasBullet || isKnownLabel || merged.isEmpty {
                merged.append(line)
            } else {
                merged[merged.count - 1] += " " + trimmed
            }
        }
        return merged.joined(separator: "\n")
    }

    @MainActor
    private static func extractInlineLabels(from text: String) -> ParsedSecondaryContent? {
        let mergedText = mergeInlineLabelContinuations(text)

        let certPrefixes  = ["Certifications:", "Certification:", "Sertifikasi:", "Sertifikat:"]
        let projPrefixes  = ["Projects:", "Project:", "Proyek:"]
        let orgPrefixes   = ["Organizations:", "Organization:", "Organisasi:", "Kepanitiaan:",
                             "Extracurricular:", "Volunteer:", "Volunteering:", "UKM:"]
        let awardPrefixes = ["Competitions:", "Competition:", "Scholarship:", "Scholarships:",
                             "Exchange Programs:", "Exchange Program:", "Award:", "Awards:",
                             "Achievement:", "Achievements:",
                             "Prestasi:", "Penghargaan:", "Beasiswa:"]

        // requireContent: true so bare section headers like "Projects:" don't match —
        // only actual inline entries with content after the colon do.
        let certLines  = findLabeledLines(from: mergedText, labelPrefixes: certPrefixes,  requireContent: true)
        let projLines  = findLabeledLines(from: mergedText, labelPrefixes: projPrefixes,  requireContent: true)
        let orgLines   = findLabeledLines(from: mergedText, labelPrefixes: orgPrefixes,   requireContent: true)
        let awardLines = findLabeledLines(from: mergedText, labelPrefixes: awardPrefixes, requireContent: true)

        guard certLines != nil || projLines != nil || awardLines != nil else { return nil }

        let certs  = parseInlineLines(certLines,  prefixes: certPrefixes,  parse: parseCertItems)
        let projs  = parseInlineLines(projLines,  prefixes: projPrefixes,  parse: parseProjItems)
        let orgs   = parseInlineLines(orgLines,   prefixes: orgPrefixes,   parse: parseOrgItems)
        let awards = parseInlineLines(awardLines, prefixes: awardPrefixes, parse: parseAwardItems)

        return ParsedSecondaryContent(projects: projs, certifications: certs, organizations: orgs, achievements: awards)
    }

    // Strips the label prefix from each matched line, then flatMaps parse results.
    @MainActor
    private static func parseInlineLines<T>(_ joined: String?, prefixes: [String], parse: (String) -> [T]) -> [T] {
        guard let joined else { return [] }
        return joined.components(separatedBy: "\n").flatMap { line -> [T] in
            let stripped = line
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-–•*·▪▸").union(.whitespaces))
            for prefix in prefixes where stripped.lowercased().hasPrefix(prefix.lowercased()) {
                let content = String(stripped.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return parse(content)
            }
            return []
        }
    }

    // Splits "A (2025), B (National, 2024), C (2023)" into individual items.
    // Detects any parenthesised group "(…)" that contains a 4-digit year anywhere inside.
    // Handles both "(YYYY)" and "(Location, YYYY)" / "(Level, YYYY)" patterns.
    // If no year-containing groups are found, returns the whole content as one item.
    private static func splitInlineItems(_ content: String) -> [String] {
        var items: [String] = []
        var itemStart = content.startIndex
        var idx = content.startIndex

        while idx < content.endIndex {
            guard content[idx] == "(" else { idx = content.index(after: idx); continue }
            let openIdx = idx

            // Find matching ")" (first one after the "(" — no nesting support needed for CVs)
            guard let closeIdx = content[content.index(after: openIdx)...].firstIndex(of: ")") else {
                idx = content.index(after: idx); continue
            }

            // Accept only groups that contain a 4-digit year somewhere inside
            let inside = String(content[content.index(after: openIdx)..<closeIdx])
            let hasYear = inside
                .components(separatedBy: CharacterSet(charactersIn: " ,;-"))
                .contains(where: { $0.count == 4 && $0.allSatisfy(\.isNumber) })

            guard hasYear else { idx = content.index(after: idx); continue }

            // Capture everything from itemStart up to and including the closing ")"
            let closeAfter = content.index(after: closeIdx)
            let item = String(content[itemStart..<closeAfter]).trimmingCharacters(in: .whitespaces)
            if !item.isEmpty { items.append(item) }

            // Skip separator: ", " or " " after ")"
            var next = closeAfter
            while next < content.endIndex && (content[next] == "," || content[next] == " ") {
                next = content.index(after: next)
            }
            itemStart = next
            idx = next
        }
        return items.isEmpty ? [content] : items
    }

    // Returns (textBeforeLastParenGroup, fourDigitYear).
    // "Data Analytics by Cisco (2024)" → ("Data Analytics by Cisco", "2024")
    private static func extractTrailingYear(_ text: String) -> (String, String) {
        guard let closeIdx = text.lastIndex(of: ")"),
              let openIdx  = text[..<closeIdx].lastIndex(of: "(") else { return (text, "") }
        let inside = String(text[text.index(after: openIdx)..<closeIdx])
        let year   = inside
            .components(separatedBy: CharacterSet(charactersIn: " ,;-"))
            .first(where: { $0.count == 4 && $0.allSatisfy(\.isNumber) }) ?? ""
        let before = String(text[..<openIdx]).trimmingCharacters(in: .whitespaces)
        return (before, year)
    }

    // "AIML (2025) Cloud Engineer (2023), Frontend Ruangguru (2022)" → [ParsedCert, ...]
    private static func parseCertItems(_ content: String) -> [ParsedCert] {
        splitInlineItems(content).compactMap { item in
            guard !item.isEmpty else { return nil }
            let (withoutYear, year) = extractTrailingYear(item)
            var name   = withoutYear
            var issuer = ""
            if let byRange = withoutYear.range(of: " by ", options: .caseInsensitive) {
                name   = String(withoutYear[..<byRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                issuer = String(withoutYear[byRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            return ParsedCert(name: name, issuer: issuer, issueDate: year, credentialURL: "")
        }
    }

    // "Wikan (2025), Lumi (2025)" or "Artha, a budgeting app (2025)" → [ParsedProj, ...]
    private static func parseProjItems(_ content: String) -> [ParsedProj] {
        splitInlineItems(content).compactMap { item in
            guard !item.isEmpty else { return nil }
            let (withoutYear, _) = extractTrailingYear(item)
            var name        = withoutYear
            var description = ""
            // Only treat first ", " as name/description separator when there's a single item
            // (multi-item lines: each item is just a name, so no description splitting)
            if let commaRange = withoutYear.range(of: ", ") {
                let candidate = String(withoutYear[..<commaRange.lowerBound])
                // If the candidate name is short (≤ 40 chars), treat it as name + description
                if candidate.count <= 40 {
                    name        = candidate.trimmingCharacters(in: .whitespaces)
                    description = String(withoutYear[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }
            return ParsedProj(name: name, role: "Personal", techStack: "", highlights: description.isEmpty ? [] : [description])
        }
    }

    // "Global Competence (2021), Community Service (2024)" → [ParsedOrg, ...]
    private static func parseOrgItems(_ content: String) -> [ParsedOrg] {
        splitInlineItems(content).compactMap { item in
            guard !item.isEmpty else { return nil }
            var name  = item
            var role  = ""
            var start = ""
            var end   = ""
            if let openIdx  = item.lastIndex(of: "("),
               let closeIdx = item.lastIndex(of: ")"),
               openIdx < closeIdx {
                name = String(item[..<openIdx]).trimmingCharacters(in: .whitespaces)
                let inside = String(item[item.index(after: openIdx)..<closeIdx])
                let parts  = inside.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                // If inside is a year range like "2022-2023", treat as dates not role
                if parts.count == 1, parts[0].allSatisfy({ $0.isNumber || $0 == "-" }) {
                    let yearParts = parts[0].components(separatedBy: "-")
                    start = yearParts.first ?? ""
                    end   = yearParts.last ?? ""
                } else {
                    role = parts.first ?? ""
                    if parts.count >= 2 {
                        let yearParts = (parts.last ?? "").components(separatedBy: "-")
                        start = yearParts.first?.trimmingCharacters(in: .whitespaces) ?? ""
                        end   = yearParts.last?.trimmingCharacters(in: .whitespaces) ?? ""
                    }
                }
            }
            return ParsedOrg(name: name, role: role, startDate: start, endDate: end)
        }
    }

    // "1st Winner (2023), Scholarship at X (2024)" → [ParsedAward, ...]
    private static func parseAwardItems(_ content: String) -> [ParsedAward] {
        splitInlineItems(content).compactMap { item in
            guard !item.isEmpty else { return nil }
            let (withoutYear, year) = extractTrailingYear(item)
            var title  = withoutYear
            var issuer = ""
            for dash in [" – ", " — ", " - "] {
                if let dashRange = withoutYear.range(of: dash) {
                    title  = String(withoutYear[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    issuer = String(withoutYear[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            return ParsedAward(title: title, issuer: issuer, date: year, notes: "")
        }
    }

    // MARK: - Map parsed output → domain models (unchanged)

    static func apply(
        basic: ParsedBasicProfile,
        sections: ParsedSections,
        preservingPhoto photoData: Data?
    ) -> (UserProfile, CVData) {
        let profile = UserProfile(
            name:      basic.name,
            email:     basic.email,
            phone:     basic.phone,
            address:   basic.address,
            skills:    basic.skills.filter { !$0.isEmpty },
            summary:   basic.summary,
            links:     basic.links.map { ProfileLink(label: $0.label, url: $0.url) },
            photoData: photoData
        )
        let cvData = CVData(
            profile: profile,
            educations: sections.educations.map {
                Education(
                    institution: $0.institution, degree: $0.degree,
                    fieldOfStudy: $0.field, startYear: $0.startYear,
                    year: $0.endYear, gpa: $0.gpa
                )
            },
            experiences: sections.experiences.map {
                WorkExperience(
                    company: $0.company, role: $0.role,
                    startDate: $0.startDate, duration: $0.endDate,
                    location: $0.location,
                    highlights: $0.highlights.filter { !$0.isEmpty }
                )
            },
            projects: sections.projects.map {
                Project(
                    name: $0.name, role: $0.role, techStack: $0.techStack,
                    highlights: $0.highlights.filter { !$0.isEmpty }
                )
            },
            certifications: sections.certifications.map {
                Certification(
                    name: $0.name, issuer: $0.issuer,
                    issueDate: $0.issueDate, credentialURL: $0.credentialURL
                )
            },
            organizations: sections.organizations.map {
                Organization(
                    name: $0.name, role: $0.role,
                    startDate: $0.startDate, endDate: $0.endDate
                )
            },
            achievements: sections.achievements.map {
                Achievement(title: $0.title, issuer: $0.issuer, date: $0.date, notes: $0.notes)
            }
        )
        return (profile, cvData)
    }
}
