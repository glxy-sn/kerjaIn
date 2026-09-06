import Foundation
import SwiftUI
import Observation

// MARK: - Feedback Types

enum FeedbackTag {
    case weakBullet, missingSkill
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
    var lastGeneratedJD: String = ""

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
        isGenerating = true
        generationDone = false
        feedbackItems = []
        for i in steps.indices { steps[i].state = .waiting }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for i in self.steps.indices {
                self.steps[i].state = .running
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                self.steps[i].state = .done
            }
            self.lastGeneratedJD = self.jobDescription
            self.feedbackItems = CVGeneratorViewModel.makeMockFeedback()
            self.isGenerating = false
            self.generationDone = true
        }
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
