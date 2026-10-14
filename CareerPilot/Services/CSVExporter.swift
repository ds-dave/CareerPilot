import Foundation

/// CSV für Excel, Numbers und Google Tabellen: Semikolon als Trenner (deutsche Excel-Voreinstellung),
/// UTF-8 mit Kennzeichen, damit Umlaute stimmen.
enum CSVExporter {
    static let delimiter = ";"
    static let byteOrderMark = "\u{FEFF}"

    static let header = [
        "Firma", "Position", "Status", "Ort", "Arbeitsmodell", "Onlineportal", "Priorität", "Link",
        "Beworben am", "Nachfassen am", "Gehalt von", "Gehalt bis", "Tags", "Archiviert", "Angelegt am", "Notizen",
    ]

    static func make(
        applications: [JobApplication],
        statusTitle: (ApplicationStatus) -> String = { $0.title },
        calendar: Calendar = .current
    ) -> String {
        func day(_ date: Date?) -> String {
            guard let date else { return "" }
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }

        var rows: [[String]] = [header]
        for application in applications.sorted(by: { $0.createdAt < $1.createdAt }) {
            rows.append([
                application.company,
                application.position,
                statusTitle(application.status),
                application.location,
                application.workModel?.title ?? "",
                application.portalTitle ?? "",
                application.priority.title,
                application.jobURLString,
                day(application.appliedOn),
                day(application.followUpOn),
                application.salaryMin.map(String.init) ?? "",
                application.salaryMax.map(String.init) ?? "",
                application.tags.joined(separator: ", "),
                application.isArchived ? "ja" : "nein",
                day(application.createdAt),
                application.notes,
            ])
        }
        return byteOrderMark + rows.map { $0.map(escape).joined(separator: delimiter) }.joined(separator: "\r\n") + "\r\n"
    }

    /// Setzt ein Feld für CSV: Anführungszeichen verdoppeln und bei Bedarf einklammern.
    /// Felder, die mit `=`, `+`, `-` oder `@` beginnen, bekommen ein Hochkomma. Sonst würde Excel
    /// sie als Formel ausführen, etwa aus einer kopierten Anzeige.
    static func escape(_ value: String) -> String {
        var text = value
        let significant = text.drop(while: { $0.isWhitespace })
        if text.first.map({ "\t\r\n".contains($0) }) == true
            || significant.first.map({ "=+-@".contains($0) }) == true {
            text = "'" + text
        }
        let needsQuotes = text.contains(delimiter) || text.contains("\"") || text.contains("\n") || text.contains("\r")
        guard needsQuotes else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
