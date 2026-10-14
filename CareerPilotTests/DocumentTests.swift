import Foundation
import SwiftData
import Testing

@testable import CareerPilot

/// Ein kleinstes gültiges PDF-Gerüst reicht für die Kopfzeilenprüfung.
private func pdf(_ extra: String = "") -> Data {
    Data("%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\n\(extra)\n%%EOF".utf8)
}

@Suite("Dokumente")
struct DocumentTests {
    @Test("Ein echtes PDF wird akzeptiert")
    func acceptsPDF() throws {
        try DocumentImporter.validate(data: pdf(), fileName: "Lebenslauf.pdf")
    }

    @Test("Falsche Endung, falscher Inhalt, leer und zu groß werden abgelehnt")
    func rejects() {
        #expect(throws: DocumentImportError.notAPDF("Bild.png")) {
            try DocumentImporter.validate(data: pdf(), fileName: "Bild.png")
        }
        #expect(throws: DocumentImportError.notAPDF("Text.pdf")) {
            try DocumentImporter.validate(data: Data("Das ist kein PDF".utf8), fileName: "Text.pdf")
        }
        #expect(throws: DocumentImportError.empty("Leer.pdf")) {
            try DocumentImporter.validate(data: Data(), fileName: "Leer.pdf")
        }
        let huge = Data(count: DocumentImporter.maxBytes + 1)
        #expect(throws: DocumentImportError.tooLarge("Gross.pdf")) {
            try DocumentImporter.validate(data: huge, fileName: "Gross.pdf")
        }
    }

    @Test("Dateinamen werden bereinigt")
    func sanitizing() {
        #expect(DocumentImporter.sanitizedName("/Users/x/Dokumente/CV 2026.pdf") == "CV 2026.pdf")
        #expect(DocumentImporter.sanitizedName("   ") == "Dokument.pdf")
        #expect(DocumentImporter.sanitizedName("a\u{0007}b.pdf") == "ab.pdf")
        let long = String(repeating: "x", count: 300) + ".pdf"
        let cleaned = DocumentImporter.sanitizedName(long)
        #expect(cleaned.count <= 125)
        #expect(cleaned.hasSuffix(".pdf"))
    }

    @Test("Die Art wird aus dem Dateinamen geraten")
    func suggestedKind() {
        #expect(DocumentImporter.suggestedKind(forFileName: "Lebenslauf_Max.pdf") == .resume)
        #expect(DocumentImporter.suggestedKind(forFileName: "CV 2026.pdf") == .resume)
        #expect(DocumentImporter.suggestedKind(forFileName: "Anschreiben Nordlicht.pdf") == .coverLetter)
        #expect(DocumentImporter.suggestedKind(forFileName: "Arbeitszeugnis.pdf") == .certificate)
        #expect(DocumentImporter.suggestedKind(forFileName: "Unterlagen.pdf") == .other)
    }

    @Test("Anhängen speichert Art, Größe und Namen")
    func attach() throws {
        let item = JobApplication(company: "Firma", position: "Dev")
        let data = pdf("x")
        let document = try item.addDocument(data: data, fileName: "Anschreiben.pdf")
        #expect(item.documents.count == 1)
        #expect(document.kind == .coverLetter)
        #expect(document.byteCount == data.count)
        #expect(document.fileName == "Anschreiben.pdf")
        #expect(!document.formattedSize.isEmpty)
    }

    @Test("Ungültige Dateien werden nicht angehängt")
    func attachRejects() {
        let item = JobApplication(company: "Firma", position: "Dev")
        #expect(throws: DocumentImportError.self) {
            try item.addDocument(data: Data("kein pdf".utf8), fileName: "x.pdf")
        }
        #expect(item.documents.isEmpty)
    }

    @Test("Laden prüft die Datei auf der Platte")
    func loadFromDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cp-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let good = folder.appendingPathComponent("CV.pdf")
        try pdf().write(to: good)
        let loaded = try DocumentImporter.load(url: good)
        #expect(loaded.fileName == "CV.pdf")

        let bad = folder.appendingPathComponent("Notiz.pdf")
        try Data("nur Text".utf8).write(to: bad)
        #expect(throws: DocumentImportError.notAPDF("Notiz.pdf")) {
            try DocumentImporter.load(url: bad)
        }

        let missing = folder.appendingPathComponent("fehlt.pdf")
        #expect(throws: DocumentImportError.unreadable("fehlt.pdf")) {
            try DocumentImporter.load(url: missing)
        }
    }

    @Test("Dokumente werden gespeichert und mit der Bewerbung gelöscht")
    @MainActor
    func persistenceAndCascade() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let item = JobApplication(company: "Firma", position: "Dev")
        try item.addDocument(data: pdf("abc"), fileName: "Lebenslauf.pdf")
        context.insert(item)
        try context.save()

        let loaded = try context.fetch(FetchDescriptor<ApplicationDocument>())
        #expect(loaded.count == 1)
        #expect(loaded.first?.data == pdf("abc"))
        #expect(loaded.first?.application?.company == "Firma")

        context.delete(item)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ApplicationDocument>()) == 0)
    }
}
