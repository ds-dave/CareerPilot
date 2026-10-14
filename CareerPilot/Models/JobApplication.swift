import Foundation
import SwiftData

/// Eine Bewerbung. Alle Eigenschaften haben Standardwerte, damit spätere
/// Schema-Erweiterungen ohne aufwendige Migration funktionieren.
@Model
final class JobApplication {
    var uuid: UUID = UUID()
    var company: String = ""
    var position: String = ""
    var status: ApplicationStatus = ApplicationStatus.wishlist
    var location: String = ""
    var workModel: WorkModel?
    var jobURLString: String = ""
    var source: ApplicationSource?
    /// Name des Portals, wenn die Quelle "Sonstiges" ist.
    var sourceName: String = ""
    var priority: Priority = Priority.medium
    var salaryMin: Int?
    var salaryMax: Int?
    var appliedOn: Date?
    var followUpOn: Date?
    var notes: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    /// Position innerhalb der Board-Spalte (aufsteigend).
    var sortIndex: Int = 0
    var tags: [String] = []

    /// Das Logo der Firma als kleines PNG (siehe `LogoImageProcessor`).
    @Attribute(.externalStorage)
    var logoData: Data?

    @Relationship(deleteRule: .cascade, inverse: \TimelineEntry.application)
    var timeline: [TimelineEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \ApplicationEvent.application)
    var events: [ApplicationEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \ContactPerson.application)
    var contacts: [ContactPerson] = []

    @Relationship(deleteRule: .cascade, inverse: \ApplicationDocument.application)
    var documents: [ApplicationDocument] = []

    init(company: String, position: String, status: ApplicationStatus = .wishlist) {
        self.company = company
        self.position = position
        self.status = status
    }
}

// MARK: - Fachlogik

/// Wie dringend das Nachfassen bei einer Bewerbung ist.
enum FollowUpState: Equatable, Sendable {
    case none
    case upcoming(days: Int)
    case dueToday
    case overdue(days: Int)

    var needsAttention: Bool {
        switch self {
        case .dueToday, .overdue: true
        case .none, .upcoming: false
        }
    }
}

extension JobApplication {
    /// Gültiger http(s)-Link zur Anzeige, sonst `nil`. Eine Adresse ohne Schema
    /// (z. B. `stepstone.de/jobs/42`) wird als https-Link gelesen.
    var jobURL: URL? {
        Self.parseLink(jobURLString)
    }

    static func parseLink(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        var candidate = trimmed
        if !candidate.contains("://") {
            // Etwas wie "javascript:alert(1)" oder "mailto:x" hat ein Schema ohne "//" und fällt hier raus.
            guard let dot = candidate.firstIndex(of: ".") else { return nil }
            if let colon = candidate.firstIndex(of: ":"), colon < dot { return nil }
            candidate = "https://" + candidate
        }
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(), host.contains(".")
        else { return nil }
        return url
    }

    /// Trägt die Quelle ein, wenn noch keine gesetzt ist und der Link ein bekanntes Portal ist.
    func detectSourceFromLink() {
        guard source == nil, let url = jobURL, let detected = ApplicationSource.detect(from: url) else { return }
        source = detected
    }

    /// Name des Portals für die Anzeige: bei "Sonstiges" der eigene Name.
    var portalTitle: String? {
        guard let source else { return nil }
        if source == .other {
            let custom = sourceName.trimmingCharacters(in: .whitespaces)
            return custom.isEmpty ? source.title : custom
        }
        return source.title
    }

    /// Anzeigename für Listen, auch wenn die Firma noch leer ist.
    var displayCompany: String {
        company.trimmingCharacters(in: .whitespaces).isEmpty ? "Ohne Firma" : company
    }

    /// Vergangene Tage seit der Bewerbung. `nil`, solange kein Datum gesetzt ist.
    func daysSinceApplied(now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let appliedOn else { return nil }
        return Self.days(from: appliedOn, to: now, calendar: calendar)
    }

    func followUpState(now: Date = .now, calendar: Calendar = .current) -> FollowUpState {
        guard let followUpOn, !isArchived, !status.isFinished else { return .none }
        let days = Self.days(from: now, to: followUpOn, calendar: calendar)
        if days < 0 { return .overdue(days: -days) }
        if days == 0 { return .dueToday }
        return .upcoming(days: days)
    }

    /// Vorschlag für das Nachfass-Datum: `days` Tage nach dem Abschicken, solange noch keine Antwort kam
    /// (Status "Beworben") und noch kein Datum gesetzt ist.
    func suggestedFollowUp(afterDays days: Int, calendar: Calendar = .current) -> Date? {
        guard status == .applied, !isArchived, followUpOn == nil, let appliedOn else { return nil }
        let day = calendar.startOfDay(for: appliedOn)
        return calendar.date(byAdding: .day, value: days, to: day)
    }

    /// Alle Stationen, die die Bewerbung je erreicht hat (aktueller Status plus Verlauf).
    var reachedStatuses: Set<ApplicationStatus> {
        var reached: Set<ApplicationStatus> = [status]
        for entry in timeline where entry.kind == .statusChanged {
            if let from = entry.fromStatus { reached.insert(from) }
            if let to = entry.toStatus { reached.insert(to) }
        }
        return reached
    }

    /// Zeitpunkt der ersten Antwort laut Verlauf, `nil` wenn unbekannt.
    var firstResponseDate: Date? {
        timeline
            .filter { $0.kind == .statusChanged }
            .filter { entry in entry.toStatus.map(ApplicationStatus.responseStatuses.contains) ?? false }
            .map(\.date)
            .min()
    }

    /// Setzt das Logo aus beliebigen Bilddaten. Gibt `false` zurück, wenn es kein lesbares Bild ist;
    /// das bisherige Logo bleibt dann erhalten.
    @discardableResult
    func setLogo(from imageData: Data) -> Bool {
        guard let normalized = LogoImageProcessor.normalized(imageData) else { return false }
        logoData = normalized
        return true
    }

    /// Hängt ein geprüftes PDF an. Wirft einen `DocumentImportError`, wenn die Datei nicht passt.
    @discardableResult
    func addDocument(
        data: Data, fileName: String, kind: DocumentKind? = nil, now: Date = .now
    ) throws -> ApplicationDocument {
        try DocumentImporter.validate(data: data, fileName: fileName)
        let name = DocumentImporter.sanitizedName(fileName)
        let document = ApplicationDocument(
            fileName: name,
            kind: kind ?? DocumentImporter.suggestedKind(forFileName: name),
            data: data,
            addedAt: now
        )
        documents.append(document)
        return document
    }

    /// Der nächste Termin ab `now`.
    func nextEvent(now: Date = .now) -> ApplicationEvent? {
        events.filter { $0.start >= now }.min { $0.start < $1.start }
    }

    /// Eine Bewerbung gilt als offen, solange sie weder archiviert noch abgeschlossen ist.
    var isOpen: Bool {
        !isArchived && !status.isFinished
    }

    /// Alle Suchbegriffe (durch Leerzeichen getrennt) müssen in einem der Felder vorkommen.
    func matches(search text: String) -> Bool {
        let terms = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return true }
        let haystacks = [company, position, location, notes, status.title] + tags
        return terms.allSatisfy { term in
            haystacks.contains { $0.localizedStandardContains(term) }
        }
    }

    /// Setzt den Status, protokolliert den Wechsel im Verlauf und trägt das Bewerbungsdatum ein,
    /// wenn die Bewerbung abgeschickt wird.
    func change(status newStatus: ApplicationStatus, now: Date = .now, calendar: Calendar = .current) {
        guard newStatus != status else { return }
        timeline.append(TimelineEntry(kind: .statusChanged, date: now, from: status, to: newStatus))
        status = newStatus
        if newStatus.isSubmitted, appliedOn == nil {
            appliedOn = calendar.startOfDay(for: now)
        }
    }

    /// Kopie als Vorlage: gleiche Stelle, frischer Status, ohne Datumsangaben.
    func duplicated() -> JobApplication {
        let copy = JobApplication(company: company, position: position, status: .wishlist)
        copy.location = location
        copy.workModel = workModel
        copy.jobURLString = jobURLString
        copy.source = source
        copy.sourceName = sourceName
        copy.priority = priority
        copy.salaryMin = salaryMin
        copy.salaryMax = salaryMax
        copy.notes = notes
        copy.tags = tags
        copy.logoData = logoData
        return copy
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
