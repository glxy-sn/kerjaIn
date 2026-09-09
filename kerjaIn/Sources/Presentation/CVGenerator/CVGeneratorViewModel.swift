import Foundation
import SwiftUI
import Observation

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

    // Indices of experiences/projects selected by the CVComposer as relevant to the JD
    var selectedExperienceIndices: [Int] = []
    var selectedProjectIndices: [Int] = []
    var isLivePipeline: Bool = false
    var lastPipelineError: String = ""

    // CVData filtered to only relevant experiences/projects for the preview
    var filteredCVData: CVData {
        guard generationDone else { return cvData }
        var filtered = cvData
        if !selectedExperienceIndices.isEmpty {
            filtered.experiences = selectedExperienceIndices
                .filter { $0 < cvData.experiences.count }
                .map    { cvData.experiences[$0] }
        }
        if !selectedProjectIndices.isEmpty {
            filtered.projects = selectedProjectIndices
                .filter { $0 < cvData.projects.count }
                .map    { cvData.projects[$0] }
        }
        return filtered
    }

    var canGenerate: Bool {
        !jobDescription.isEmpty && (!generationDone || jobDescription != lastGeneratedJD)
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
        // Capture ALL resolved suggestions so GapReviewer won't repeat them
        let resolvedTitles = feedbackItems
            .filter { $0.state == .applied || $0.state == .skipped }
            .map    { $0.title }

        // Capture applied items for CVComposer: include user's text OR "[auto-fix]" marker for items
        // where the model handles the rewrite itself (BANNED_VERB, CLICHE — no user input needed).
        let appliedAnswers = feedbackItems
            .filter { $0.state == .applied }
            .map { item -> String in
                let input = item.inputText.trimmingCharacters(in: .whitespaces)
                return "• \(item.title): \(input.isEmpty ? "[auto-fix — rewrite this bullet]" : input)"
            }
            .joined(separator: "\n")

        isGenerating = true
        generationDone = false
        feedbackItems = []
        scoreBreakdown = nil
        selectedExperienceIndices = []
        selectedProjectIndices = []
        for i in steps.indices { steps[i].state = .waiting }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = MLXInferenceService.shared
            if !service.isReady {
                await service.loadSelectedModel()
            }
            if service.isReady {
                self.isLivePipeline = true
                await self.runRealPipeline(appliedAnswers: appliedAnswers, resolvedTitles: resolvedTitles)
            } else {
                self.isLivePipeline = false
                await self.runMockPipeline(resolvedTitles: resolvedTitles)
            }
        }
    }

    @MainActor
    private func runRealPipeline(appliedAnswers: String = "", resolvedTitles: [String] = []) async {
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
            steps[2].state = .done

            // Step 4 — GapReviewer (excludes all resolved suggestions)
            steps[3].state = .running
            let alreadyAddressed = resolvedTitles.isEmpty
                ? appliedAnswers
                : resolvedTitles.map { "• \($0)" }.joined(separator: "\n")
            let gaps = try await CVGenerationService.reviewGaps(
                matchAnalysis: analysis,
                profileSummary: profile,
                appliedImprovements: alreadyAddressed
            )
            steps[3].state = .done

            // Finalise
            lastGeneratedJD = jd
            scoreBreakdown  = CVGenerationService.calculateScore(from: analysis)
            feedbackItems   = CVGenerationService.toFeedbackItems(gaps)
            isGenerating    = false
            generationDone  = true
        } catch {
            lastPipelineError = error.localizedDescription
            isLivePipeline = false
            for i in steps.indices where steps[i].state != .done { steps[i].state = .done }
            await runMockPipeline(resolvedTitles: resolvedTitles)
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
                tagLabel: "Weak bullet · missing impact",
                title: "This experience has no measurable result",
                bulletQuote: "\"Migrated 12 screens from UIKit to SwiftUI.\"",
                question: "What was the measurable outcome?",
                inputPlaceholder: "e.g. cut UI code by 30%, dropped load time to 0.4s",
                helperText: "The agent weaves your answer into the bullet — it won't make up a number.",
                missingDesc: "",
                boldPhrases: []
            ),
            FeedbackItem(
                id: "fb-2",
                tag: .weakBullet,
                tagLabel: "Weak bullet · vague scope",
                title: "This bullet describes a task, not a contribution",
                bulletQuote: "\"Maintained legacy UIKit codebase.\"",
                question: "What did that maintenance achieve, and at what scale?",
                inputPlaceholder: "e.g. kept 40k-line app stable across 3 iOS releases",
                helperText: "Turns a responsibility into a result a recruiter can weigh.",
                missingDesc: "",
                boldPhrases: []
            ),
            FeedbackItem(
                id: "fb-3",
                tag: .missingSkill,
                tagLabel: "Missing skill · can't be filled in",
                title: "",
                bulletQuote: "",
                question: "",
                inputPlaceholder: "",
                helperText: "",
                missingDesc: "The JD asks for on-device ML, but it doesn't appear in your knowledge base. The agent won't add a skill you haven't done — add real experience with it in Profile first, or accept it as an honest gap for this role.",
                boldPhrases: ["on-device ML", "Profile"]
            ),
        ]
    }
}
