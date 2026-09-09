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

    private static func findLabeledLines(from text: String, labelPrefixes: [String]) -> String? {
        let upperPrefixes = labelPrefixes.map { $0.uppercased() }
        let matched = text.components(separatedBy: CharacterSet.newlines)
            .filter { line in
                let content = line
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-–•*·").union(.whitespaces))
                    .uppercased()
                return upperPrefixes.contains(where: { content.hasPrefix($0) })
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
        let secondarySource = buildSecondarySource(from: text)
        let secondary = await extractSecondaryContent(text: secondarySource, system: system)

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
            Extract ALL education and work experience entries from the resume sections below.
            Output this JSON — the template shows 2 examples, add more objects for each additional entry found:
            {"educations":[{"institution":"UNIVERSITY_1","degree":"DEGREE_1","field":"MAJOR_1","startYear":"2018","endYear":"2022","gpa":""},{"institution":"UNIVERSITY_2","degree":"DEGREE_2","field":"MAJOR_2","startYear":"2015","endYear":"2019","gpa":"3.5"}],"experiences":[{"company":"COMPANY_1","role":"ROLE_1","startDate":"Jan 2022","endDate":"Present","location":"","highlights":["bullet 1","bullet 2"]},{"company":"COMPANY_2","role":"ROLE_2","startDate":"Jun 2020","endDate":"Dec 2021","location":"","highlights":["bullet 1"]}]}

            Rules:
            - educations: ONLY formal degrees (Bachelor, Master, PhD, Diploma). NOT bootcamps or online courses.
            - experiences: ALL jobs, internships, part-time, freelance.
            - CRITICAL: Copy highlight bullets VERBATIM. If no bullets, use [].
            - Include EVERY entry found — do not stop after 1 or 2.

            Resume sections:
            \(source)

            Completed JSON:
            """
        let raw = (try? await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 1200)) ?? ""
        return (try? MLXInferenceService.decode(ParsedPrimaryContent.self, from: raw))
            ?? ParsedPrimaryContent(educations: [], experiences: [])
    }

    private static func extractSecondaryContent(text: String, system: String) async -> ParsedSecondaryContent {
        let prompt = """
            Extract ALL projects, certifications, organizations, and achievements from the resume below.
            Output this JSON — the template shows 2 examples per section, add more objects for each entry found. Use [] if a section is empty.
            {"projects":[{"name":"PROJECT_1","role":"Personal","techStack":"Swift, SwiftUI","highlights":["built X","integrated Y"]},{"name":"PROJECT_2","role":"Team Lead","techStack":"","highlights":[]}],"certifications":[{"name":"CERT_1","issuer":"ISSUER_1","issueDate":"2023","credentialURL":""},{"name":"CERT_2","issuer":"ISSUER_2","issueDate":"2022","credentialURL":""}],"organizations":[{"name":"ORG_1","role":"ROLE_1","startDate":"2021","endDate":"2023"},{"name":"ORG_2","role":"ROLE_2","startDate":"2020","endDate":"2021"}],"achievements":[{"title":"AWARD_1","issuer":"FROM_1","date":"2023","notes":""},{"title":"AWARD_2","issuer":"FROM_2","date":"2022","notes":""}]}

            Rules:
            - CRITICAL for projects: Copy name, techStack, and highlights VERBATIM. If no description bullets, set highlights []. Do NOT invent content.
            - certifications: professional certificates and licenses only.
            - organizations: clubs, volunteer, extracurricular (ORGANISASI, KEPANITIAAN, UKM).
            - achievements: awards, scholarships, competitions (PRESTASI, PENGHARGAAN).
            - Include EVERY entry found — do not stop after 1 or 2.

            Resume sections:
            \(text)

            Completed JSON:
            """
        let raw = (try? await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 1200)) ?? ""
        return (try? MLXInferenceService.decode(ParsedSecondaryContent.self, from: raw))
            ?? ParsedSecondaryContent(projects: [], certifications: [], organizations: [], achievements: [])
    }

    // Builds the best source text for secondary section extraction using the
    // same section-detection logic from the original FoundationModels version.
    private static func buildSecondarySource(from text: String) -> String {
        let projSection  = findSectionText(from: text, matching: ["PROJECT", "PORTFOLIO", "PROYEK"])
        let certSection  = findSectionText(from: text, matching: ["CERTIF", "LICENSE", "CREDENTIAL", "SERTIFIK"])
        let orgSection   = findSectionText(from: text, matching: ["ORGANIZATION", "EXTRACURRICULAR", "VOLUNTEER", "ORGANISASI", "KEPANITIAAN", "UKM"])
        let awardSection = findSectionText(from: text, matching: ["ACHIEVEMENT", "AWARD", "HONOR", "PRESTASI", "PENGHARGAAN"])
        let combined     = findSectionText(from: text, matching: ["HONOR", "AWARD", "ADDITIONAL", "MISCELLANEOUS", "LAINNYA"])

        var parts: [String] = []
        for s in [projSection, certSection, orgSection, awardSection, combined].compactMap({ $0 }) {
            if !parts.contains(s) { parts.append(s) }
        }
        if parts.isEmpty { parts.append(slice(text, from: 2500, maxLength: 3000)) }
        return parts.joined(separator: "\n\n").prefix(3500).description
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
