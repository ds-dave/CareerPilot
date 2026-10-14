import Foundation
import SwiftData

/// Eine Kontaktperson zu einer Bewerbung, z. B. Recruiterin oder Teamleiter.
@Model
final class ContactPerson {
    var name: String = ""
    var role: String = ""
    var email: String = ""
    var phone: String = ""
    var application: JobApplication?

    @Relationship(deleteRule: .nullify, inverse: \ApplicationEvent.contact)
    var events: [ApplicationEvent] = []

    init(name: String = "", role: String = "") {
        self.name = name
        self.role = role
    }
}

extension ContactPerson {
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Ohne Namen" : trimmed
    }

    var mailURL: URL? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@"), !trimmed.contains(where: \.isWhitespace) else { return nil }
        return URL(string: "mailto:\(trimmed)")
    }

    var phoneURL: URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard digits.count >= 3 else { return nil }
        return URL(string: "tel:\(digits)")
    }
}
