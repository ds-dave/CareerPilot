import Foundation

/// Erzeugt eine iCalendar-Datei (RFC 5545), die Kalender, Outlook und Co. öffnen können.
enum ICSExporter {
    static let productID = "-//CareerPilot//Bewerbungen//DE"

    static func calendar(
        events: [ApplicationEvent],
        followUps: [JobApplication] = [],
        defaultLeadMinutes: Int = 60,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:\(productID)",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:CareerPilot",
        ]

        for event in events.sorted(by: { $0.start < $1.start }) {
            lines += eventLines(event, defaultLeadMinutes: defaultLeadMinutes, now: now)
        }
        for application in followUps {
            guard let due = application.followUpOn else { continue }
            lines += followUpLines(application, due: due, now: now, calendar: calendar)
        }
        lines.append("END:VCALENDAR")

        return lines.flatMap(fold).joined(separator: "\r\n") + "\r\n"
    }

    // MARK: Bausteine

    private static func eventLines(_ event: ApplicationEvent, defaultLeadMinutes: Int, now: Date) -> [String] {
        let company = event.application?.displayCompany ?? ""
        var lines = [
            "BEGIN:VEVENT",
            "UID:\(event.uuid.uuidString)@careerpilot.app",
            "DTSTAMP:\(utc(now))",
            "DTSTART:\(utc(event.start))",
            "DTEND:\(utc(event.end))",
            "SUMMARY:\(escape(company.isEmpty ? event.displayTitle : "\(event.displayTitle): \(company)"))",
        ]
        let place = event.location.trimmingCharacters(in: .whitespaces)
        if !place.isEmpty {
            lines.append("LOCATION:\(escape(place))")
        }
        if let url = event.meetingURL {
            lines.append("URL:\(url.absoluteString)")
        }

        var description: [String] = []
        if let position = event.application?.position, !position.isEmpty {
            description.append("Position: \(position)")
        }
        if let contact = event.contact {
            description.append("Ansprechpartner: \(contact.displayName)")
        }
        if !event.questions.isEmpty {
            description.append("Fragen:")
            description += event.questions.map { "- \($0)" }
        }
        if !event.checklist.isEmpty {
            description.append("Vorbereitung:")
            description += event.checklist.map { "\($0.isDone ? "[x]" : "[ ]") \($0.text)" }
        }
        if !description.isEmpty {
            lines.append("DESCRIPTION:\(escape(description.joined(separator: "\n")))")
        }

        let lead = event.reminderLeadMinutes ?? defaultLeadMinutes
        if lead >= 0 {
            lines += [
                "BEGIN:VALARM",
                "ACTION:DISPLAY",
                "DESCRIPTION:\(escape(event.displayTitle))",
                "TRIGGER:-PT\(lead)M",
                "END:VALARM",
            ]
        }
        lines.append("END:VEVENT")
        return lines
    }

    private static func followUpLines(
        _ application: JobApplication, due: Date, now: Date, calendar: Calendar
    ) -> [String] {
        let day = calendar.startOfDay(for: due)
        let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return [
            "BEGIN:VEVENT",
            "UID:followup-\(application.uuid.uuidString)@careerpilot.app",
            "DTSTAMP:\(utc(now))",
            "DTSTART;VALUE=DATE:\(dateOnly(day, calendar))",
            "DTEND;VALUE=DATE:\(dateOnly(next, calendar))",
            "SUMMARY:\(escape("Nachfassen: \(application.displayCompany)"))",
            "DESCRIPTION:\(escape(application.position))",
            "TRANSP:TRANSPARENT",
            "END:VEVENT",
        ]
    }

    // MARK: Formatierung

    /// Maskiert Sonderzeichen in Textwerten (RFC 5545, 3.3.11).
    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
    }

    /// Bricht Zeilen nach höchstens 75 Bytes um; Folgezeilen beginnen mit einem Leerzeichen.
    static func fold(_ line: String) -> [String] {
        guard line.utf8.count > 75 else { return [line] }
        var result: [String] = []
        var current = ""
        var currentBytes = 0
        var limit = 75
        for character in line {
            let size = String(character).utf8.count
            if currentBytes + size > limit {
                result.append(result.isEmpty ? current : " " + current)
                current = ""
                currentBytes = 0
                limit = 74
            }
            current.append(character)
            currentBytes += size
        }
        if !current.isEmpty {
            result.append(result.isEmpty ? current : " " + current)
        }
        return result
    }

    private static func utc(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func dateOnly(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
