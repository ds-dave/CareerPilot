import Foundation

enum WorkModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case onsite, hybrid, remote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onsite: "Vor Ort"
        case .hybrid: "Hybrid"
        case .remote: "Remote"
        }
    }
}

enum ApplicationSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case linkedIn, indeed, stepStone, xing, companySite, speculative, referral, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .linkedIn: "LinkedIn"
        case .indeed: "Indeed"
        case .stepStone: "StepStone"
        case .xing: "XING"
        case .companySite: "Karriereseite"
        case .speculative: "Initiativ"
        case .referral: "Empfehlung"
        case .other: "Sonstiges"
        }
    }
}

extension ApplicationSource {
    /// Erkennt bekannte Jobportale an der Adresse. Unbekannte Seiten ergeben `nil`.
    static func detect(from url: URL) -> ApplicationSource? {
        guard let host = url.host()?.lowercased() else { return nil }
        let known: [(String, ApplicationSource)] = [
            ("linkedin.", .linkedIn),
            ("indeed.", .indeed),
            ("stepstone.", .stepStone),
            ("xing.", .xing),
        ]
        return known.first { host.contains($0.0) }?.1
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case low, medium, high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Niedrig"
        case .medium: "Mittel"
        case .high: "Hoch"
        }
    }

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rank < rhs.rank
    }
}
