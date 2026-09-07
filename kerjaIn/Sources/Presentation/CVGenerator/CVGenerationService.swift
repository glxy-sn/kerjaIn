import Foundation
import FoundationModels

// MARK: - @Generable output types for each pipeline stage
// All types require macOS 26.0+ (Apple Intelligence / FoundationModels framework)

@available(macOS 26.0, *)
@Generable(description: "Requirements extracted from a job description")
struct ExtractedRequirements {
    @Guide(description: "Must-have hard skills or technologies explicitly required. Ordered by priority: 1) hard technical skills, 2) job-title keywords, 3) required education/certifications, 4) soft skills. 1–5 words each.")
    var mustHaveSkills: [String]

    @Guide(description: "Preferred or nice-to-have skills mentioned in the job description. 1–5 words each.")
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

    @Guide(description: "Exact reason code — one of: MISSING_METRIC, BANNED_VERB, CLICHE, MISSING_KEYWORD, NO_BACKING")
    var reasonCode: String

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
            Rank mustHaveSkills by priority: hard technical skills first, then job-title keywords, then required education/certifications, then soft skills. Weight terms that recur across the posting or appear in the job title / requirements section.
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
            - matched: profile has a clear, direct proof bullet for this requirement
            - partial: profile shows indirect or limited evidence only
            - missing: profile has no evidence — never mark matched without a real proof bullet
            Be strict. Only use data the candidate explicitly provided. Never assume or infer skills not stated.
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
            You are an expert CV writer. Rules you must follow:
            - Never invent facts. Use only data from the provided profile.
            - Professional summary: 2–3 sentences. No "I", "me", or "my". Mirror the JD job title where the candidate genuinely held an equivalent role.
            - Skills: pick only skills the candidate actually has, ordered by JD relevance.
            - Distribute 8–12 JD keywords naturally across the summary — do not keyword-stuff.
            - Never use banned openers: Responsible for / Helped / Assisted / Worked on / Involved in / Utilized / Leveraged.
            - Aim for XYZ structure in any bullets: Accomplished [X] measured by [Y] by doing [Z].
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
            You are a CV improvement coach. Identify 2–4 specific, actionable improvements. Set reasonCode to exactly one of:
            - MISSING_METRIC: bullet describes a duty with no measurable outcome — ask for a number.
            - BANNED_VERB: bullet opens with Responsible for/Helped/Assisted/Worked on/Involved in/Utilized/Leveraged — ask them to rewrite with a strong action verb.
            - CLICHE: contains team player/hard worker/detail-oriented/results-oriented/go-getter/synergy — flag and ask to replace with evidence.
            - MISSING_KEYWORD: JD skill the candidate partially demonstrates but hasn't stated explicitly — suggest adding it.
            - NO_BACKING: JD skill the candidate truly lacks — do not suggest adding it; explain the gap.
            Never invent facts. Never suggest skills the candidate hasn't done.
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
            let (tag, tagLabel, placeholder, helperText) = Self.feedbackMeta(for: item)
            return FeedbackItem(
                id:               "fb-\(idx + 1)",
                tag:              tag,
                tagLabel:         tagLabel,
                title:            item.title,
                bulletQuote:      item.existingBullet.isEmpty ? "" : "\"\(item.existingBullet)\"",
                question:         item.improvementQuestion,
                inputPlaceholder: placeholder,
                helperText:       helperText,
                missingDesc:      item.skillExplanation,
                boldPhrases:      []
            )
        }
    }

    private static func feedbackMeta(for item: GeneratedFeedbackItem) -> (FeedbackTag, String, String, String) {
        switch item.reasonCode.uppercased() {
        case "MISSING_METRIC":
            return (.missingMetric,
                    "Missing metric · add a number",
                    "e.g. reduced load time by 40%, served 10k users",
                    "The agent weaves your number in — it won't make up figures.")
        case "BANNED_VERB":
            return (.bannedVerb,
                    "Banned verb · rewrite opener",
                    "e.g. Built, Designed, Shipped, Reduced, Led",
                    "Start with a strong past-tense action verb — it stops the recruiter's eye.")
        case "CLICHE":
            return (.cliche,
                    "Cliché · replace with evidence",
                    "e.g. what you actually did, with a result",
                    "Replace the filler phrase with a concrete example or number.")
        case "NO_BACKING":
            return (.missingSkill,
                    "No backing · can't be added",
                    "",
                    "This skill is missing from your profile. Gain real experience first, then add it.")
        case "MISSING_KEYWORD":
            return (.missingSkill,
                    "Missing keyword · partially there",
                    "Describe where you used this skill",
                    "You have partial backing — add a real bullet to your profile to strengthen the match.")
        default:
            let isWeak = item.type == .weakBullet
            return (isWeak ? .weakBullet : .missingSkill,
                    isWeak ? "Weak bullet · missing impact" : "Missing skill · can't be filled in",
                    "Describe the outcome…",
                    "The agent weaves your answer in — it won't make up numbers.")
        }
    }
}
