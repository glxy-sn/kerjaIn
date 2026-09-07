import Foundation
import FoundationModels

// MARK: - @Generable output types for each pipeline stage
// All types require macOS 26.0+ (Apple Intelligence / FoundationModels framework)

@available(macOS 26.0, *)
@Generable(description: "Requirements extracted from a job description")
struct ExtractedRequirements {
    @Guide(description: "Must-have hard skills or technologies explicitly required by the job")
    var mustHaveSkills: [String]

    @Guide(description: "Preferred or nice-to-have skills mentioned in the job description")
    var niceToHaveSkills: [String]

    @Guide(description: "The primary job title being hired for")
    var jobTitle: String
}

@available(macOS 26.0, *)
@Generable(description: "How well the candidate's profile covers a requirement")
enum MatchStatus {
    case matched  // profile clearly demonstrates this
    case partial  // profile shows indirect or limited evidence
    case missing  // profile has no evidence of this
}

@available(macOS 26.0, *)
@Generable(description: "Match result for one requirement")
struct RequirementMatchItem {
    @Guide(description: "The requirement text (1–5 words)")
    var requirement: String

    @Guide(description: "Match status: matched, partial, or missing")
    var status: MatchStatus
}

@available(macOS 26.0, *)
@Generable(description: "Full relevance analysis of the candidate profile against the job requirements")
struct MatchAnalysis {
    @Guide(description: "Match assessment for each must-have requirement")
    var mustHaveResults: [RequirementMatchItem]

    @Guide(description: "Match assessment for each nice-to-have requirement")
    var niceToHaveResults: [RequirementMatchItem]
}

@available(macOS 26.0, *)
@Generable(description: "CV content tailored for the target role")
struct ComposedCVContent {
    @Guide(description: "A 2–3 sentence professional summary that connects the candidate's experience to this specific role. Only use facts from the candidate's profile.")
    var professionalSummary: String

    @Guide(description: "The candidate's most relevant skills for this role (picked from their existing skill list)")
    var highlightedSkills: [String]
}

@available(macOS 26.0, *)
@Generable(description: "Type of CV improvement: a weak bullet that needs a measurable impact, or a skill entirely missing from the profile")
enum GapFeedbackType {
    case weakBullet
    case missingSkill
}

@available(macOS 26.0, *)
@Generable(description: "One specific CV improvement suggestion from the gap review")
struct GeneratedFeedbackItem {
    @Guide(description: "Whether this is a weak bullet to strengthen, or a skill missing from the profile")
    var type: GapFeedbackType

    @Guide(description: "Short title describing the issue (max 8 words)")
    var title: String

    @Guide(description: "The exact existing bullet text that is weak. Empty string if type is missingSkill.")
    var existingBullet: String

    @Guide(description: "One precise question to elicit a measurable outcome from the user. Empty string if type is missingSkill.")
    var improvementQuestion: String

    @Guide(description: "Brief explanation of why this missing skill matters for the role. Empty string if type is weakBullet.")
    var skillExplanation: String
}

@available(macOS 26.0, *)
@Generable(description: "Gap review output with 2–4 improvement suggestions")
struct GapReviewOutput {
    @Guide(description: "List of 2 to 4 concrete, actionable improvement suggestions")
    var items: [GeneratedFeedbackItem]
}

// MARK: - Service

@available(macOS 26.0, *)
enum CVGenerationService {

    // MARK: - Profile → compact text summary

    static func profileSummary(_ cvData: CVData) -> String {
        var lines: [String] = []
        let p = cvData.profile

        if !p.skills.isEmpty {
            lines.append("Skills: \(p.skills.joined(separator: ", "))")
        }
        if !p.summary.isEmpty {
            lines.append("Summary: \(p.summary)")
        }

        if !cvData.experiences.isEmpty {
            lines.append("\nWork Experience:")
            for exp in cvData.experiences {
                let period = [exp.startDate, exp.duration].filter { !$0.isEmpty }.joined(separator: "–")
                lines.append("• \(exp.role) at \(exp.company) (\(period))")
                for h in exp.highlights.prefix(3) where !h.isEmpty {
                    lines.append("  – \(h)")
                }
            }
        }

        if !cvData.educations.isEmpty {
            lines.append("\nEducation:")
            for edu in cvData.educations {
                let field = edu.fieldOfStudy.isEmpty ? "" : " in \(edu.fieldOfStudy)"
                lines.append("• \(edu.degree)\(field), \(edu.institution) (\(edu.year))")
            }
        }

        if !cvData.certifications.isEmpty {
            lines.append("Certifications: \(cvData.certifications.map(\.name).joined(separator: ", "))")
        }

        if !cvData.organizations.isEmpty {
            let orgs = cvData.organizations.map { "\($0.role) at \($0.name)" }.joined(separator: ", ")
            lines.append("Organizations: \(orgs)")
        }

        if !cvData.projects.isEmpty {
            lines.append("\nProjects:")
            for proj in cvData.projects.prefix(3) {
                lines.append("• \(proj.name) — \(proj.techStack)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Step 1: RequirementExtractor

    static func extractRequirements(from jd: String) async throws -> ExtractedRequirements {
        let session = LanguageModelSession(instructions: """
            The person's locale is en_US. You MUST respond in U.S. English.
            You are a recruitment specialist. Extract structured job requirements from job descriptions.
            Be concise — each skill or requirement should be 1–5 words.
            Only extract requirements that are explicitly stated, not implied.
            """)
        let response = try await session.respond(
            to: "Extract requirements from this job description:\n\n\(jd)",
            generating: ExtractedRequirements.self
        )
        return response.content
    }

    // MARK: - Step 2: RelevanceMatcher

    static func matchRelevance(
        requirements: ExtractedRequirements,
        profileSummary: String
    ) async throws -> MatchAnalysis {
        let mustHaveList   = requirements.mustHaveSkills.map   { "• \($0)" }.joined(separator: "\n")
        let niceToHaveList = requirements.niceToHaveSkills.map { "• \($0)" }.joined(separator: "\n")

        let session = LanguageModelSession(instructions: """
            The person's locale is en_US. You MUST respond in U.S. English.
            You are a CV reviewer. Compare a candidate profile against job requirements.
            Criteria:
            - matched: profile clearly and directly demonstrates this requirement
            - partial: profile shows limited or indirect evidence
            - missing: profile has no evidence of this requirement
            Be strict: only mark as matched if evidence is clear and direct.
            """)

        let prompt = """
            Candidate Profile:
            \(profileSummary)

            Must-have requirements:
            \(mustHaveList.isEmpty ? "None" : mustHaveList)

            Nice-to-have requirements:
            \(niceToHaveList.isEmpty ? "None" : niceToHaveList)

            Analyze how well the candidate matches each requirement.
            """
        let response = try await session.respond(to: prompt, generating: MatchAnalysis.self)
        return response.content
    }

    // MARK: - Step 3: CVComposer

    static func composeCVContent(
        jd: String,
        profileSummary: String,
        jobTitle: String
    ) async throws -> ComposedCVContent {
        let session = LanguageModelSession(instructions: """
            The person's locale is en_US. You MUST respond in U.S. English.
            You are an expert CV writer specializing in targeted job applications.
            Write a concise professional summary (2–3 sentences) that connects the
            candidate's real experience to the target role.
            Only use facts from the provided profile — never invent or embellish.
            Select the most relevant skills from the candidate's existing skill list.
            """)

        let prompt = """
            Target Role: \(jobTitle)

            Job Description (excerpt):
            \(String(jd.prefix(600)))

            Candidate Profile:
            \(profileSummary)

            Compose a tailored professional summary and highlight the most relevant skills.
            """
        let response = try await session.respond(to: prompt, generating: ComposedCVContent.self)
        return response.content
    }

    // MARK: - Step 4: GapReviewer

    static func reviewGaps(
        matchAnalysis: MatchAnalysis,
        profileSummary: String
    ) async throws -> GapReviewOutput {
        let gaps = (matchAnalysis.mustHaveResults + matchAnalysis.niceToHaveResults)
            .filter { $0.status == .partial || $0.status == .missing }
            .map    { "• \($0.requirement) (\($0.status == .partial ? "partial" : "missing"))" }
            .joined(separator: "\n")

        let session = LanguageModelSession(instructions: """
            The person's locale is en_US. You MUST respond in U.S. English.
            You are a CV improvement coach. Identify 2–4 specific, actionable improvements.
            For weak bullets: ask one precise question to elicit a measurable result or number.
            For missing skills: explain in one sentence why this skill matters for the role.
            Never invent facts — improvements should prompt the user to provide their own real information.
            """)

        let prompt = """
            Candidate Profile:
            \(profileSummary)

            Gaps (partial or missing requirements):
            \(gaps.isEmpty ? "No significant gaps identified" : gaps)

            Identify the most impactful CV improvements for this candidate.
            """
        let response = try await session.respond(to: prompt, generating: GapReviewOutput.self)
        return response.content
    }

    // MARK: - Score Calculation (cv-match-scoring rules)

    static func calculateScore(from analysis: MatchAnalysis) -> MatchScoreBreakdown {
        let wMust:    Double = 3
        let wNice:    Double = 1

        func value(_ item: RequirementMatchItem) -> Double {
            switch item.status {
            case .matched: return 1.0
            case .partial: return 0.5
            case .missing: return 0.0
            }
        }

        let mustNum  = analysis.mustHaveResults.reduce(0.0)    { $0 + wMust * value($1) }
        let niceNum  = analysis.niceToHaveResults.reduce(0.0)  { $0 + wNice * value($1) }
        let num      = mustNum + niceNum
        let den      = Double(analysis.mustHaveResults.count) * wMust
                     + Double(analysis.niceToHaveResults.count) * wNice
        let score    = den > 0 ? Int((num / den * 100).rounded()) : 0

        let missingMust = analysis.mustHaveResults.filter { $0.status == .missing }.map(\.requirement)
        let partialMust = analysis.mustHaveResults.filter { $0.status == .partial }.map(\.requirement)

        let gate: ReadinessGate
        if !missingMust.isEmpty     { gate = .notQualified(missingSkills: missingMust) }
        else if !partialMust.isEmpty { gate = .needsWork(partialSkills: partialMust) }
        else                         { gate = .ready }

        return MatchScoreBreakdown(
            matchScore:        score,
            gate:              gate,
            mustHaveMatched:   analysis.mustHaveResults.filter  { $0.status == .matched }.count,
            mustHavePartial:   analysis.mustHaveResults.filter  { $0.status == .partial }.count,
            mustHaveMissing:   analysis.mustHaveResults.filter  { $0.status == .missing }.count,
            mustHaveTotal:     analysis.mustHaveResults.count,
            niceToHaveMatched: analysis.niceToHaveResults.filter { $0.status == .matched }.count,
            niceToHavePartial: analysis.niceToHaveResults.filter { $0.status == .partial }.count,
            niceToHaveTotal:   analysis.niceToHaveResults.count,
            numerator:         num,
            denominator:       den
        )
    }

    // MARK: - Convert GapReviewOutput → [FeedbackItem]

    static func toFeedbackItems(_ output: GapReviewOutput) -> [FeedbackItem] {
        output.items.enumerated().map { idx, item in
            let tag: FeedbackTag = item.type == .weakBullet ? .weakBullet : .missingSkill
            let tagLabel = item.type == .weakBullet
                ? "Weak bullet · missing impact"
                : "Missing skill · can't be filled in"
            return FeedbackItem(
                id:               "fb-\(idx + 1)",
                tag:              tag,
                tagLabel:         tagLabel,
                title:            item.title,
                bulletQuote:      item.existingBullet.isEmpty ? "" : "\"\(item.existingBullet)\"",
                question:         item.improvementQuestion,
                inputPlaceholder: "Describe the outcome…",
                helperText:       "The agent weaves your answer in — it won't make up numbers.",
                missingDesc:      item.skillExplanation,
                boldPhrases:      []
            )
        }
    }
}
