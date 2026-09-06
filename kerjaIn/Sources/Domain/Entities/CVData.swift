import Foundation

struct CVData: Codable, Equatable {
    var profile: UserProfile
    var educations: [Education]
    var experiences: [WorkExperience]
    var projects: [Project]
    var certifications: [Certification]
    var organizations: [Organization]
    var achievements: [Achievement]

    static let empty = CVData(
        profile: .empty,
        educations: [], experiences: [], projects: [], certifications: [],
        organizations: [], achievements: []
    )

    enum CodingKeys: CodingKey {
        case profile, educations, experiences, projects, certifications, organizations, achievements
    }

    init(profile: UserProfile, educations: [Education], experiences: [WorkExperience],
         projects: [Project], certifications: [Certification],
         organizations: [Organization] = [], achievements: [Achievement] = []) {
        self.profile = profile; self.educations = educations
        self.experiences = experiences; self.projects = projects
        self.certifications = certifications
        self.organizations = organizations; self.achievements = achievements
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile        = try c.decode(UserProfile.self, forKey: .profile)
        educations     = (try? c.decode([Education].self,      forKey: .educations))     ?? []
        experiences    = (try? c.decode([WorkExperience].self, forKey: .experiences))    ?? []
        projects       = (try? c.decode([Project].self,        forKey: .projects))       ?? []
        certifications = (try? c.decode([Certification].self,  forKey: .certifications)) ?? []
        organizations  = (try? c.decode([Organization].self,   forKey: .organizations))  ?? []
        achievements   = (try? c.decode([Achievement].self,    forKey: .achievements))   ?? []
    }
}

struct Education: Codable, Equatable, Identifiable {
    var id: String
    var institution: String  // School
    var degree: String
    var fieldOfStudy: String
    var startYear: String
    var year: String         // End
    var gpa: String
    var highlights: [String]

    init(id: String = UUID().uuidString, institution: String = "", degree: String = "",
         fieldOfStudy: String = "", startYear: String = "", year: String = "",
         gpa: String = "", highlights: [String] = [""]) {
        self.id = id; self.institution = institution; self.degree = degree
        self.fieldOfStudy = fieldOfStudy; self.startYear = startYear
        self.year = year; self.gpa = gpa; self.highlights = highlights
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        institution  = (try? c.decode(String.self, forKey: .institution)) ?? ""
        degree       = (try? c.decode(String.self, forKey: .degree)) ?? ""
        fieldOfStudy = (try? c.decode(String.self, forKey: .fieldOfStudy)) ?? ""
        startYear    = (try? c.decode(String.self, forKey: .startYear)) ?? ""
        year         = (try? c.decode(String.self, forKey: .year)) ?? ""
        gpa          = (try? c.decode(String.self, forKey: .gpa)) ?? ""
        highlights   = (try? c.decode([String].self, forKey: .highlights)) ?? []
    }
}

struct WorkExperience: Codable, Equatable, Identifiable {
    var id: String
    var company: String      // Organization
    var role: String         // Role / title
    var startDate: String    // Start
    var duration: String     // End
    var location: String
    var description: String
    var highlights: [String]

    init(id: String = UUID().uuidString, company: String = "", role: String = "",
         startDate: String = "", duration: String = "", location: String = "",
         description: String = "", highlights: [String] = [""]) {
        self.id = id; self.company = company; self.role = role
        self.startDate = startDate; self.duration = duration; self.location = location
        self.description = description; self.highlights = highlights
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        company     = (try? c.decode(String.self, forKey: .company)) ?? ""
        role        = (try? c.decode(String.self, forKey: .role)) ?? ""
        startDate   = (try? c.decode(String.self, forKey: .startDate)) ?? ""
        duration    = (try? c.decode(String.self, forKey: .duration)) ?? ""
        location    = (try? c.decode(String.self, forKey: .location)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        highlights  = (try? c.decode([String].self, forKey: .highlights)) ?? []
    }
}

struct Project: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var role: String
    var techStack: String
    var highlights: [String]
    var links: [ProfileLink]  // e.g. [("video demo", url), ("GitHub", url)]

    init(id: String = UUID().uuidString, name: String = "", role: String = "",
         techStack: String = "", highlights: [String] = [""], links: [ProfileLink] = []) {
        self.id = id; self.name = name; self.role = role
        self.techStack = techStack; self.highlights = highlights; self.links = links
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = (try? c.decode(String.self,        forKey: .id))         ?? UUID().uuidString
        name       = (try? c.decode(String.self,        forKey: .name))       ?? ""
        role       = (try? c.decode(String.self,        forKey: .role))       ?? ""
        techStack  = (try? c.decode(String.self,        forKey: .techStack))  ?? ""
        highlights = (try? c.decode([String].self,      forKey: .highlights)) ?? []
        links      = (try? c.decode([ProfileLink].self, forKey: .links))      ?? []
    }
}

struct Certification: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var issuer: String
    var issueDate: String
    var credentialId: String
    var credentialURL: String  // link to view credential
    var highlights: [String]

    init(id: String = UUID().uuidString, name: String = "", issuer: String = "",
         issueDate: String = "", credentialId: String = "",
         credentialURL: String = "", highlights: [String] = [""]) {
        self.id = id; self.name = name; self.issuer = issuer
        self.issueDate = issueDate; self.credentialId = credentialId
        self.credentialURL = credentialURL; self.highlights = highlights
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = (try? c.decode(String.self,   forKey: .id))            ?? UUID().uuidString
        name          = (try? c.decode(String.self,   forKey: .name))          ?? ""
        issuer        = (try? c.decode(String.self,   forKey: .issuer))        ?? ""
        issueDate     = (try? c.decode(String.self,   forKey: .issueDate))     ?? ""
        credentialId  = (try? c.decode(String.self,   forKey: .credentialId))  ?? ""
        credentialURL = (try? c.decode(String.self,   forKey: .credentialURL)) ?? ""
        highlights    = (try? c.decode([String].self, forKey: .highlights))    ?? []
    }
}

struct Organization: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var role: String
    var startDate: String
    var endDate: String
    var highlights: [String]
    var credentialURL: String

    init(id: String = UUID().uuidString, name: String = "", role: String = "",
         startDate: String = "", endDate: String = "",
         highlights: [String] = [""], credentialURL: String = "") {
        self.id = id; self.name = name; self.role = role
        self.startDate = startDate; self.endDate = endDate
        self.highlights = highlights; self.credentialURL = credentialURL
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = (try? c.decode(String.self,   forKey: .id))            ?? UUID().uuidString
        name          = (try? c.decode(String.self,   forKey: .name))          ?? ""
        role          = (try? c.decode(String.self,   forKey: .role))          ?? ""
        startDate     = (try? c.decode(String.self,   forKey: .startDate))     ?? ""
        endDate       = (try? c.decode(String.self,   forKey: .endDate))       ?? ""
        highlights    = (try? c.decode([String].self, forKey: .highlights))    ?? []
        credentialURL = (try? c.decode(String.self,   forKey: .credentialURL)) ?? ""
    }
}

struct Achievement: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var issuer: String
    var date: String
    var notes: String
    var credentialURL: String

    init(id: String = UUID().uuidString, title: String = "", issuer: String = "",
         date: String = "", notes: String = "", credentialURL: String = "") {
        self.id = id; self.title = title; self.issuer = issuer
        self.date = date; self.notes = notes; self.credentialURL = credentialURL
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = (try? c.decode(String.self, forKey: .id))            ?? UUID().uuidString
        title         = (try? c.decode(String.self, forKey: .title))         ?? ""
        issuer        = (try? c.decode(String.self, forKey: .issuer))        ?? ""
        date          = (try? c.decode(String.self, forKey: .date))          ?? ""
        notes         = (try? c.decode(String.self, forKey: .notes))         ?? ""
        credentialURL = (try? c.decode(String.self, forKey: .credentialURL)) ?? ""
    }
}
