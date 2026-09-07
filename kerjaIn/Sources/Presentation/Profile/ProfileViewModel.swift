import Foundation
import AppKit
import Observation

enum ProfileEditTarget: Equatable {
    case education(String?)
    case experience(String?)
    case project(String?)
    case certification(String?)
    case organization(String?)
    case achievement(String?)
}

@Observable
final class ProfileViewModel {
    var profile: UserProfile = .empty
    var cvData: CVData = .empty

    var editingTarget: ProfileEditTarget? = nil
    var draftEducation:    Education    = Education()
    var draftExperience:   WorkExperience = WorkExperience()
    var draftProject:      Project      = Project()
    var draftCertification: Certification = Certification()
    var draftOrganization: Organization = Organization()
    var draftAchievement:  Achievement  = Achievement()

    var isEditingProfile = false
    var editingProfile: UserProfile = .empty

    // CV Import state
    var isImporting = false
    var importError: String? = nil
    var showImportError = false
    var showImportConfirm = false
    var showReviewNotice = false
    var importSummaryLine = ""
    private var pendingImportProfile: UserProfile? = nil
    private var pendingImportCVData: CVData? = nil

    private let profileRepository: any ProfileRepository
    private let cvRepository: any CVRepository

    init(profileRepository: any ProfileRepository, cvRepository: any CVRepository) {
        self.profileRepository = profileRepository
        self.cvRepository = cvRepository
    }

    func load() {
        profile = profileRepository.getProfile()
        cvData = cvRepository.getCVData()
        editingProfile = profile
    }

    // MARK: - Header profile edit

    func startEditingProfile() { editingProfile = profile; isEditingProfile = true }

    func commitProfileEdit() {
        // Preserve fields managed outside the sheet
        let currentSkills    = profile.skills
        let currentPhotoData = profile.photoData
        profile = editingProfile
        profile.skills    = currentSkills
        profile.photoData = currentPhotoData
        saveProfile()
        isEditingProfile = false
    }

    func cancelProfileEdit() { editingProfile = profile; isEditingProfile = false }

    // MARK: - Skills

    func addSkill(_ skill: String) {
        let t = skill.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !profile.skills.contains(t) else { return }
        profile.skills.append(t)
        saveProfile()
    }

    func removeSkill(_ skill: String) {
        profile.skills.removeAll { $0 == skill }
        saveProfile()
    }

    // MARK: - Education

    func startAddEducation()          { draftEducation = Education();   editingTarget = .education(nil) }
    func startEditEducation(_ e: Education) { draftEducation = e;       editingTarget = .education(e.id) }

    func saveEducation() {
        guard case .education(let id) = editingTarget else { return }
        var draft = draftEducation
        draft.highlights = draft.highlights.filter { !$0.isEmpty }
        if let id, let idx = cvData.educations.firstIndex(where: { $0.id == id }) {
            cvData.educations[idx] = draft
        } else { cvData.educations.append(draft) }
        saveCVData(); editingTarget = nil
    }

    func deleteEducation(id: String) { cvData.educations.removeAll { $0.id == id }; saveCVData(); editingTarget = nil }

    // MARK: - Experience

    func startAddExperience()              { draftExperience = WorkExperience(); editingTarget = .experience(nil) }
    func startEditExperience(_ e: WorkExperience) { draftExperience = e;        editingTarget = .experience(e.id) }

    func saveExperience() {
        guard case .experience(let id) = editingTarget else { return }
        var draft = draftExperience
        draft.highlights = draft.highlights.filter { !$0.isEmpty }
        if let id, let idx = cvData.experiences.firstIndex(where: { $0.id == id }) {
            cvData.experiences[idx] = draft
        } else { cvData.experiences.append(draft) }
        saveCVData(); editingTarget = nil
    }

    func deleteExperience(id: String) { cvData.experiences.removeAll { $0.id == id }; saveCVData(); editingTarget = nil }

    // MARK: - Project

    func startAddProject()          { draftProject = Project(); editingTarget = .project(nil) }
    func startEditProject(_ p: Project) { draftProject = p;    editingTarget = .project(p.id) }

    func addProjectLink(label: String, url: String) {
        let u = url.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty else { return }
        draftProject.links.append(ProfileLink(label: label.trimmingCharacters(in: .whitespaces), url: u))
    }

    func removeProjectLink(at idx: Int) {
        guard draftProject.links.indices.contains(idx) else { return }
        draftProject.links.remove(at: idx)
    }

    func saveProject() {
        guard case .project(let id) = editingTarget else { return }
        var draft = draftProject
        draft.highlights = draft.highlights.filter { !$0.isEmpty }
        if let id, let idx = cvData.projects.firstIndex(where: { $0.id == id }) {
            cvData.projects[idx] = draft
        } else { cvData.projects.append(draft) }
        saveCVData(); editingTarget = nil
    }

    func deleteProject(id: String) { cvData.projects.removeAll { $0.id == id }; saveCVData(); editingTarget = nil }

    // MARK: - Certification

    func startAddCertification()              { draftCertification = Certification(); editingTarget = .certification(nil) }
    func startEditCertification(_ c: Certification) { draftCertification = c;        editingTarget = .certification(c.id) }

    func saveCertification() {
        guard case .certification(let id) = editingTarget else { return }
        var draft = draftCertification
        draft.highlights = draft.highlights.filter { !$0.isEmpty }
        if let id, let idx = cvData.certifications.firstIndex(where: { $0.id == id }) {
            cvData.certifications[idx] = draft
        } else { cvData.certifications.append(draft) }
        saveCVData(); editingTarget = nil
    }

    func deleteCertification(id: String) { cvData.certifications.removeAll { $0.id == id }; saveCVData(); editingTarget = nil }

    // MARK: - Organization

    func startAddOrganization()               { draftOrganization = Organization(); editingTarget = .organization(nil) }
    func startEditOrganization(_ o: Organization) { draftOrganization = o;          editingTarget = .organization(o.id) }

    func saveOrganization() {
        guard case .organization(let id) = editingTarget else { return }
        var draft = draftOrganization
        draft.highlights = draft.highlights.filter { !$0.isEmpty }
        if let id, let idx = cvData.organizations.firstIndex(where: { $0.id == id }) {
            cvData.organizations[idx] = draft
        } else { cvData.organizations.append(draft) }
        saveCVData(); editingTarget = nil
    }

    func deleteOrganization(id: String) { cvData.organizations.removeAll { $0.id == id }; saveCVData(); editingTarget = nil }

    // MARK: - Achievement

    func startAddAchievement()               { draftAchievement = Achievement(); editingTarget = .achievement(nil) }
    func startEditAchievement(_ a: Achievement) { draftAchievement = a;          editingTarget = .achievement(a.id) }

    func saveAchievement() {
        guard case .achievement(let id) = editingTarget else { return }
        let draft = draftAchievement
        if let id, let idx = cvData.achievements.firstIndex(where: { $0.id == id }) {
            cvData.achievements[idx] = draft
        } else { cvData.achievements.append(draft) }
        saveCVData(); editingTarget = nil
    }

    func deleteAchievement(id: String) { cvData.achievements.removeAll { $0.id == id }; saveCVData(); editingTarget = nil }

    func cancelEditing() { editingTarget = nil }

    // MARK: - CV Import

    // Called from View after synchronous text extraction (while NSOpenPanel access is still valid)
    func importCV(fromText text: String) {
        guard #available(macOS 26.0, *) else { return }
        isImporting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isImporting = false }
            do {
                let (basic, sections) = try await CVImportService.parseCV(from: text)
                let (newProfile, newCVData) = CVImportService.apply(
                    basic: basic, sections: sections,
                    preservingPhoto: self.profile.photoData
                )
                self.pendingImportProfile = newProfile
                self.pendingImportCVData = newCVData
                self.importSummaryLine = Self.makeSummaryLine(profile: newProfile, cvData: newCVData)
                self.showImportConfirm = true
            } catch let e as CVImportService.ImportError {
                self.importError = e.errorDescription ?? "Import failed."
                self.showImportError = true
            } catch {
                self.importError = "Parsing failed: \(error.localizedDescription)"
                self.showImportError = true
            }
        }
    }

    func confirmImport() {
        if let newProfile = pendingImportProfile, let newCVData = pendingImportCVData {
            profile = newProfile
            cvData = newCVData
            cvData.profile = newProfile
            saveProfile()
            saveCVData()
            showReviewNotice = true
        }
        pendingImportProfile = nil
        pendingImportCVData = nil
        showImportConfirm = false
    }

    func cancelImport() {
        pendingImportProfile = nil
        pendingImportCVData = nil
        showImportConfirm = false
        showImportError = false
        importError = nil
    }

    private static func makeSummaryLine(profile: UserProfile, cvData: CVData) -> String {
        var parts: [String] = []
        if !profile.name.isEmpty { parts.append(profile.name) }
        if !cvData.experiences.isEmpty {
            let n = cvData.experiences.count
            parts.append("\(n) experience\(n == 1 ? "" : "s")")
        }
        if !cvData.educations.isEmpty {
            let n = cvData.educations.count
            parts.append("\(n) education entr\(n == 1 ? "y" : "ies")")
        }
        if !cvData.projects.isEmpty {
            let n = cvData.projects.count
            parts.append("\(n) project\(n == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Photo

    func updatePhoto(url: URL) {
        guard let img = NSImage(contentsOf: url) else { return }
        let size = NSSize(width: 200, height: 200)
        let resized = NSImage(size: size, flipped: false) { rect in img.draw(in: rect); return true }
        guard let tiff = resized.tiffRepresentation,
              let bmp  = NSBitmapImageRep(data: tiff),
              let jpeg = bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else { return }
        profile.photoData = jpeg
        saveProfile()
    }

    // MARK: - Persist

    func saveProfile() { profileRepository.saveProfile(profile) }
    func saveCVData()  { cvRepository.saveCVData(cvData) }
}
