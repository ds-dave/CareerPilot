import Foundation
import SwiftData

enum EventKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case phone
    case interview
    case technical
    case trial
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phone: "Telefonat"
        case .interview: "Interview"
        case .technical: "Fachgespräch"
        case .trial: "Probearbeiten"
        case .other: "Termin"
        }
    }

    var systemImage: String {
        switch self {
        case .phone: "phone"
        case .interview: "person.2"
        case .technical: "wrench.and.screwdriver"
        case .trial: "briefcase"
        case .other: "calendar"
        }
    }
}

/// Ein Punkt der Vorbereitungs-Checkliste.
struct ChecklistItem: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var text: String
    var isDone = false
}

/// Ein Termin zu einer Bewerbung: Telefonat, Interview, Fachgespräch, Probearbeiten.
@Model
final class ApplicationEvent {
    var uuid: UUID = UUID()
    var kind: EventKind = EventKind.interview
    /// Eigener Titel; leer heißt: die Art des Termins ist der Titel.
    var title: String = ""
    var start: Date = Date()
    var durationMinutes: Int = 60
    var location: String = ""
    var meetingURLString: String = ""
    var checklist: [ChecklistItem] = []
    var questions: [String] = []
    /// Nachbereitung (Markdown).
    var debrief: String = ""
    /// Minuten vor dem Termin; `nil` nimmt den Standard aus den Einstellungen, negativ heißt keine Erinnerung.
    var reminderLeadMinutes: Int?

    var application: JobApplication?
    var contact: ContactPerson?

    init(kind: EventKind = .interview, start: Date = Date(), durationMinutes: Int = 60) {
        self.kind = kind
        self.start = start
        self.durationMinutes = durationMinutes
    }
}

extension ApplicationEvent {
    var displayTitle: String {
        let custom = title.trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? kind.title : custom
    }

    var end: Date {
        start.addingTimeInterval(TimeInterval(max(durationMinutes, 0) * 60))
    }

    var meetingURL: URL? {
        JobApplication.parseLink(meetingURLString)
    }

    /// Anteil erledigter Punkte der Checkliste, `nil` ohne Checkliste.
    var checklistProgress: (done: Int, total: Int)? {
        guard !checklist.isEmpty else { return nil }
        return (checklist.filter(\.isDone).count, checklist.count)
    }
}
