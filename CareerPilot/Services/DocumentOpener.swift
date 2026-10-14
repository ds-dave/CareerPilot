import AppKit
import Foundation

/// Öffnet Dokumente mit der Standard-App (Vorschau) und sichert Kopien.
@MainActor
enum DocumentOpener {
    /// Schreibt eine Kopie in den temporären Ordner und öffnet sie. Das Original bleibt in der Datenbank.
    static func open(_ document: ApplicationDocument) {
        do {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("CareerPilot", isDirectory: true)
                .appendingPathComponent(document.uuid.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(DocumentImporter.sanitizedName(document.fileName))
            try document.data.write(to: url, options: .atomic)
            NSWorkspace.shared.open(url)
        } catch {
            NSSound.beep()
        }
    }

    /// Fragt nach einem Ort und speichert eine Kopie dorthin.
    static func saveCopy(of document: ApplicationDocument) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = DocumentImporter.sanitizedName(document.fileName)
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? document.data.write(to: url, options: .atomic)
    }
}
