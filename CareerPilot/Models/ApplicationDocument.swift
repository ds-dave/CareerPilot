import Foundation
import SwiftData

enum DocumentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case resume
    case coverLetter
    case certificate
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resume: "Lebenslauf"
        case .coverLetter: "Anschreiben"
        case .certificate: "Zeugnis"
        case .other: "Sonstiges"
        }
    }

    var systemImage: String {
        switch self {
        case .resume: "person.text.rectangle"
        case .coverLetter: "envelope"
        case .certificate: "rosette"
        case .other: "doc"
        }
    }
}

/// Eine angehängte PDF-Datei. Der Inhalt liegt als externes Attribut in der Datenbank:
/// SwiftData legt große Daten daneben ab, sie bleiben aber Teil von Rückgängig und Backup.
@Model
final class ApplicationDocument {
    var uuid: UUID = UUID()
    var fileName: String = ""
    var kind: DocumentKind = DocumentKind.other
    var addedAt: Date = Date()
    var byteCount: Int = 0

    @Attribute(.externalStorage)
    var data: Data = Data()

    var application: JobApplication?

    init(fileName: String, kind: DocumentKind, data: Data, addedAt: Date = .now) {
        self.fileName = fileName
        self.kind = kind
        self.data = data
        self.byteCount = data.count
        self.addedAt = addedAt
    }
}

extension ApplicationDocument {
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}
