import AppKit
import UniformTypeIdentifiers

/// Dateidialoge für Export und Import. Die App ist sandboxed: erst durch die Auswahl des Nutzers
/// bekommt sie Zugriff auf die Datei.
@MainActor
enum FilePanels {
    /// Fragt nach einem Speicherort und schreibt die Daten. Gibt `false` bei Abbruch oder Fehler zurück.
    @discardableResult
    static func save(_ data: Data, suggestedName: String, type: UTType) -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    static func open(types: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func stamp(_ date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
