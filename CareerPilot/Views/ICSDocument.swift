import SwiftUI
import UniformTypeIdentifiers

/// Dokument für den Export-Dialog: reiner Text einer `.ics`-Datei.
struct ICSDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.calendarEvent] }
    static var writableContentTypes: [UTType] { [.calendarEvent] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8)
        else { throw CocoaError(.fileReadCorruptFile) }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
