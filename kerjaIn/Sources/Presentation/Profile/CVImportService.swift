import Foundation
import PDFKit
import FoundationModels

// MARK: - Call 1: Basic profile info (name, contact, skills, summary, links)

@available(macOS 26.0, *)
@Generable(description: "A profile link from a CV, e.g. LinkedIn or GitHub")
struct ParsedLink {
    @Guide(description: "Short label, e.g. LinkedIn, GitHub, Portfolio")
    var label: String
    @Guide(description: "Full URL")
    var url: String
}

@available(macOS 26.0, *)
@Generable(description: "Basic candidate info extracted from a resume")
struct ParsedBasicProfile {
    @Guide(description: "Candidate's full name")
    var name: String
    @Guide(description: "Email address")
    var email: String
    @Guide(description: "Phone number")
    var phone: String
    @Guide(description: "City or full address")
    var address: String
    @Guide(description: "Professional summary or objective paragraph. Empty string if absent.")
    var summary: String
    @Guide(description: "All skills listed (each 1–4 words)")
    var skills: [String]
    @Guide(description: "Online profile links (LinkedIn, GitHub, portfolio, etc.)")
    var links: [ParsedLink]
}

// MARK: - Call 2: CV sections (experience, education, projects, extras)

@available(macOS 26.0, *)
@Generable(description: "One education entry")
struct ParsedEdu {
    @Guide(description: "University or school name")
    var institution: String
    @Guide(description: "Degree, e.g. Bachelor of Science")
    var degree: String
    @Guide(description: "Major or field of study")
    var field: String
    @Guide(description: "Start year, e.g. 2019. Empty if not shown.")
    var startYear: String
    @Guide(description: "Graduation year or Present")
    var endYear: String
    @Guide(description: "GPA if shown, e.g. 3.85. Empty if not shown.")
    var gpa: String
}

@available(macOS 26.0, *)
@Generable(description: "One work experience entry")
struct ParsedExp {
    @Guide(description: "Company name")
    var company: String
    @Guide(description: "Job title")
    var role: String
    @Guide(description: "Start date, e.g. Jan 2022")
    var startDate: String
    @Guide(description: "End date or Present")
    var endDate: String
    @Guide(description: "Location if shown, otherwise empty string")
    var location: String
    @Guide(description: "Bullet points verbatim from the CV")
    var highlights: [String]
}

@available(macOS 26.0, *)
@Generable(description: "One project entry")
struct ParsedProj {
    @Guide(description: "Project name")
    var name: String
    @Guide(description: "Role in the project. Empty if not specified.")
    var role: String
    @Guide(description: "Technologies used, comma-separated")
    var techStack: String
    @Guide(description: "Description bullet points verbatim")
    var highlights: [String]
}

@available(macOS 26.0, *)
@Generable(description: "One certification")
struct ParsedCert {
    @Guide(description: "Certification name")
    var name: String
    @Guide(description: "Issuing organization")
    var issuer: String
    @Guide(description: "Issue date, e.g. Jun 2023. Empty if not shown.")
    var issueDate: String
    @Guide(description: "Credential URL if shown, otherwise empty string")
    var credentialURL: String
}

@available(macOS 26.0, *)
@Generable(description: "One organization or extracurricular activity")
struct ParsedOrg {
    @Guide(description: "Organization name")
    var name: String
    @Guide(description: "Role held")
    var role: String
    @Guide(description: "Start date")
    var startDate: String
    @Guide(description: "End date or Present")
    var endDate: String
}

@available(macOS 26.0, *)
@Generable(description: "One award or achievement")
struct ParsedAward {
    @Guide(description: "Award title")
    var title: String
    @Guide(description: "Issuing organization or event")
    var issuer: String
    @Guide(description: "Year or date received")
    var date: String
    @Guide(description: "Brief description. Empty if not shown.")
    var notes: String
}

// Each secondary section gets its own tiny single-array schema.
// Smaller schema = more room for text within the on-device context window.

@available(macOS 26.0, *)
@Generable(description: "Education and work experience from a CV")
struct ParsedPrimaryContent {
    @Guide(description: "Education history, most recent first")
    var educations: [ParsedEdu]
    @Guide(description: "Work experience, most recent first")
    var experiences: [ParsedExp]
}

@available(macOS 26.0, *)
@Generable(description: "Projects extracted from a CV section")
struct ParsedProjectList {
    @Guide(description: "All projects in this section")
    var projects: [ParsedProj]
}

@available(macOS 26.0, *)
@Generable(description: "Certifications extracted from a CV section")
struct ParsedCertList {
    @Guide(description: "All certifications and licenses in this section")
    var certifications: [ParsedCert]
}

@available(macOS 26.0, *)
@Generable(description: "Organizations extracted from a CV section")
struct ParsedOrgList {
    @Guide(description: "All organizations and extracurriculars in this section")
    var organizations: [ParsedOrg]
}

@available(macOS 26.0, *)
@Generable(description: "Awards and achievements extracted from a CV section")
struct ParsedAwardList {
    @Guide(description: "All awards and achievements in this section")
    var achievements: [ParsedAward]
}

@available(macOS 26.0, *)
@Generable(description: "Skills extracted from a CV section")
struct ParsedSkillsList {
    @Guide(description: "All individual skills (1–5 words each)")
    var skills: [String]
}

// Non-@Generable container assembled from all partial parse results.
struct ParsedSections {
    var educations:     [ParsedEdu]
    var experiences:    [ParsedExp]
    var projects:       [ParsedProj]
    var certifications: [ParsedCert]
    var organizations:  [ParsedOrg]
    var achievements:   [ParsedAward]
}

// MARK: - Service

@available(macOS 26.0, *)
enum CVImportService {

    enum ImportError: Error, LocalizedError {
        case aiUnavailable
        case textExtractionFailed
        case unsupportedLanguage
        case parseFailed(String)

        var errorDescription: String? {
            switch self {
            case .aiUnavailable:
                return "Apple Intelligence is required for CV import. Enable it in System Settings → Apple Intelligence & Siri."
            case .textExtractionFailed:
                return "Could not read the file. Make sure it's a text-based PDF (not scanned) or a .txt file."
            case .unsupportedLanguage:
                return "Apple Intelligence couldn't process the CV text. This can happen when the document contains institution or company names in an unsupported language.\n\nTip: Try converting your CV to plain text (.txt) first, or remove non-English institution names before importing."
            case .parseFailed(let msg):
                return "Parsing failed: \(msg)"
            }
        }
    }

    // Force en_US locale in all sessions — the device may be set to an unsupported locale
    // (e.g. Indonesian), and passing the device locale would make the model try to respond
    // in that language, triggering unsupportedLanguageOrLocale.
    private static let localeInstruction = "The person's locale is en_US. "

    // MARK: - Text extraction
    // Uses Data(contentsOf:) + PDFDocument(data:) to safely read inside async context

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

    // MARK: - Section-based LLM parsing

    // Major CV section keywords used ONLY for boundary detection (not for search).
    // Kept minimal on purpose — generic words like "SKILL", "TECHNOLOGY", "LANGUAGE"
    // are intentionally excluded because they appear inside project/experience sub-items
    // (e.g. "Technology: Swift") and would cause false section boundaries.
    private static let boundaryHeaders = [
        "EDUCATION", "EXPERIENCE", "WORK EXPERIENCE", "EMPLOYMENT",
        "PROJECT", "PORTFOLIO",
        "CERTIF", "LICENSE", "CREDENTIAL",
        "ORGANIZATION", "EXTRACURRICULAR", "VOLUNTEER",
        "ACHIEVEMENT", "AWARD", "HONOR",
        "PUBLICATION", "REFERENCE",
        "SUMMARY", "PROFILE", "OBJECTIVE"
    ]

    // Returns true only for lines that look like a CV section header:
    //   • Short (2–60 chars), no colon (rules out "Technology: Swift")
    //   • Mostly uppercase (CV headers are typically ALL CAPS)
    //   • Matches one of the major boundary keywords
    private static func isSectionBoundary(_ line: String, excluding keywords: [String]) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 1, trimmed.count < 60 else { return false }
        guard !trimmed.contains(":") else { return false }           // label lines have colons
        let upper = trimmed.uppercased()
        // Must be ≥ 70% uppercase letters (ignores punctuation / spaces)
        let letters = trimmed.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let uppercaseRatio = Double(letters.filter { $0.isUppercase }.count) / Double(letters.count)
        guard uppercaseRatio >= 0.7 else { return false }
        return boundaryHeaders.contains(where: { upper.contains($0) })
            && !keywords.contains(where: { upper.contains($0) })
    }

    // Extracts the text block of a specific CV section identified by header keywords.
    // Stops at the next recognised section header so only that section's content is returned.
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
                    capturing = true
                    result.append(line)
                }
            } else {
                if isSectionBoundary(line, excluding: keywords) { break }
                result.append(line)
            }
        }

        let combined = result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }

    // Safe substring slice by character offset.
    private static func slice(_ text: String, from: Int, maxLength: Int) -> String {
        String(text.dropFirst(min(from, text.count)).prefix(maxLength))
    }

    // Collects every line whose content (after stripping leading bullet/dash chars) starts
    // with one of the given prefixes followed by a colon — e.g. "Projects:" or "Certifications:".
    // This handles the "repeated-label" inline format where the same label appears on multiple
    // lines and findSectionText cannot detect the lines as section headers (they're too long or
    // contain colons). Returns nil when no matching lines are found.
    private static func findLabeledLines(from text: String, labelPrefixes: [String]) -> String? {
        let upperPrefixes = labelPrefixes.map { $0.uppercased() }
        let matched = text
            .components(separatedBy: CharacterSet.newlines)
            .filter { line in
                let content = line
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-–•*·").union(.whitespaces))
                    .uppercased()
                return upperPrefixes.contains(where: { content.hasPrefix($0) })
            }
        return matched.isEmpty ? nil : matched.joined(separator: "\n")
    }

    static func parseCV(from text: String) async throws -> (ParsedBasicProfile, ParsedSections) {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw ImportError.aiUnavailable
        }

        // Strategy:
        //   Session 1  — basic info (top 3000 chars) → ParsedBasicProfile
        //   Session 2a — education + experience (top 4000 chars) → ParsedPrimaryContent
        //   Sessions 2b–2e — one session per secondary section, each receiving ONLY the
        //     text of that section (extracted by header matching). Single-array schemas
        //     keep per-call token usage low and avoid context window overflow entirely.

        do {
            let locale = localeInstruction
            let cvPrefix = "This is an English-language CV/resume. It may contain institution or company names as proper nouns in other languages. "

            // Session 1: basic profile
            let session1 = LanguageModelSession(instructions: """
                \(locale)You are a CV parser. You MUST respond in U.S. English.
                Extract only the basic contact information, skills list,
                professional summary, and profile links from the resume.
                Do not invent any information not present in the text.
                Use empty string or empty array for absent fields.
                """)
            let basic = try await session1.respond(
                to: "\(cvPrefix)Extract the basic profile info:\n\n\(slice(text, from: 0, maxLength: 3000))",
                generating: ParsedBasicProfile.self
            ).content

            // Session 2a: education + experience
            let session2a = LanguageModelSession(instructions: """
                \(locale)You are a CV parser. You MUST respond in U.S. English.
                Extract education and work experience from the resume using these strict rules:
                - educations: ONLY formal university/college degrees (Bachelor, Master, PhD, Diploma). Do NOT include academies, bootcamps, training programs, or courses.
                - experiences: ALL jobs, internships, part-time roles, freelance work, and any program where the person held an active role.
                Do not invent any information. Preserve bullet points verbatim. Use empty arrays if absent.
                """)
            let primary = try await session2a.respond(
                to: "\(cvPrefix)Extract education and work experience:\n\n\(slice(text, from: 0, maxLength: 4000))",
                generating: ParsedPrimaryContent.self
            ).content

            // Sessions 2b–2e: one session per secondary section type.
            //
            // Each session uses a two-tier source strategy:
            //   1. Prefer the text of a dedicated section found by header matching
            //      (e.g. a standalone "PROJECTS" section in standard CVs).
            //   2. Fall back to the secondary slice of the full CV when no dedicated header
            //      exists — e.g. CVs that list everything inline inside a combined section
            //      like "HONORS, AWARDS & SKILLS" with bullets "- Projects: A, B, C".
            //
            // The inline-format note in each instruction teaches the model to handle both
            // the structured (one-entry-per-line) AND inline (comma-separated list) styles.

            // Fallback sources in priority order:
            //   1. Dedicated section (e.g. standalone "PROJECTS" header)
            //   2. Combined section containing multiple types (e.g. "HONORS, AWARDS & SKILLS")
            //   3. Raw secondary slice of the CV text
            // Fallback priority: dedicated section → combined section → raw secondary slice.
            // Combined section catches CVs that merge everything under one header
            // like "HONORS, AWARDS & SKILLS".
            let combinedSection = findSectionText(from: text, matching: ["HONOR", "AWARD", "ADDITIONAL", "MISCELLANEOUS"])
            let secondarySlice  = slice(text, from: 2500, maxLength: 3000)

            // Two inline formats appear in combined CV sections:
            //   Format A — same label repeated, ONE item per line (do NOT split within a line):
            //     "- Projects: Artha, a financial budgeting app (2025)"
            //     "- Projects: MoNaik, a fitness app (2025)"
            //   Format B — all items on ONE line, comma-separated:
            //     "- Projects: Name1 (2025), Name2 (2025), Name3 (2024)"
            // The model must distinguish these: in Format A the full text after the colon is
            // ONE item; in Format B each comma-separated token is a separate item.
            let inlineNote = """
                The source may use Format A (same label on multiple separate lines — \
                each line is ONE entry, do NOT split on commas within a single line) \
                OR Format B (all items on one line separated by commas — split each \
                comma-separated item into a separate entry). \
                Determine which format is used from context before extracting.
                """

            var allProjects: [ParsedProj]  = []
            var allCerts:    [ParsedCert]  = []
            var allOrgs:     [ParsedOrg]   = []
            var allAwards:   [ParsedAward] = []

            // Three-tier source for each secondary section type:
            //   1. findSectionText  — dedicated section header (standard CV format)
            //   2. findLabeledLines — grep all lines with the label prefix (inline/combined format)
            //   3. combinedSection / secondarySlice — last-resort full-block fallback

            let projSource = findSectionText(from: text, matching: ["PROJECT", "PORTFOLIO"])
                ?? findLabeledLines(from: text, labelPrefixes: ["Projects:", "Project:"])
                ?? combinedSection ?? secondarySlice
            let sProj = LanguageModelSession(instructions: "\(locale)You are a CV parser. You MUST respond in U.S. English. Extract all projects. Use empty array if none found.")
            if let r = try? await sProj.respond(to: "\(cvPrefix)Extract all projects:\n\n\(projSource)", generating: ParsedProjectList.self).content {
                allProjects = r.projects
            }

            let certSource = findSectionText(from: text, matching: ["CERTIF", "LICENSE", "CREDENTIAL"])
                ?? findLabeledLines(from: text, labelPrefixes: ["Certifications:", "Certification:", "License:"])
                ?? combinedSection ?? secondarySlice
            let sCert = LanguageModelSession(instructions: "\(locale)You are a CV parser. You MUST respond in U.S. English. Extract all certifications and licenses. Use empty array if none found.")
            if let r = try? await sCert.respond(to: "\(cvPrefix)Extract all certifications:\n\n\(certSource)", generating: ParsedCertList.self).content {
                allCerts = r.certifications
            }

            let orgSource = findSectionText(from: text, matching: ["ORGANIZATION", "EXTRACURRICULAR", "VOLUNTEER"])
                ?? findLabeledLines(from: text, labelPrefixes: ["Organizations:", "Organization:", "Volunteering:", "Volunteer:", "Extracurricular:"])
                ?? combinedSection ?? secondarySlice
            let sOrg = LanguageModelSession(instructions: "\(locale)You are a CV parser. You MUST respond in U.S. English. Volunteering also counts as organizations. Extract all organizations and extracurriculars. Use empty array if none found.")
            if let r = try? await sOrg.respond(to: "\(cvPrefix)Extract all organizations and volunteering:\n\n\(orgSource)", generating: ParsedOrgList.self).content {
                allOrgs = r.organizations
            }

            let awardSource = findSectionText(from: text, matching: ["ACHIEVEMENT", "AWARD", "HONOR", "RECOGNITION"])
                ?? findLabeledLines(from: text, labelPrefixes: ["Competitions:", "Competition:", "Achievement:", "Achievements:", "Exchange Programs:", "Exchange Program:", "Scholarship:", "Scholarships:"])
                ?? combinedSection ?? secondarySlice
            let sAward = LanguageModelSession(instructions: "\(locale)You are a CV parser. You MUST respond in U.S. English. Competitions, scholarships, and exchange programs also count as achievements. Extract all awards and achievements. Use empty array if none found.")
            if let r = try? await sAward.respond(to: "\(cvPrefix)Extract all awards, competitions, scholarships, and achievements:\n\n\(awardSource)", generating: ParsedAwardList.self).content {
                allAwards = r.achievements
            }

            // Skills fallback: session 1 uses top 3000 chars; skills listed inside a combined
            // section at the bottom of the CV (e.g. "Technical Skills: SwiftUI, UIKit...") are
            // missed. If session 1 found no skills, run a dedicated skills extraction session.
            var mutableBasic = basic
            if mutableBasic.skills.isEmpty {
                let skillSource = findSectionText(from: text, matching: ["TECHNICAL SKILL", "INTERPERSONAL SKILL"])
                    ?? combinedSection ?? secondarySlice
                let sSkills = LanguageModelSession(instructions: """
                    \(locale)You are a CV parser. You MUST respond in U.S. English.
                    Extract all individual skills from lines labeled "Technical Skills:", \
                    "Interpersonal Skills:", "Skills:", or similar. \
                    Split comma-separated skill lists into individual short entries (1–5 words each).
                    Use empty array if none found.
                    """)
                if let r = try? await sSkills.respond(to: "\(cvPrefix)Extract all skills:\n\n\(skillSource)", generating: ParsedSkillsList.self).content {
                    mutableBasic.skills = r.skills.filter { !$0.isEmpty }
                }
            }

            let sections = ParsedSections(
                educations:     primary.educations,
                experiences:    primary.experiences,
                projects:       allProjects,
                certifications: allCerts,
                organizations:  allOrgs,
                achievements:   allAwards
            )
            return (mutableBasic, sections)

        } catch let e as ImportError {
            throw e
        } catch let e as LanguageModelSession.GenerationError {
            switch e {
            case .unsupportedLanguageOrLocale:
                throw ImportError.unsupportedLanguage
            case .exceededContextWindowSize:
                throw ImportError.parseFailed("A CV section is too large for the on-device model. Try shortening that section and importing again.")
            default:
                throw ImportError.parseFailed(e.localizedDescription)
            }
        } catch {
            throw ImportError.parseFailed(error.localizedDescription)
        }
    }

    // MARK: - Map parsed output → domain models

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
