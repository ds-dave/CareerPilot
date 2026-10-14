import Foundation
import SwiftData

enum TimelineKind: String, Codable, Sendable {
    case statusChanged
    case note
}

/// Ein Eintrag im Verlauf einer Bewerbung: automatisch protokollierte Statuswechsel und eigene Notizen.
@Model
final class TimelineEntry {
    var kind: TimelineKind = TimelineKind.note
    var date: Date = Date()
    var text: String = ""
    var fromStatus: ApplicationStatus?
    var toStatus: ApplicationStatus?
    var application: JobApplication?

    init(
        kind: TimelineKind,
        date: Date = .now,
        text: String = "",
        from: ApplicationStatus? = nil,
        to: ApplicationStatus? = nil
    ) {
        self.kind = kind
        self.date = date
        self.text = text
        self.fromStatus = from
        self.toStatus = to
    }
}
