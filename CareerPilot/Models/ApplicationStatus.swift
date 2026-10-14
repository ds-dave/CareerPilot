import Foundation

/// Stationen einer Bewerbung, in der Reihenfolge des Boards.
/// Der Rohwert bleibt stabil (er liegt in der Datenbank), die Beschriftung darf sich ändern.
enum ApplicationStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case wishlist
    case applied
    case acknowledged
    case phoneScreen
    case interview
    case offer
    case accepted
    case rejected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wishlist: "Wunschliste"
        case .applied: "Beworben"
        case .acknowledged: "Eingangsbestätigung"
        case .phoneScreen: "Telefonat"
        case .interview: "Interview"
        case .offer: "Angebot"
        case .accepted: "Zusage"
        case .rejected: "Absage"
        }
    }

    /// Abgeschlossen: hier ist kein Nachfassen mehr nötig.
    var isFinished: Bool {
        self == .accepted || self == .rejected
    }

    /// Die Bewerbung ist (mindestens) abgeschickt worden.
    var isSubmitted: Bool {
        self != .wishlist
    }

    /// Stationen, die eine Antwort des Unternehmens bedeuten (auch eine Absage ist eine Antwort).
    static let responseStatuses: Set<ApplicationStatus> = [
        .acknowledged, .phoneScreen, .interview, .offer, .accepted, .rejected,
    ]

    /// Darstellung ohne Farbe: Punkt hohl, normal, betont oder gedämpft.
    enum Tone: Sendable {
        case idle, active, strong, closed
    }

    var tone: Tone {
        switch self {
        case .wishlist: .idle
        case .offer, .accepted: .strong
        case .rejected: .closed
        default: .active
        }
    }
}
