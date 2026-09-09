import Foundation

// MARK: - Codable output types (replaces @Generable from FoundationModels branch)

struct ExtractedRequirements: Codable {
    var mustHaveSkills: [String]
    var niceToHaveSkills: [String]
    var jobTitle: String
}

enum MatchStatus: String, Codable {
    case matched
    case partial
    case missing
}

struct RequirementMatchItem: Codable {
    var requirement: String
    var status: MatchStatus
}

struct MatchAnalysis: Codable {
    var mustHaveResults: [RequirementMatchItem]
    var niceToHaveResults: [RequirementMatchItem]
}

struct ComposedCVContent: Codable {
    var professionalSummary: String
    var highlightedSkills: [String]
}

enum GapFeedbackType: String, Codable {
    case weakBullet
    case missingSkill
}

struct GeneratedFeedbackItem: Codable {
    var type: GapFeedbackType
    var reasonCode: String
    var title: String
    var existingBullet: String
    var improvementQuestion: String
    var skillExplanation: String
}

struct GapReviewOutput: Codable {
    var items: [GeneratedFeedbackItem]
}

// MARK: - Service

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
        let system = "You complete JSON templates by filling in placeholder values."
        let prompt = """
            Complete this JSON template using the job description below. Fill every "..." with a real value:
            {"mustHaveSkills":["...","..."],"niceToHaveSkills":["..."],"jobTitle":"..."}

            mustHaveSkills = explicitly required skills (technical first, soft skills last, 1-5 words each)
            niceToHaveSkills = preferred/nice-to-have skills
            jobTitle = exact title from the job posting

            Job description:
            \(String(jd.prefix(2000)))

            Completed JSON:
            """
        let raw = try await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 500)
        return try MLXInferenceService.decode(ExtractedRequirements.self, from: raw)
    }

    // MARK: - Step 2: RelevanceMatcher

    static func matchRelevance(
        requirements: ExtractedRequirements,
        profileSummary: String
    ) async throws -> MatchAnalysis {
        let mustHaveList   = requirements.mustHaveSkills.map   { "• \($0)" }.joined(separator: "\n")
        let niceToHaveList = requirements.niceToHaveSkills.map { "• \($0)" }.joined(separator: "\n")

        let system = "You complete JSON templates by filling in placeholder values."
        let prompt = """
            Complete this JSON template. For each requirement, set status to "matched", "partial", or "missing":
            {"mustHaveResults":[{"requirement":"...","status":"..."}],"niceToHaveResults":[{"requirement":"...","status":"..."}]}

            matched = direct proof in profile | partial = indirect/limited evidence | missing = no evidence

            Candidate profile:
            \(profileSummary)

            Must-have requirements:
            \(mustHaveList.isEmpty ? "None" : mustHaveList)

            Nice-to-have requirements:
            \(niceToHaveList.isEmpty ? "None" : niceToHaveList)

            Completed JSON:
            """
        let raw = try await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 700)
        return try MLXInferenceService.decode(MatchAnalysis.self, from: raw)
    }

    // MARK: - Step 3: CVComposer
    // Uses labeled-text output (not JSON) because free-prose summaries contain quotes/commas
    // that routinely break JSON string parsing in small models.

    static func composeCVContent(
        jd: String,
        profileSummary: String,
        jobTitle: String,
        appliedImprovements: String = ""
    ) async throws -> ComposedCVContent {
        let system = "You write professional CV content following exact formatting instructions."
        var prompt = """
            Write a tailored CV summary for the candidate below.

            Target role: \(jobTitle)
            Job description: \(String(jd.prefix(600)))
            Candidate profile: \(profileSummary)
            """
        if !appliedImprovements.isEmpty {
            prompt += "\nImprovements to incorporate: \(appliedImprovements)"
        }
        prompt += """


            Rules: 2-3 sentences, no I/me/my, only facts from the profile, avoid weak verbs like Responsible for / Helped / Utilized.

            Respond with EXACTLY these two labeled lines and nothing else:
            SUMMARY: [your 2-3 sentence summary]
            SKILLS: [skill1, skill2, skill3, skill4, skill5]
            """
        let raw = try await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 400)
        return Self.parseLabeledCVOutput(raw, fallbackSummary: "")
    }

    private static func parseLabeledCVOutput(_ text: String, fallbackSummary: String) -> ComposedCVContent {
        // Known label variants models use
        let summaryPrefixes = ["PROFESSIONAL SUMMARY:", "PROFESSIONAL_SUMMARY:", "SUMMARY:", "Summary:", "Professional Summary:"]
        let skillsPrefixes  = ["SKILLS:", "Skills:", "KEY SKILLS:", "Highlighted Skills:"]

        var summary = ""
        var skills: [String] = []
        var candidateParagraphs: [String] = []  // non-empty lines that aren't skill lists

        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }

            if let prefix = summaryPrefixes.first(where: { t.uppercased().hasPrefix($0.uppercased()) }) {
                let s = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                if !s.isEmpty { summary = s }
            } else if let prefix = skillsPrefixes.first(where: { t.uppercased().hasPrefix($0.uppercased()) }) {
                skills = String(t.dropFirst(prefix.count))
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "[]")) }
                    .filter { !$0.isEmpty }
            } else {
                // Collect as candidate for fallback summary (skip lines that look like skill lists)
                let commaCount = t.filter { $0 == "," }.count
                if commaCount < 3 { candidateParagraphs.append(t) }
            }
        }

        // Fallback: if no labeled summary found, use the first substantial paragraph
        if summary.isEmpty {
            summary = candidateParagraphs
                .first { $0.count > 40 } ?? fallbackSummary
        }

        return ComposedCVContent(professionalSummary: summary, highlightedSkills: skills)
    }

    // MARK: - Client-side relevance filter (no LLM — pure keyword matching)

    /// Scores experiences/projects against JD keywords, picks the top-ranked ones.
    /// Max 3 experiences and 2 projects — sorted by keyword overlap score, descending.
    static func filterRelevantIndices(
        in cvData: CVData,
        using keywords: [String]
    ) -> (experiences: [Int], projects: [Int]) {
        // Split keywords on non-alphanumeric chars so "AI/ML" → ["ai","ml"],
        // keep tokens ≥2 chars so "AI", "ML", "Go" are included.
        let tokens = keywords.flatMap { kw in
            kw.lowercased()
              .components(separatedBy: CharacterSet.alphanumerics.inverted)
              .filter { $0.count >= 2 }
        }

        guard !tokens.isEmpty else {
            return (Array(cvData.experiences.indices), Array(cvData.projects.indices))
        }

        func score(_ text: String) -> Int {
            let lower = text.lowercased()
            // Count unique tokens that appear in this text (not repeated matches for the same token)
            return tokens.filter { lower.contains($0) }.count
        }

        // Score every experience, sort descending, take top 3
        let expScored = cvData.experiences.indices.map { i -> (Int, Int) in
            let exp = cvData.experiences[i]
            let text = ([exp.role, exp.company, exp.description, exp.location] + exp.highlights).joined(separator: " ")
            return (i, score(text))
        }
        let sortedExp = expScored.sorted { $0.1 > $1.1 }
        let topExp: [Int]
        if sortedExp.first?.1 == 0 {
            topExp = Array(cvData.experiences.indices)  // nothing matched → include all
        } else {
            topExp = sortedExp.filter { $0.1 > 0 }.prefix(3).map(\.0)
        }

        // Score every project, sort descending, take top 2
        let projScored = cvData.projects.indices.map { i -> (Int, Int) in
            let p = cvData.projects[i]
            let text = ([p.name, p.role, p.techStack] + p.highlights).joined(separator: " ")
            return (i, score(text))
        }
        let sortedProj = projScored.sorted { $0.1 > $1.1 }
        let topProj: [Int]
        if sortedProj.first?.1 == 0 {
            topProj = Array(cvData.projects.indices)  // nothing matched → include all
        } else {
            topProj = sortedProj.filter { $0.1 > 0 }.prefix(2).map(\.0)
        }

        return (topExp, topProj)
    }

    // MARK: - Step 4: GapReviewer

    static func reviewGaps(
        matchAnalysis: MatchAnalysis,
        profileSummary: String,
        appliedImprovements: String = ""
    ) async throws -> GapReviewOutput {
        let gaps = (matchAnalysis.mustHaveResults + matchAnalysis.niceToHaveResults)
            .filter { $0.status == .partial || $0.status == .missing }
            .map    { "• \($0.requirement) (\($0.status == .partial ? "partial" : "missing"))" }
            .joined(separator: "\n")

        // Keep only skills + first 3 experience bullets to stay within token budget for a 3B model
        let compactProfile = profileSummary
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("    –") || $0.isEmpty }  // drop sub-bullets deeper than one level
            .prefix(30)
            .joined(separator: "\n")

        let system = "You complete JSON templates by filling in placeholder values."
        var prompt = """
            Complete this JSON template with 2-4 CV improvements. Fill every "..." with a real value:
            {"items":[{"type":"weakBullet","reasonCode":"MISSING_METRIC","title":"...","existingBullet":"...","improvementQuestion":"...","skillExplanation":""}]}

            reasonCode must be one of:
            MISSING_METRIC — bullet has no number/result → ask user for the metric
            BANNED_VERB — bullet starts with weak verb → improvementQuestion must be ""
            CLICHE — contains filler phrase → improvementQuestion must be ""
            MISSING_KEYWORD — partial skill match → ask user to describe where they used it
            NO_BACKING — skill completely absent → improvementQuestion must be "", skillExplanation explains why it matters

            type: "weakBullet" for bullet rewrites, "missingSkill" for missing/partial skills

            Candidate profile (skills and experience):
            \(compactProfile)

            Job requirement gaps:
            \(gaps.isEmpty ? "None" : gaps)
            """
        if !appliedImprovements.isEmpty {
            prompt += "\n\nSkip these (already addressed): \(appliedImprovements)"
        }
        prompt += "\n\nCompleted JSON:"
        let raw = try await MLXInferenceService.shared.generate(system: system, prompt: prompt, maxTokens: 800)
        return try MLXInferenceService.decode(GapReviewOutput.self, from: raw)
    }

    // MARK: - Score Calculation

    static func calculateScore(from analysis: MatchAnalysis) -> MatchScoreBreakdown {
        let wMust: Double = 3
        let wNice: Double = 1

        func value(_ item: RequirementMatchItem) -> Double {
            switch item.status {
            case .matched: return 1.0
            case .partial: return 0.5
            case .missing: return 0.0
            }
        }

        let mustNum = analysis.mustHaveResults.reduce(0.0)   { $0 + wMust * value($1) }
        let niceNum = analysis.niceToHaveResults.reduce(0.0) { $0 + wNice * value($1) }
        let num     = mustNum + niceNum
        let den     = Double(analysis.mustHaveResults.count) * wMust
                    + Double(analysis.niceToHaveResults.count) * wNice
        let score   = den > 0 ? Int((num / den * 100).rounded()) : 0

        let missingMust = analysis.mustHaveResults.filter { $0.status == .missing }.map(\.requirement)
        let partialMust = analysis.mustHaveResults.filter { $0.status == .partial }.map(\.requirement)

        let gate: ReadinessGate
        if !missingMust.isEmpty      { gate = .notQualified(missingSkills: missingMust) }
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
            let (tag, tagLabel, question, placeholder, helperText, canApply) = Self.feedbackMeta(for: item)
            return FeedbackItem(
                id:               "fb-\(idx + 1)",
                tag:              tag,
                tagLabel:         tagLabel,
                title:            item.title,
                bulletQuote:      item.existingBullet.isEmpty ? "" : "\"\(item.existingBullet)\"",
                question:         question,
                inputPlaceholder: placeholder,
                helperText:       helperText,
                missingDesc:      item.skillExplanation,
                boldPhrases:      [],
                canApply:         canApply
            )
        }
    }

    // Returns (tag, tagLabel, question, inputPlaceholder, helperText, canApply)
    private static func feedbackMeta(for item: GeneratedFeedbackItem)
        -> (FeedbackTag, String, String, String, String, Bool)
    {
        switch item.reasonCode.uppercased() {
        case "MISSING_METRIC":
            return (.missingMetric,
                    "Missing metric · add a number",
                    item.improvementQuestion,
                    "e.g. reduced load time by 40%, served 10k users",
                    "The agent weaves your number in — it won't make up figures.",
                    true)
        case "BANNED_VERB":
            // Model auto-rewrites the opener — user just needs to confirm with Apply, no input needed.
            return (.bannedVerb,
                    "Banned verb · auto-fix",
                    "",
                    "",
                    "",
                    true)
        case "CLICHE":
            // Model auto-removes the cliché — user just confirms with Apply.
            return (.cliche,
                    "Cliché · auto-fix",
                    "",
                    "",
                    "",
                    true)
        case "NO_BACKING":
            return (.missingSkill,
                    "No backing · can't be added",
                    "",
                    "",
                    "This skill is missing from your profile. Gain real experience first, then add it.",
                    false)   // purely informational, no Apply
        case "MISSING_KEYWORD":
            return (.missingSkill,
                    "Missing keyword · partially there",
                    item.improvementQuestion,
                    "Describe where you used this skill",
                    "The agent weaves your context into the summary.",
                    true)
        default:
            let isWeak = item.type == .weakBullet
            return (isWeak ? .weakBullet : .missingSkill,
                    isWeak ? "Weak bullet · missing impact" : "Missing skill",
                    item.improvementQuestion,
                    "Describe the outcome…",
                    "The agent weaves your answer in — it won't make up numbers.",
                    isWeak)
        }
    }
}
