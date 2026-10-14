import Foundation
import SwiftData

// MARK: - Dateiformat

/// Das JSON-Backup. Die Version erlaubt es späteren App-Versionen, ältere Dateien zu lesen.
struct BackupFile: Codable, Equatable {
    static let formatName = "careerpilot-backup"
    static let currentVersion = 1

    var format: String = BackupFile.formatName
    var version: Int = BackupFile.currentVersion
    var exportedAt: Date
    var applications: [ApplicationRecord]
}

struct ApplicationRecord: Codable, Equatable {
    var uuid: UUID
    var company: String
    var position: String
    var status: ApplicationStatus
    var sortIndex: Int = 0
    var location: String = ""
    var workModel: WorkModel?
    var jobURL: String = ""
    var source: ApplicationSource?
    var sourceName: String = ""
    var priority: Priority = .medium
    var salaryMin: Int?
    var salaryMax: Int?
    var appliedOn: Date?
    var followUpOn: Date?
    var notes: String = ""
    var isArchived: Bool = false
    var createdAt: Date
    var tags: [String] = []
    /// Logo als PNG; JSON speichert es als Base64.
    var logo: Data?
    var timeline: [TimelineRecord] = []
    var contacts: [ContactRecord] = []
    var events: [EventRecord] = []
    var documents: [DocumentRecord] = []

    init(
        uuid: UUID, company: String, position: String, status: ApplicationStatus, createdAt: Date
    ) {
        self.uuid = uuid
        self.company = company
        self.position = position
        self.status = status
        self.createdAt = createdAt
    }

    /// Fehlende Felder bekommen Standardwerte, damit auch ältere oder von Hand gekürzte Dateien lesbar bleiben.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decode(UUID.self, forKey: .uuid)
        company = try c.decode(String.self, forKey: .company)
        position = try c.decode(String.self, forKey: .position)
        status = try c.decode(ApplicationStatus.self, forKey: .status)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        sortIndex = try c.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        workModel = try c.decodeIfPresent(WorkModel.self, forKey: .workModel)
        jobURL = try c.decodeIfPresent(String.self, forKey: .jobURL) ?? ""
        source = try c.decodeIfPresent(ApplicationSource.self, forKey: .source)
        sourceName = try c.decodeIfPresent(String.self, forKey: .sourceName) ?? ""
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .medium
        salaryMin = try c.decodeIfPresent(Int.self, forKey: .salaryMin)
        salaryMax = try c.decodeIfPresent(Int.self, forKey: .salaryMax)
        appliedOn = try c.decodeIfPresent(Date.self, forKey: .appliedOn)
        followUpOn = try c.decodeIfPresent(Date.self, forKey: .followUpOn)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        logo = try c.decodeIfPresent(Data.self, forKey: .logo)
        timeline = try c.decodeIfPresent([TimelineRecord].self, forKey: .timeline) ?? []
        contacts = try c.decodeIfPresent([ContactRecord].self, forKey: .contacts) ?? []
        events = try c.decodeIfPresent([EventRecord].self, forKey: .events) ?? []
        documents = try c.decodeIfPresent([DocumentRecord].self, forKey: .documents) ?? []
    }
}

struct TimelineRecord: Codable, Equatable {
    var kind: TimelineKind
    var date: Date
    var text: String = ""
    var fromStatus: ApplicationStatus?
    var toStatus: ApplicationStatus?
}

struct ContactRecord: Codable, Equatable {
    var name: String
    var role: String = ""
    var email: String = ""
    var phone: String = ""
}

struct EventRecord: Codable, Equatable {
    var uuid: UUID
    var kind: EventKind
    var title: String = ""
    var start: Date
    var durationMinutes: Int = 60
    var location: String = ""
    var meetingURL: String = ""
    var checklist: [ChecklistItem] = []
    var questions: [String] = []
    var debrief: String = ""
    var reminderLeadMinutes: Int?
    /// Position des Ansprechpartners in der Kontaktliste dieser Bewerbung.
    var contactIndex: Int?
}

struct DocumentRecord: Codable, Equatable {
    var uuid: UUID
    var fileName: String
    var kind: DocumentKind
    var addedAt: Date
    /// Der Dateiinhalt; JSON speichert ihn als Base64.
    var data: Data
}

// MARK: - Fehler und Ergebnis

enum BackupError: LocalizedError, Equatable {
    case notABackup
    case newerVersion(Int)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notABackup:
            "Diese Datei ist kein CareerPilot-Backup."
        case .newerVersion:
            "Das Backup stammt aus einer neueren Version von CareerPilot. Bitte aktualisiere die App."
        case .unreadable:
            "Die Datei konnte nicht gelesen werden. Sie ist vermutlich beschädigt."
        }
    }
}

struct ImportSummary: Equatable {
    var added = 0
    var skipped = 0
    var skippedDocuments = 0

    var message: String {
        var parts: [String] = []
        parts.append(added == 1 ? "1 Bewerbung hinzugefügt" : "\(added) Bewerbungen hinzugefügt")
        if skipped > 0 {
            parts.append(skipped == 1 ? "1 war schon vorhanden" : "\(skipped) waren schon vorhanden")
        }
        if skippedDocuments > 0 {
            parts.append("\(skippedDocuments) Dokument\(skippedDocuments == 1 ? "" : "e") übersprungen")
        }
        return parts.joined(separator: ", ") + "."
    }
}

// MARK: - Umwandlung

enum BackupCodec {
    /// Größer als das hier ist keine plausible Sicherung, und das Lesen würde zu viel Speicher brauchen.
    static let maxFileBytes = 1_024 * 1_048_576

    // MARK: Export

    static func makeBackup(
        from applications: [JobApplication], includeDocuments: Bool = true, now: Date = .now
    ) -> BackupFile {
        let records = applications
            .sorted { $0.createdAt < $1.createdAt }
            .map { record(from: $0, includeDocuments: includeDocuments) }
        return BackupFile(exportedAt: now, applications: records)
    }

    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(file)
    }

    private static func record(from application: JobApplication, includeDocuments: Bool) -> ApplicationRecord {
        var record = ApplicationRecord(
            uuid: application.uuid, company: application.company, position: application.position,
            status: application.status, createdAt: application.createdAt
        )
        record.sortIndex = application.sortIndex
        record.location = application.location
        record.workModel = application.workModel
        record.jobURL = application.jobURLString
        record.source = application.source
        record.sourceName = application.sourceName
        record.priority = application.priority
        record.salaryMin = application.salaryMin
        record.salaryMax = application.salaryMax
        record.appliedOn = application.appliedOn
        record.followUpOn = application.followUpOn
        record.notes = application.notes
        record.isArchived = application.isArchived
        record.tags = application.tags
        record.logo = includeDocuments ? application.logoData : nil

        record.timeline = application.timeline
            .sorted { $0.date < $1.date }
            .map {
                TimelineRecord(kind: $0.kind, date: $0.date, text: $0.text,
                               fromStatus: $0.fromStatus, toStatus: $0.toStatus)
            }

        let contacts = application.contacts
        record.contacts = contacts.map {
            ContactRecord(name: $0.name, role: $0.role, email: $0.email, phone: $0.phone)
        }

        record.events = application.events
            .sorted { $0.start < $1.start }
            .map { event in
                EventRecord(
                    uuid: event.uuid, kind: event.kind, title: event.title, start: event.start,
                    durationMinutes: event.durationMinutes, location: event.location,
                    meetingURL: event.meetingURLString, checklist: event.checklist,
                    questions: event.questions, debrief: event.debrief,
                    reminderLeadMinutes: event.reminderLeadMinutes,
                    contactIndex: event.contact.flatMap { contact in
                        contacts.firstIndex { $0 === contact }
                    }
                )
            }

        if includeDocuments {
            record.documents = application.documents
                .sorted { $0.addedAt < $1.addedAt }
                .map {
                    DocumentRecord(uuid: $0.uuid, fileName: $0.fileName, kind: $0.kind,
                                   addedAt: $0.addedAt, data: $0.data)
                }
        }
        return record
    }

    // MARK: Import

    static func decode(_ data: Data) throws -> BackupFile {
        guard data.count <= maxFileBytes else { throw BackupError.unreadable }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Erst nur den Kopf lesen: so lässt sich "falsche Datei" von "beschädigte Datei" unterscheiden.
        struct Header: Decodable {
            var format: String
            var version: Int
        }
        guard let header = try? decoder.decode(Header.self, from: data),
              header.format == BackupFile.formatName
        else { throw BackupError.notABackup }
        guard header.version <= BackupFile.currentVersion else {
            throw BackupError.newerVersion(header.version)
        }
        do {
            return try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
    }

    /// Fügt die Bewerbungen aus dem Backup hinzu. Was es per UUID schon gibt, bleibt unverändert.
    @discardableResult
    static func restore(
        _ file: BackupFile, into context: ModelContext, existing: Set<UUID>
    ) -> ImportSummary {
        var summary = ImportSummary()
        var known = existing

        for record in file.applications {
            guard known.insert(record.uuid).inserted else {
                summary.skipped += 1
                continue
            }
            let application = JobApplication(
                company: record.company, position: record.position, status: record.status
            )
            application.uuid = record.uuid
            application.sortIndex = record.sortIndex
            application.location = record.location
            application.workModel = record.workModel
            application.jobURLString = record.jobURL
            application.source = record.source
            application.sourceName = record.sourceName
            application.priority = record.priority
            application.salaryMin = record.salaryMin
            application.salaryMax = record.salaryMax
            application.appliedOn = record.appliedOn
            application.followUpOn = record.followUpOn
            application.notes = record.notes
            application.isArchived = record.isArchived
            application.createdAt = record.createdAt
            application.tags = record.tags
            // Auch Logos aus fremden Dateien laufen durch die Bildprüfung.
            if let logo = record.logo { application.setLogo(from: logo) }

            for entry in record.timeline {
                application.timeline.append(
                    TimelineEntry(kind: entry.kind, date: entry.date, text: entry.text,
                                  from: entry.fromStatus, to: entry.toStatus)
                )
            }

            var contacts: [ContactPerson] = []
            for item in record.contacts {
                let contact = ContactPerson(name: item.name, role: item.role)
                contact.email = item.email
                contact.phone = item.phone
                application.contacts.append(contact)
                contacts.append(contact)
            }

            for item in record.events {
                let event = ApplicationEvent(kind: item.kind, start: item.start, durationMinutes: item.durationMinutes)
                event.uuid = item.uuid
                event.title = item.title
                event.location = item.location
                event.meetingURLString = item.meetingURL
                event.checklist = item.checklist
                event.questions = item.questions
                event.debrief = item.debrief
                event.reminderLeadMinutes = item.reminderLeadMinutes
                application.events.append(event)
                if let index = item.contactIndex, contacts.indices.contains(index) {
                    event.contact = contacts[index]
                }
            }

            for item in record.documents {
                // Dokumente aus fremden Dateien durchlaufen dieselbe Prüfung wie beim Hinzufügen.
                do {
                    let document = try application.addDocument(
                        data: item.data, fileName: item.fileName, kind: item.kind, now: item.addedAt
                    )
                    document.uuid = item.uuid
                } catch {
                    summary.skippedDocuments += 1
                }
            }

            context.insert(application)
            summary.added += 1
        }
        return summary
    }
}
