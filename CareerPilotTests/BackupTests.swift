import Foundation
import SwiftData
import Testing

@testable import CareerPilot

private func pdf(_ text: String = "x") -> Data {
    Data("%PDF-1.4\n\(text)\n%%EOF".utf8)
}

/// Eine Bewerbung mit allem, was ein Backup enthalten muss.
@MainActor
private func richApplication() throws -> JobApplication {
    let application = JobApplication(company: "Nordlicht, \"Software\"; GmbH", position: "Backend-Entwickler", status: .interview)
    application.location = "Hamburg"
    application.workModel = .hybrid
    application.jobURLString = "https://example.com/jobs/1"
    application.source = .other
    application.sourceName = "Honeypot"
    application.priority = .high
    application.salaryMin = 62_000
    application.salaryMax = 74_000
    application.appliedOn = Date(timeIntervalSince1970: 1_790_000_000)
    application.followUpOn = Date(timeIntervalSince1970: 1_790_500_000)
    application.notes = "## Notizen\n- Zeile 1\n- Zeile 2"
    application.tags = ["Java", "Hybrid"]
    application.sortIndex = 3
    application.timeline.append(
        TimelineEntry(kind: .statusChanged, date: Date(timeIntervalSince1970: 1_790_100_000), from: .applied, to: .interview)
    )
    application.timeline.append(
        TimelineEntry(kind: .note, date: Date(timeIntervalSince1970: 1_790_200_000), text: "Netter Kontakt")
    )

    let contact = ContactPerson(name: "Mara Beispiel", role: "Team-Lead")
    contact.email = "mara@example.com"
    contact.phone = "+49 40 555"
    application.contacts.append(contact)

    let event = ApplicationEvent(kind: .interview, start: Date(timeIntervalSince1970: 1_791_000_000), durationMinutes: 90)
    event.title = "Zweite Runde"
    event.location = "Hamburg"
    event.meetingURLString = "https://meet.example.com/x"
    event.checklist = [ChecklistItem(text: "Fragen", isDone: true), ChecklistItem(text: "Unterlagen")]
    event.questions = ["Wie groß ist das Team?"]
    event.debrief = "Lief gut."
    event.reminderLeadMinutes = 30
    event.contact = contact
    application.events.append(event)

    try application.addDocument(data: pdf("Lebenslauf"), fileName: "Lebenslauf.pdf")
    return application
}

@MainActor
@Suite("Backup")
struct BackupTests {
    @Test("Export und Import ergeben dieselbe Bewerbung, mit Verlauf, Terminen, Kontakten und Dokumenten")
    func roundTrip() throws {
        let sourceContainer = try AppSchema.makeContainer(inMemory: true)
        let source = sourceContainer.mainContext
        let original = try richApplication()
        source.insert(original)
        try source.save()

        let data = try BackupCodec.encode(BackupCodec.makeBackup(from: [original]))
        let file = try BackupCodec.decode(data)

        let targetContainer = try AppSchema.makeContainer(inMemory: true)
        let target = targetContainer.mainContext
        let summary = BackupCodec.restore(file, into: target, existing: [])
        try target.save()
        #expect(summary == ImportSummary(added: 1, skipped: 0, skippedDocuments: 0))

        let restored = try #require(try target.fetch(FetchDescriptor<JobApplication>()).first)
        #expect(restored.uuid == original.uuid)
        #expect(restored.company == original.company)
        #expect(restored.status == .interview)
        #expect(restored.workModel == .hybrid)
        #expect(restored.source == .other)
        #expect(restored.sourceName == "Honeypot")
        #expect(restored.priority == .high)
        #expect(restored.salaryMin == 62_000)
        #expect(restored.appliedOn == original.appliedOn)
        #expect(restored.notes == original.notes)
        #expect(restored.tags == ["Java", "Hybrid"])
        #expect(restored.sortIndex == 3)
        #expect(restored.timeline.count == 2)
        #expect(restored.timeline.contains { $0.kind == .statusChanged && $0.toStatus == .interview })
        #expect(restored.contacts.count == 1)
        #expect(restored.contacts.first?.email == "mara@example.com")

        let event = try #require(restored.events.first)
        #expect(event.title == "Zweite Runde")
        #expect(event.durationMinutes == 90)
        #expect(event.checklist.map(\.text) == ["Fragen", "Unterlagen"])
        #expect(event.checklist.first?.isDone == true)
        #expect(event.questions == ["Wie groß ist das Team?"])
        #expect(event.reminderLeadMinutes == 30)
        #expect(event.contact?.name == "Mara Beispiel")

        let document = try #require(restored.documents.first)
        #expect(document.fileName == "Lebenslauf.pdf")
        #expect(document.kind == .resume)
        #expect(document.data == pdf("Lebenslauf"))
    }

    @Test("Ein zweiter Import überspringt vorhandene Bewerbungen")
    func importIsIdempotent() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let item = try richApplication()
        context.insert(item)
        let file = BackupCodec.makeBackup(from: [item])

        let first = BackupCodec.restore(file, into: context, existing: [item.uuid])
        #expect(first == ImportSummary(added: 0, skipped: 1, skippedDocuments: 0))
        #expect(try context.fetchCount(FetchDescriptor<JobApplication>()) == 1)

        let otherContainer = try AppSchema.makeContainer(inMemory: true)
        let other = otherContainer.mainContext
        let one = BackupCodec.restore(file, into: other, existing: [])
        #expect(one.added == 1)
        try other.save()
        let ids = Set(try other.fetch(FetchDescriptor<JobApplication>()).map(\.uuid))
        let two = BackupCodec.restore(file, into: other, existing: ids)
        #expect(two.added == 0)
        #expect(two.skipped == 1)
        #expect(try other.fetchCount(FetchDescriptor<JobApplication>()) == 1)
    }

    @Test("Backup ohne Dokumente lässt sie weg")
    func withoutDocuments() throws {
        let item = try richApplication()
        let file = BackupCodec.makeBackup(from: [item], includeDocuments: false)
        #expect(file.applications.first?.documents.isEmpty == true)
    }

    @Test("Falsche und neuere Dateien werden mit klarer Meldung abgelehnt")
    func rejects() throws {
        #expect(throws: BackupError.notABackup) { try BackupCodec.decode(Data("[1,2,3]".utf8)) }
        #expect(throws: BackupError.notABackup) { try BackupCodec.decode(Data("{\"format\":\"anderes\",\"version\":1}".utf8)) }
        #expect(throws: BackupError.newerVersion(99)) {
            try BackupCodec.decode(Data("{\"format\":\"careerpilot-backup\",\"version\":99,\"applications\":[]}".utf8))
        }
        #expect(throws: BackupError.unreadable) {
            try BackupCodec.decode(Data("{\"format\":\"careerpilot-backup\",\"version\":1,\"applications\":[{\"nope\":1}]}".utf8))
        }
    }

    @Test("Fehlende optionale Felder bekommen Standardwerte")
    func toleratesMissingFields() throws {
        let json = """
        {"format":"careerpilot-backup","version":1,"exportedAt":"2026-10-10T10:00:00Z",
         "applications":[{"uuid":"\(UUID().uuidString)","company":"Minimal AG","position":"Dev","status":"applied"}]}
        """
        let file = try BackupCodec.decode(Data(json.utf8))
        let record = try #require(file.applications.first)
        #expect(record.priority == .medium)
        #expect(record.tags.isEmpty)
        #expect(record.events.isEmpty)

        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        #expect(BackupCodec.restore(file, into: context, existing: []).added == 1)
    }

    @Test("Ungültige PDFs im Backup werden übersprungen und gezählt")
    func invalidDocumentsAreSkipped() throws {
        var record = ApplicationRecord(uuid: UUID(), company: "Firma", position: "Dev", status: .applied, createdAt: .now)
        record.documents = [
            DocumentRecord(uuid: UUID(), fileName: "gut.pdf", kind: .resume, addedAt: .now, data: pdf()),
            DocumentRecord(uuid: UUID(), fileName: "boese.pdf", kind: .other, addedAt: .now, data: Data("MZ-kein-pdf".utf8)),
        ]
        let file = BackupFile(exportedAt: .now, applications: [record])
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let summary = BackupCodec.restore(file, into: context, existing: [])
        #expect(summary.added == 1)
        #expect(summary.skippedDocuments == 1)
        #expect(summary.message.contains("1 Dokument übersprungen"))
        let restored = try #require(try context.fetch(FetchDescriptor<JobApplication>()).first)
        #expect(restored.documents.count == 1)
    }

    @Test("Meldungstexte im Singular und Plural")
    func messages() {
        #expect(ImportSummary(added: 1).message == "1 Bewerbung hinzugefügt.")
        #expect(ImportSummary(added: 3, skipped: 2).message == "3 Bewerbungen hinzugefügt, 2 waren schon vorhanden.")
    }
}

@MainActor
@Suite("CSV")
struct CSVTests {
    @Test("Maskierung: Trenner, Anführungszeichen, Zeilenumbruch")
    func escaping() {
        #expect(CSVExporter.escape("Hallo") == "Hallo")
        #expect(CSVExporter.escape("a;b") == "\"a;b\"")
        #expect(CSVExporter.escape("er sagte \"ja\"") == "\"er sagte \"\"ja\"\"\"")
        #expect(CSVExporter.escape("Zeile 1\nZeile 2") == "\"Zeile 1\nZeile 2\"")
    }

    @Test("Formelzeichen am Anfang werden entschärft")
    func formulaInjection() {
        #expect(CSVExporter.escape("=HYPERLINK(\"http://böse\")").hasPrefix("\"'="))
        #expect(CSVExporter.escape("+49 40 555") == "'+49 40 555")
        #expect(CSVExporter.escape("-1") == "'-1")
        #expect(CSVExporter.escape("@SUM(A1)") == "'@SUM(A1)")
        #expect(CSVExporter.escape("Normal = fein") == "Normal = fein")
        #expect(CSVExporter.escape("  =1+1") == "'  =1+1")
        #expect(CSVExporter.escape("\n=1+1") == "\"'\n=1+1\"")
        #expect(CSVExporter.escape("  Normal") == "  Normal")
    }

    @Test("Kopfzeile, Werte und Zeilenenden")
    func document() throws {
        let item = try richApplication()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let csv = CSVExporter.make(applications: [item], calendar: calendar)

        #expect(csv.hasPrefix(CSVExporter.byteOrderMark + "Firma;Position;Status"))
        let lines = csv.dropFirst().components(separatedBy: "\r\n")
        #expect(lines.first?.split(separator: ";").count == CSVExporter.header.count)
        #expect(csv.contains("\"Nordlicht, \"\"Software\"\"; GmbH\""))
        #expect(csv.contains(";Interview;"))
        #expect(csv.contains(";Hybrid;Honeypot;Hoch;https://example.com/jobs/1;"))
        #expect(csv.contains(";62000;74000;Java, Hybrid;nein;"))
        #expect(csv.hasSuffix("\r\n"))
    }

    @Test("Eigene Statusnamen werden übernommen")
    func customStatusTitles() throws {
        let item = JobApplication(company: "A", position: "B", status: .applied)
        let csv = CSVExporter.make(applications: [item]) { _ in "Abgeschickt" }
        #expect(csv.contains(";Abgeschickt;"))
    }
}
