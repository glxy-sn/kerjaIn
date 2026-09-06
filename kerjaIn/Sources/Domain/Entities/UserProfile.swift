import Foundation

struct ProfileLink: Codable, Equatable {
    var label: String  // e.g. "GitHub", "Portfolio", "LinkedIn"
    var url: String
}

struct UserProfile: Codable, Equatable {
    var name: String
    var email: String
    var phone: String
    var address: String
    var skills: [String]
    var summary: String
    var links: [ProfileLink]
    var photoData: Data?

    static let empty = UserProfile(
        name: "", email: "", phone: "", address: "",
        skills: [], summary: "", links: [], photoData: nil
    )

    enum CodingKeys: CodingKey {
        case name, email, phone, address, skills, summary, links, photoData
    }

    init(name: String, email: String, phone: String, address: String,
         skills: [String], summary: String, links: [ProfileLink] = [], photoData: Data? = nil) {
        self.name = name; self.email = email; self.phone = phone
        self.address = address; self.skills = skills; self.summary = summary
        self.links = links; self.photoData = photoData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name      = (try? c.decode(String.self, forKey: .name))         ?? ""
        email     = (try? c.decode(String.self, forKey: .email))        ?? ""
        phone     = (try? c.decode(String.self, forKey: .phone))        ?? ""
        address   = (try? c.decode(String.self, forKey: .address))      ?? ""
        skills    = (try? c.decode([String].self, forKey: .skills))     ?? []
        summary   = (try? c.decode(String.self, forKey: .summary))      ?? ""
        photoData = try? c.decode(Data.self, forKey: .photoData)
        // Migrate old [String] links to [ProfileLink]
        if let newLinks = try? c.decode([ProfileLink].self, forKey: .links) {
            links = newLinks
        } else if let oldLinks = try? c.decode([String].self, forKey: .links) {
            links = oldLinks.map { ProfileLink(label: "Link", url: $0) }
        } else {
            links = []
        }
    }
}
