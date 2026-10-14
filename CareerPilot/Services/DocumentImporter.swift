import Foundation

enum DocumentImportError: LocalizedError, Equatable {
    case notAPDF(String)
    case tooLarge(String)
    case empty(String)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .notAPDF(let name): "„\(name)“ ist keine PDF-Datei."
        case .tooLarge(let name): "„\(name)“ ist größer als \(DocumentImporter.maxBytes / 1_048_576) MB."
        case .empty(let name): "„\(name)“ ist leer."
        case .unreadable(let name): "„\(name)“ konnte nicht gelesen werden."
        }
    }
}

/// Prüft und liest Dokumente, bevor sie an eine Bewerbung gehängt werden.
enum DocumentImporter {
    static let maxBytes = 20 * 1_048_576

    /// Prüft Größe, Endung und die PDF-Kopfzeile. Die Endung allein genügt nicht.
    static func validate(data: Data, fileName: String) throws {
        let name = sanitizedName(fileName)
        guard !data.isEmpty else { throw DocumentImportError.empty(name) }
        guard data.count <= maxBytes else { throw DocumentImportError.tooLarge(name) }
        guard name.lowercased().hasSuffix(".pdf") else { throw DocumentImportError.notAPDF(name) }
        let header = data.prefix(1_024)
        guard header.range(of: Data("%PDF-".utf8)) != nil else { throw DocumentImportError.notAPDF(name) }
    }

    /// Nur der Dateiname, ohne Pfad und Steuerzeichen, höchstens 120 Zeichen.
    static func sanitizedName(_ raw: String) -> String {
        let last = raw.split(separator: "/").last.map(String.init) ?? raw
        let cleaned = last.unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return "Dokument.pdf" }
        guard cleaned.count > 120 else { return cleaned }
        let ext = (cleaned as NSString).pathExtension
        let base = String(((cleaned as NSString).deletingPathExtension).prefix(110))
        return ext.isEmpty ? base : "\(base).\(ext)"
    }

    /// Rät die Art anhand des Dateinamens, damit sie nicht jedes Mal von Hand gewählt werden muss.
    static func suggestedKind(forFileName name: String) -> DocumentKind {
        let lower = name.lowercased()
        let table: [(DocumentKind, [String])] = [
            (.resume, ["lebenslauf", "cv", "resume", "résumé", "vita"]),
            (.coverLetter, ["anschreiben", "cover", "bewerbungsschreiben", "motivationsschreiben"]),
            (.certificate, ["zeugnis", "zertifikat", "certificate", "bescheinigung", "urkunde"]),
        ]
        for (kind, words) in table where words.contains(where: lower.contains) {
            return kind
        }
        return .other
    }

    /// Liest eine vom Nutzer gewählte Datei. Prüft die Größe, bevor die Daten geladen werden.
    static func load(url: URL) throws -> (fileName: String, data: Data) {
        let name = sanitizedName(url.lastPathComponent)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxBytes {
            throw DocumentImportError.tooLarge(name)
        }
        guard let data = try? Data(contentsOf: url) else { throw DocumentImportError.unreadable(name) }
        try validate(data: data, fileName: name)
        return (name, data)
    }
}
