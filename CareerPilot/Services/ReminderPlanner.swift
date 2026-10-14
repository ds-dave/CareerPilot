import Foundation

/// Eine geplante lokale Benachrichtigung. Rein beschreibend, damit sich die Planung ohne System testen lässt.
struct PlannedNotification: Hashable, Sendable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

/// Berechnet aus den Bewerbungen, welche Benachrichtigungen anstehen.
enum ReminderPlanner {
    static let idPrefix = "careerpilot."
    /// Wie weit in die Zukunft geplant wird. macOS erlaubt höchstens 64 ausstehende Benachrichtigungen.
    static let horizonDays = 14
    static let limit = 60

    static func plan(
        applications: [JobApplication],
        preferences: ReminderPreferences,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        guard preferences.isEnabled else { return [] }

        let active = applications.filter { !$0.isArchived }
        let today = calendar.startOfDay(for: now)
        guard let horizonEnd = calendar.date(byAdding: .day, value: Self.horizonDays, to: today) else { return [] }

        var plans: [PlannedNotification] = []

        // Termine: kurz vorher.
        for application in active {
            for event in application.events {
                let lead = event.reminderLeadMinutes ?? preferences.eventLeadMinutes
                guard lead >= 0 else { continue }
                let fire = event.start.addingTimeInterval(-TimeInterval(lead * 60))
                guard fire > now, event.start > now, fire < horizonEnd else { continue }
                plans.append(
                    PlannedNotification(
                        id: "\(idPrefix)event.\(event.uuid.uuidString)",
                        title: "\(event.displayTitle) bei \(application.displayCompany)",
                        body: eventBody(event, lead: lead, calendar: calendar),
                        fireDate: fire
                    )
                )
            }
        }

        // Nachfassen: am Fälligkeitstag zur gewählten Uhrzeit.
        if preferences.notifyFollowUps {
            for application in active where !application.status.isFinished {
                guard let due = application.followUpOn else { continue }
                let day = calendar.startOfDay(for: due)
                guard day >= today, day < horizonEnd,
                      let fire = calendar.date(bySettingHour: preferences.hour, minute: 0, second: 0, of: day),
                      fire > now
                else { continue }
                plans.append(
                    PlannedNotification(
                        id: "\(idPrefix)followup.\(application.uuid.uuidString).\(dayKey(day, calendar))",
                        title: "Nachfassen bei \(application.displayCompany)",
                        body: "\(application.position) – heute ist dein Nachfass-Termin.",
                        fireDate: fire
                    )
                )
            }
        }

        // Tägliche Zusammenfassung.
        if preferences.dailyDigest {
            for offset in 0..<Self.horizonDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let fire = calendar.date(bySettingHour: preferences.hour, minute: 0, second: 0, of: day),
                      fire > now,
                      let digest = digest(for: day, isToday: offset == 0, applications: active, fire: fire,
                                          now: now, calendar: calendar)
                else { continue }
                plans.append(digest)
            }
        }

        return Array(plans.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }

    // MARK: Bausteine

    private static func digest(
        for day: Date, isToday: Bool, applications: [JobApplication], fire: Date, now: Date, calendar: Calendar
    ) -> PlannedNotification? {
        let open = applications.filter { !$0.status.isFinished }
        let dueToday = open.filter { application in
            application.followUpOn.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        }
        let overdue = isToday
            ? open.filter { application in
                application.followUpOn.map { calendar.startOfDay(for: $0) < day } ?? false
            }
            : []
        let events = applications.flatMap(\.events).filter { calendar.isDate($0.start, inSameDayAs: day) }

        var parts: [String] = []
        if !overdue.isEmpty {
            parts.append("\(plural(overdue.count, "überfälliger Nachfass-Termin", "überfällige Nachfass-Termine"))")
        }
        if !dueToday.isEmpty {
            parts.append(plural(dueToday.count, "Nachfass-Termin", "Nachfass-Termine"))
        }
        if !events.isEmpty {
            parts.append(plural(events.count, "Termin", "Termine"))
        }
        guard !parts.isEmpty else { return nil }

        let names = (overdue + dueToday).map(\.displayCompany) + events.compactMap { $0.application?.displayCompany }
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        let more = unique.count > 3 ? " und weitere" : ""
        let body = parts.joined(separator: ", ") + ": " + unique.prefix(3).joined(separator: ", ") + more

        return PlannedNotification(
            id: "\(idPrefix)digest.\(dayKey(day, calendar))",
            title: "CareerPilot – dein Tag",
            body: body,
            fireDate: fire
        )
    }

    private static func eventBody(_ event: ApplicationEvent, lead: Int, calendar: Calendar) -> String {
        let time = event.start.formatted(date: .omitted, time: .shortened)
        var parts = [lead == 0 ? "Jetzt, \(time) Uhr" : "Um \(time) Uhr"]
        let place = event.location.trimmingCharacters(in: .whitespaces)
        if !place.isEmpty { parts.append(place) }
        if let contact = event.contact { parts.append("mit \(contact.displayName)") }
        return parts.joined(separator: " · ")
    }

    private static func dayKey(_ day: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func plural(_ count: Int, _ singular: String, _ plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}
