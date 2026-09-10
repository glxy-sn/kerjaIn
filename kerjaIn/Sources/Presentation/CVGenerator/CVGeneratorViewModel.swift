import Foundation
import SwiftUI
import Observation

// MARK: - Section Config

struct SectionConfig {
    var name: String
    var detail: String
    var enabled: Bool
}

// MARK: - Match Scoring

enum ReadinessGate {
    case ready
    case needsWork(partialSkills: [String])
    case notQualified(missingSkills: [String])

    var label: String {
        switch self {
        case .ready:        return "Ready"
        case .needsWork:    return "Needs work"
        case .notQualified: return "Not qualified"
        }
    }

    var icon: String {
        switch self {
        case .ready:        return "checkmark.circle.fill"
        case .needsWork:    return "exclamationmark.circle.fill"
        case .notQualified: return "xmark.circle.fill"
        }
    }
}

struct MatchScoreBreakdown {
    let matchScore: Int
    let gate: ReadinessGate
    let mustHaveMatched: Int
    let mustHavePartial: Int
    let mustHaveMissing: Int
    let mustHaveTotal: Int
    let niceToHaveMatched: Int
    let niceToHavePartial: Int
    let niceToHaveTotal: Int
    let numerator: Double
    let denominator: Double
}

// MARK: - Feedback Types

enum FeedbackTag {
    case weakBullet      // generic weak bullet
    case missingMetric   // MISSING_METRIC — no measurable outcome
    case bannedVerb      // BANNED_VERB — weak opener
    case cliche          // CLICHE — filler self-descriptor
    case missingSkill    // MISSING_KEYWORD or NO_BACKING
}

enum FeedbackState {
    case pending, applied, skipped
}

struct FeedbackItem: Identifiable {
    let id: String
    let tag: FeedbackTag
    let tagLabel: String
    let title: String
    let bulletQuote: String
    let rawBullet: String       // original bullet text without quote decoration — used for find-and-replace
    let question: String
    let inputPlaceholder: String
    let helperText: String
    let missingDesc: String
    let boldPhrases: [String]
    var canApply: Bool = true   // false only for NO_BACKING (purely informational)
    var state: FeedbackState = .pending
    var inputText: String = ""
}

// MARK: - Pipeline Step Types

enum AgentStepState {
    case waiting, running, done
}

struct AgentStep: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    var state: AgentStepState = .waiting
}

// MARK: - ViewModel

@Observable
final class CVGeneratorViewModel {
    var cvData: CVData = .empty
    var jobDescription: String = ""
    var isSaved = false
    var isGenerating = false
    var generationDone = false
    var showCustomize = false

    var steps: [AgentStep] = [
        AgentStep(id: 1, title: "Requirement Extractor", subtitle: "Pulls key skills & keywords from the JD"),
        AgentStep(id: 2, title: "Relevance Matcher",     subtitle: "Scores your experience against requirements"),
        AgentStep(id: 3, title: "CV Composer",           subtitle: "Drafts a targeted, ATS-friendly CV"),
        AgentStep(id: 4, title: "Gap Reviewer",          subtitle: "Flags weak bullets & missing skills"),
    ]

    var feedbackItems: [FeedbackItem] = []
    var scoreBreakdown: MatchScoreBreakdown? = nil
    var lastGeneratedJD: String = ""
    var cvFullyOptimized: Bool = false

    // Tracks how many rounds of feedback the user has completed for the current JD.
    // GapReviewer is skipped after 2 rounds to prevent infinite suggestion loops.
    private var feedbackRoundsCompleted: Int = 0
    // Accumulates rawBullet text of every resolved item — passed to GapReviewer
    // so it never re-flags a bullet that was already addressed.
    private var allAddressedRawBullets: [String] = []

    // Indices of experiences/projects selected by the CVComposer as relevant to the JD
    var selectedExperienceIndices: [Int] = []
    var selectedProjectIndices: [Int] = []
    var isLivePipeline: Bool = false
    var lastPipelineError: String = ""

    // JD-tailored skills from the CVComposer (not persisted — only shown in filtered preview)
    var generatedSkills: [String] = []

    // Section visibility toggles for the generated CV preview
    var sections: [SectionConfig] = CVGeneratorViewModel.defaultSections

    static let defaultSections: [SectionConfig] = [
        SectionConfig(name: "Professional Summary", detail: "1 paragraph",       enabled: true),
        SectionConfig(name: "Experience",           detail: "3 selected",        enabled: true),
        SectionConfig(name: "Projects",             detail: "2 selected",        enabled: true),
        SectionConfig(name: "Skills",               detail: "8 tags",            enabled: true),
        SectionConfig(name: "Education",            detail: "1 entry",           enabled: true),
        SectionConfig(name: "Certifications",       detail: "off for this role", enabled: false),
        SectionConfig(name: "Honors & Awards",      detail: "off for this role", enabled: false),
        SectionConfig(name: "Organizations",        detail: "off for this role", enabled: false),
    ]

    // CVData filtered to only relevant experiences/projects, with section visibility applied
    var filteredCVData: CVData {
        guard generationDone else { return cvData }
        var filtered = cvData
        let enabled = Set(sections.filter(\.enabled).map(\.name))

        if !enabled.contains("Experience") {
            filtered.experiences = []
        } else if !selectedExperienceIndices.isEmpty {
            filtered.experiences = selectedExperienceIndices
                .filter { $0 < cvData.experiences.count }
                .map    { cvData.experiences[$0] }
        }
        if !enabled.contains("Projects") {
            filtered.projects = []
        } else if !selectedProjectIndices.isEmpty {
            filtered.projects = selectedProjectIndices
                .filter { $0 < cvData.projects.count }
                .map    { cvData.projects[$0] }
        }
        if !enabled.contains("Education")            { filtered.educations = [] }
        if !enabled.contains("Certifications")       { filtered.certifications = [] }
        if !enabled.contains("Honors & Awards")      { filtered.achievements = [] }
        if !enabled.contains("Organizations")        { filtered.organizations = [] }
        if !enabled.contains("Professional Summary") { filtered.profile.summary = "" }
        if !enabled.contains("Skills") {
            filtered.profile.skills = []
        } else if !generatedSkills.isEmpty {
            filtered.profile.skills = generatedSkills
        }
        return filtered
    }

    var canGenerate: Bool {
        !jobDescription.isEmpty && (
            !generationDone ||
            jobDescription != lastGeneratedJD ||
            feedbackItems.contains { $0.state == .applied }
        )
    }

    var generateButtonLabel: String {
        if isGenerating { return "Generating..." }
        let n = feedbackItems.filter { $0.state == .applied }.count
        if n > 0 { return "Apply \(n) Change\(n == 1 ? "" : "s") & Regenerate" }
        if generationDone { return "Regenerate CV" }
        return "Generate CV"
    }

    var pendingFeedback: [FeedbackItem] {
        feedbackItems.filter { $0.state == .pending }
    }

    private let cvRepository: any CVRepository
    private let profileRepository: any ProfileRepository

    init(cvRepository: any CVRepository, profileRepository: any ProfileRepository) {
        self.cvRepository = cvRepository
        self.profileRepository = profileRepository
    }

    func load() {
        cvData = cvRepository.getCVData()
        if cvData.profile == .empty {
            cvData.profile = profileRepository.getProfile()
        }
    }

    func save() {
        cvRepository.saveCVData(cvData)
        isSaved = true
    }

    func generateCV() {
        guard !jobDescription.isEmpty, canGenerate else { return }
        runGeneration()
    }

    func regenerateCV() {
        guard !jobDescription.isEmpty else { return }
        runGeneration()
    }

    func applyFeedback(id: String) {
        guard let idx = feedbackItems.firstIndex(where: { $0.id == id }) else { return }
        feedbackItems[idx].state = .applied
    }

    func skipFeedback(id: String) {
        guard let idx = feedbackItems.firstIndex(where: { $0.id == id }) else { return }
        feedbackItems[idx].state = .skipped
    }

    func updateFeedbackInput(id: String, text: String) {
        guard let idx = feedbackItems.firstIndex(where: { $0.id == id }) else { return }
        feedbackItems[idx].inputText = text
    }

    func addEducation()  { cvData.educations.append(Education()) }
    func addExperience() { cvData.experiences.append(WorkExperience()) }
    func removeEducation(at offsets: IndexSet)  { cvData.educations.remove(atOffsets: offsets) }
    func removeExperience(at offsets: IndexSet) { cvData.experiences.remove(atOffsets: offsets) }

    // MARK: - Private

    private func runGeneration() {
        // New JD → reset per-JD feedback tracking
        if lastGeneratedJD != jobDescription {
            feedbackRoundsCompleted = 0
            allAddressedRawBullets = []
            cvFullyOptimized = false
        }

        // Accumulate raw bullet text of every resolved item into the persistent list
        let newlyResolved = feedbackItems
            .filter { $0.state == .applied || $0.state == .skipped }
        let newBullets = newlyResolved.compactMap { $0.rawBullet.isEmpty ? nil : $0.rawBullet }
        allAddressedRawBullets.append(contentsOf: newBullets)

        let resolvedTitles = newlyResolved.map(\.title)

        // Applied items that have a bullet to rewrite
        let appliedItems = feedbackItems
            .filter { $0.state == .applied && !$0.rawBullet.isEmpty }

        // Text summary of applied answers for the CVComposer summary context
        let appliedAnswers = appliedItems
            .map { item -> String in
                let input = item.inputText.trimmingCharacters(in: .whitespaces)
                return "• \(item.title): \(input.isEmpty ? "[auto-fix]" : input)"
            }
            .joined(separator: "\n")

        // Increment round counter when user resolved items; skip GapReviewer after 2 rounds
        if !resolvedTitles.isEmpty { feedbackRoundsCompleted += 1 }
        let skipGapReview = feedbackRoundsCompleted >= 2
        let addressedBullets = allAddressedRawBullets  // snapshot for async closure

        isGenerating = true
        generationDone = false
        cvFullyOptimized = false
        feedbackItems = []
        scoreBreakdown = nil
        selectedExperienceIndices = []
        selectedProjectIndices = []
        generatedSkills = []
        for i in steps.indices { steps[i].state = .waiting }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = MLXInferenceService.shared
            if !service.isReady {
                await service.loadSelectedModel()
            }
            if service.isReady {
                self.isLivePipeline = true
                await self.runRealPipeline(
                    appliedAnswers: appliedAnswers,
                    resolvedTitles: resolvedTitles,
                    appliedItems: appliedItems,
                    skipGapReview: skipGapReview,
                    addressedBullets: addressedBullets
                )
            } else {
                self.isLivePipeline = false
                await self.runMockPipeline(resolvedTitles: resolvedTitles)
            }
        }
    }

    @MainActor
    private func runRealPipeline(
        appliedAnswers: String = "",
        resolvedTitles: [String] = [],
        appliedItems: [FeedbackItem] = [],
        skipGapReview: Bool = false,
        addressedBullets: [String] = []
    ) async {
        let jd      = jobDescription
        let profile = CVGenerationService.profileSummary(cvData)

        do {
            // Step 1 — RequirementExtractor
            steps[0].state = .running
            let requirements = try await CVGenerationService.extractRequirements(from: jd)
            steps[0].state = .done

            // Step 2 — RelevanceMatcher
            steps[1].state = .running
            let analysis = try await CVGenerationService.matchRelevance(
                requirements: requirements,
                profileSummary: profile
            )
            steps[1].state = .done

            // Client-side filtering: experiences/projects that match JD keywords
            let matchedKeywords = (analysis.mustHaveResults + analysis.niceToHaveResults)
                .filter { $0.status != .missing }
                .map    { $0.requirement }
            let filtered = CVGenerationService.filterRelevantIndices(in: cvData, using: matchedKeywords)
            selectedExperienceIndices = filtered.experiences
            selectedProjectIndices    = filtered.projects

            // Step 3 — CVComposer (incorporates user's typed answers if any)
            steps[2].state = .running
            let composed = try await CVGenerationService.composeCVContent(
                jd: jd,
                profileSummary: profile,
                jobTitle: requirements.jobTitle,
                appliedImprovements: appliedAnswers
            )
            cvData.profile.summary = composed.professionalSummary
            if !composed.highlightedSkills.isEmpty {
                generatedSkills = composed.highlightedSkills
            }
            // Rewrite specific bullets for every applied feedback item that has a bullet
            for item in appliedItems {
                if let rewritten = try? await CVGenerationService.rewriteBullet(
                    original: item.rawBullet,
                    userContext: item.inputText,
                    jd: jd
                ), !rewritten.isEmpty {
                    applyBulletRewrite(original: item.rawBullet, rewritten: rewritten)
                }
            }
            steps[2].state = .done

            // Step 4 — GapReviewer (skipped after 2 feedback rounds to prevent infinite loop)
            if skipGapReview {
                steps[3].state = .done
                cvFullyOptimized = true
            } else {
                steps[3].state = .running
                // Build context: resolved titles + all bullets already addressed across rounds
                var addressedParts: [String] = []
                if !resolvedTitles.isEmpty {
                    addressedParts.append(resolvedTitles.map { "• \($0)" }.joined(separator: "\n"))
                }
                if !addressedBullets.isEmpty {
                    addressedParts.append("Bullets already rewritten — do NOT flag these again:\n• " +
                        addressedBullets.joined(separator: "\n• "))
                }
                let alreadyAddressed = addressedParts.isEmpty ? appliedAnswers : addressedParts.joined(separator: "\n\n")
                let gaps = try await CVGenerationService.reviewGaps(
                    matchAnalysis: analysis,
                    profileSummary: profile,
                    appliedImprovements: alreadyAddressed
                )
                steps[3].state = .done
                feedbackItems = CVGenerationService.toFeedbackItems(gaps)
            }

            // Finalise
            lastGeneratedJD = jd
            scoreBreakdown  = CVGenerationService.calculateScore(from: analysis)
            isGenerating    = false
            generationDone  = true
        } catch {
            lastPipelineError = error.localizedDescription
            isLivePipeline = false
            for i in steps.indices where steps[i].state != .done { steps[i].state = .done }
            await runMockPipeline(resolvedTitles: resolvedTitles)
        }
    }

    // Find the original bullet in cvData (experiences then projects) and replace it in-place.
    // Called after the model rewrites a bullet so the updated text persists to the next generation.
    private func applyBulletRewrite(original: String, rewritten: String) {
        let orig = original.trimmingCharacters(in: .whitespaces)
        guard !orig.isEmpty else { return }
        for i in cvData.experiences.indices {
            for j in cvData.experiences[i].highlights.indices {
                if cvData.experiences[i].highlights[j].trimmingCharacters(in: .whitespaces) == orig {
                    cvData.experiences[i].highlights[j] = rewritten
                    return
                }
            }
        }
        for i in cvData.projects.indices {
            for j in cvData.projects[i].highlights.indices {
                if cvData.projects[i].highlights[j].trimmingCharacters(in: .whitespaces) == orig {
                    cvData.projects[i].highlights[j] = rewritten
                    return
                }
            }
        }
    }

    @MainActor
    private func runMockPipeline(resolvedTitles: [String] = []) async {
        for i in steps.indices {
            steps[i].state = .running
            try? await Task.sleep(nanoseconds: 800_000_000)
            steps[i].state = .done
        }
        lastGeneratedJD = jobDescription
        // Filter out suggestions the user already resolved in the previous run
        let allMock = CVGeneratorViewModel.makeMockFeedback()
        feedbackItems = allMock.filter { item in
            !resolvedTitles.contains(item.title)
        }
        scoreBreakdown = CVGeneratorViewModel.makeMockScore()
        isGenerating   = false
        generationDone = true
    }

    private static func makeMockScore() -> MatchScoreBreakdown {
        // Example from scoring doc: 5 must-have (4 matched, 1 partial, 0 missing) + 3 nice-to-have (2 matched)
        // Score = (4×3×1.0 + 1×3×0.5 + 2×1×1.0) / (5×3 + 3×1) = 15.5/18 = 86%
        MatchScoreBreakdown(
            matchScore: 86,
            gate: .needsWork(partialSkills: ["Core Data"]),
            mustHaveMatched: 4,
            mustHavePartial: 1,
            mustHaveMissing: 0,
            mustHaveTotal: 5,
            niceToHaveMatched: 2,
            niceToHavePartial: 0,
            niceToHaveTotal: 3,
            numerator: 15.5,
            denominator: 18.0
        )
    }

    private static func makeMockFeedback() -> [FeedbackItem] {
        [
            FeedbackItem(
                id: "fb-1",
                tag: .weakBullet,
                tagLabel: "Missing metric · add a number",
                title: "This bullet is missing a measurable result",
                bulletQuote: "\"Migrated 12 screens from UIKit to SwiftUI.\"",
                rawBullet: "Migrated 12 screens from UIKit to SwiftUI.",
                question: "How many lines of code changed, or what % load time improvement?",
                inputPlaceholder: "e.g. 30% less code, dropped load time to 0.4s",
                helperText: "The agent rewrites the bullet with your number — it won't make one up.",
                missingDesc: "",
                boldPhrases: []
            ),
            FeedbackItem(
                id: "fb-2",
                tag: .weakBullet,
                tagLabel: "Missing metric · add a number",
                title: "This bullet has no scale or outcome",
                bulletQuote: "\"Maintained legacy UIKit codebase.\"",
                rawBullet: "Maintained legacy UIKit codebase.",
                question: "How many lines of code, users affected, or iOS releases spanned?",
                inputPlaceholder: "e.g. 40k-line codebase across 3 iOS releases",
                helperText: "The agent rewrites the bullet with your number — it won't make one up.",
                missingDesc: "",
                boldPhrases: []
            ),
            FeedbackItem(
                id: "fb-3",
                tag: .missingSkill,
                tagLabel: "Missing skill · can't be added",
                title: "",
                bulletQuote: "",
                rawBullet: "",
                question: "",
                inputPlaceholder: "",
                helperText: "",
                missingDesc: "The JD asks for on-device ML, but it doesn't appear in your knowledge base. The agent won't add a skill you haven't done — add real experience with it in Profile first, or accept it as an honest gap for this role.",
                boldPhrases: ["on-device ML", "Profile"]
            ),
        ]
    }
}
