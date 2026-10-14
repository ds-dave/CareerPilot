import Foundation
import SwiftData
import Testing

@testable import CareerPilot

private let berlin: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    calendar.firstWeekday = 2
    calendar.locale = Locale(identifier: "de_DE")
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    berlin.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func application(
    _ company: String = "Firma",
    status: ApplicationStatus = .applied,
    appliedOn: Date? = nil,
    followUp: Date? = nil
) -> JobApplication {
    let application = JobApplication(company: company, position: "Dev", status: status)
    application.appliedOn = appliedOn
    application.followUpOn = followUp
    return application
}

private func event(
    _ kind: EventKind = .interview, at start: Date, minutes: Int = 60, for application: JobApplication? = nil
) -> ApplicationEvent {
    let event = ApplicationEvent(kind: kind, start: start, durationMinutes: minutes)
    if let application {
        application.events.append(event)
    }
    return event
}

// MARK: - Vorschlag

@Suite("Nachfass-Vorschlag")
struct FollowUpSuggestionTests {
    @Test("Vorschlag: Bewerbungsdatum plus X Tage, solange keine Antwort kam")
    func suggestion() {
        let item = application(appliedOn: date(2026, 3, 2, 18))
        let suggested = item.suggestedFollowUp(afterDays: 7, calendar: berlin)
        #expect(suggested == berlin.startOfDay(for: date(2026, 3, 9)))
    }

    @Test("Kein Vorschlag mit Antwort, gesetztem Datum, ohne Bewerbungsdatum oder archiviert")
    func noSuggestion() {
        #expect(application(status: .acknowledged, appliedOn: date(2026, 3, 2)).suggestedFollowUp(afterDays: 7) == nil)
        #expect(application(appliedOn: date(2026, 3, 2), followUp: date(2026, 3, 20)).suggestedFollowUp(afterDays: 7) == nil)
        #expect(application(appliedOn: nil).suggestedFollowUp(afterDays: 7) == nil)
        let archived = application(appliedOn: date(2026, 3, 2))
        archived.isArchived = true
        #expect(archived.suggestedFollowUp(afterDays: 7) == nil)
    }
}

// MARK: - Planer

@Suite("ReminderPlanner")
struct ReminderPlannerTests {
    private let now = date(2026, 3, 10, 8, 0)

    private func prefs(
        enabled: Bool = true, followUps: Bool = true, digest: Bool = false, lead: Int = 60, hour: Int = 9
    ) -> ReminderPreferences {
        ReminderPreferences(
            isEnabled: enabled, hour: hour, followUpDays: 7, eventLeadMinutes: lead,
            notifyFollowUps: followUps, dailyDigest: digest
        )
    }

    @Test("Ausgeschaltet plant nichts")
    func disabled() {
        let item = application(followUp: date(2026, 3, 12))
        #expect(ReminderPlanner.plan(applications: [item], preferences: prefs(enabled: false), now: now, calendar: berlin).isEmpty)
    }

    @Test("Nachfassen: eine Benachrichtigung am Fälligkeitstag zur gewählten Uhrzeit")
    func followUpNotification() {
        let item = application("Nordlicht", followUp: date(2026, 3, 12, 0, 0))
        let plans = ReminderPlanner.plan(applications: [item], preferences: prefs(hour: 9), now: now, calendar: berlin)
        #expect(plans.count == 1)
        #expect(plans[0].title == "Nachfassen bei Nordlicht")
        #expect(plans[0].fireDate == date(2026, 3, 12, 9, 0))
    }

    @Test("Vergangene, abgeschlossene und archivierte Nachfass-Termine werden nicht geplant")
    func skipsNonRelevantFollowUps() {
        let past = application(followUp: date(2026, 3, 1))
        let finished = application(status: .rejected, followUp: date(2026, 3, 12))
        let archived = application(followUp: date(2026, 3, 12))
        archived.isArchived = true
        let plans = ReminderPlanner.plan(
            applications: [past, finished, archived], preferences: prefs(), now: now, calendar: berlin
        )
        #expect(plans.isEmpty)
    }

    @Test("Termine: Erinnerung mit Vorlauf, nur in der Zukunft")
    func eventReminder() {
        let item = application("Beispiel AG")
        _ = event(.interview, at: date(2026, 3, 11, 14, 0), for: item)
        _ = event(.phone, at: date(2026, 3, 9, 14, 0), for: item)
        let plans = ReminderPlanner.plan(applications: [item], preferences: prefs(followUps: false, lead: 60), now: now, calendar: berlin)
        #expect(plans.count == 1)
        #expect(plans[0].fireDate == date(2026, 3, 11, 13, 0))
        #expect(plans[0].title == "Interview bei Beispiel AG")
    }

    @Test("Eigener Vorlauf pro Termin und 'keine Erinnerung'")
    func perEventLead() {
        let item = application()
        let early = event(at: date(2026, 3, 11, 14, 0), for: item)
        early.reminderLeadMinutes = 1_440
        let none = event(at: date(2026, 3, 12, 14, 0), for: item)
        none.reminderLeadMinutes = -1
        let plans = ReminderPlanner.plan(applications: [item], preferences: prefs(followUps: false), now: now, calendar: berlin)
        #expect(plans.map(\.fireDate) == [date(2026, 3, 10, 14, 0)])
    }

    @Test("Zusammenfassung: überfällig, heute und Termine in einer Nachricht")
    func digest() {
        let overdue = application("Alt AG", followUp: date(2026, 3, 8))
        let today = application("Heute GmbH", followUp: date(2026, 3, 10))
        let withEvent = application("Termin KG")
        _ = event(at: date(2026, 3, 10, 15, 0), for: withEvent)
        let plans = ReminderPlanner.plan(
            applications: [overdue, today, withEvent],
            preferences: prefs(followUps: false, digest: true, lead: -1),
            now: now, calendar: berlin
        )
        let digest = plans.first { $0.id.contains("digest") }
        #expect(digest != nil)
        #expect(digest?.fireDate == date(2026, 3, 10, 9, 0))
        #expect(digest?.body.contains("1 überfälliger Nachfass-Termin") == true)
        #expect(digest?.body.contains("1 Nachfass-Termin") == true)
        #expect(digest?.body.contains("1 Termin") == true)
    }

    @Test("Zusammenfassung ohne Inhalt entfällt, Plan bleibt unter dem Systemlimit")
    func limits() {
        #expect(ReminderPlanner.plan(applications: [], preferences: prefs(digest: true), now: now, calendar: berlin).isEmpty)

        let many = (0..<100).map { index in
            application("F\(index)", followUp: berlin.date(byAdding: .day, value: 1 + index % 10, to: date(2026, 3, 10)))
        }
        let plans = ReminderPlanner.plan(applications: many, preferences: prefs(), now: now, calendar: berlin)
        #expect(plans.count == ReminderPlanner.limit)
        #expect(plans == plans.sorted { $0.fireDate < $1.fireDate })
    }
}

// MARK: - Agenda

@Suite("AgendaBuilder")
struct AgendaBuilderTests {
    private let now = date(2026, 3, 10, 10, 0)

    @Test("Sortiert in überfällig, heute, demnächst und wartend")
    func sections() {
        let overdue = application("Überfällig", followUp: date(2026, 3, 7))
        let today = application("Heute", followUp: date(2026, 3, 10))
        let soon = application("Bald", followUp: date(2026, 3, 13))
        let far = application("Weit", followUp: date(2026, 3, 30))
        let waiting = application("Wartet", appliedOn: date(2026, 2, 20))
        let fresh = application("Frisch", appliedOn: date(2026, 3, 8))
        let withEvents = application("Mit Terminen")
        let eventToday = event(at: date(2026, 3, 10, 15, 0), for: withEvents)
        let eventSoon = event(at: date(2026, 3, 12, 9, 0), for: withEvents)
        let eventFar = event(at: date(2026, 3, 25, 9, 0), for: withEvents)

        let agenda = AgendaBuilder.build(
            applications: [overdue, today, soon, far, waiting, fresh, withEvents],
            now: now, waitingAfterDays: 7, calendar: berlin
        )

        #expect(agenda.overdue.map(\.company) == ["Überfällig"])
        #expect(agenda.followUpsToday.map(\.company) == ["Heute"])
        #expect(agenda.upcomingFollowUps.map(\.company) == ["Bald"])
        #expect(agenda.eventsToday.map(\.uuid) == [eventToday.uuid])
        #expect(agenda.upcomingEvents.map(\.uuid) == [eventSoon.uuid])
        #expect(!agenda.upcomingEvents.contains { $0.uuid == eventFar.uuid })
        #expect(agenda.waiting.map(\.company) == ["Wartet"])
        #expect(agenda.attentionCount == 3)
    }

    @Test("Wer schon im Nachfassen auftaucht, steht nicht zusätzlich unter 'Wartet'")
    func noDuplicates() {
        let item = application("Doppelt", appliedOn: date(2026, 2, 1), followUp: date(2026, 3, 5))
        let agenda = AgendaBuilder.build(applications: [item], now: now, waitingAfterDays: 7, calendar: berlin)
        #expect(agenda.overdue.count == 1)
        #expect(agenda.waiting.isEmpty)
    }

    @Test("Archivierte Bewerbungen und leere Agenda")
    func archivedAndEmpty() {
        let item = application("Archiv", followUp: date(2026, 3, 5))
        item.isArchived = true
        let agenda = AgendaBuilder.build(applications: [item], now: now, calendar: berlin)
        #expect(agenda.isEmpty)
        #expect(agenda.attentionCount == 0)
    }
}

// MARK: - Monatsraster

@Suite("MonthGrid")
struct MonthGridTests {
    @Test("Sechs Wochen, beginnend am Montag")
    func shape() {
        let weeks = MonthGrid.weeks(containing: date(2026, 3, 15), calendar: berlin)
        #expect(weeks.count == 6)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(berlin.component(.weekday, from: weeks[0][0]) == 2)
        // 1. März 2026 ist ein Sonntag, die erste Woche beginnt also am 23. Februar.
        #expect(berlin.isDate(weeks[0][0], inSameDayAs: date(2026, 2, 23)))
        #expect(berlin.isDate(weeks[0][6], inSameDayAs: date(2026, 3, 1)))
    }

    @Test("Der erste Tag des Monats ist enthalten, auch wenn er auf den Wochenanfang fällt")
    func monthStartsOnMonday() {
        let weeks = MonthGrid.weeks(containing: date(2026, 6, 10), calendar: berlin)
        #expect(berlin.isDate(weeks[0][0], inSameDayAs: date(2026, 6, 1)))
    }

    @Test("Wochentagskürzel beginnen mit dem ersten Wochentag")
    func symbols() {
        let symbols = MonthGrid.weekdaySymbols(calendar: berlin)
        #expect(symbols.count == 7)
        #expect(symbols.first == berlin.shortStandaloneWeekdaySymbols[1])
    }
}

// MARK: - ICS

@Suite("ICSExporter")
struct ICSExporterTests {
    private let now = date(2026, 3, 10, 8, 0)

    @Test("Aufbau, Zeilenenden und Pflichtfelder")
    func structure() {
        let item = application("Nordlicht, Software; GmbH")
        let meeting = event(.interview, at: date(2026, 3, 12, 14, 0), minutes: 90, for: item)
        meeting.location = "Hamburg, Hafenstraße 12"
        meeting.meetingURLString = "https://meet.example.com/abc"

        let text = ICSExporter.calendar(events: [meeting], defaultLeadMinutes: 30, now: now, calendar: berlin)
        let lines = text.components(separatedBy: "\r\n")

        #expect(lines.first == "BEGIN:VCALENDAR")
        #expect(lines.contains("VERSION:2.0"))
        #expect(lines.contains("DTSTART:20260312T130000Z"))
        #expect(lines.contains("DTEND:20260312T143000Z"))
        #expect(lines.contains("DTSTAMP:20260310T070000Z"))
        #expect(lines.contains("SUMMARY:Interview: Nordlicht\\, Software\\; GmbH"))
        #expect(lines.contains("LOCATION:Hamburg\\, Hafenstraße 12"))
        #expect(lines.contains("URL:https://meet.example.com/abc"))
        #expect(lines.contains("TRIGGER:-PT30M"))
        #expect(text.hasSuffix("END:VCALENDAR\r\n"))
        #expect(!text.contains("\n\n"))
    }

    @Test("Keine Erinnerung erzeugt keinen Alarm")
    func noAlarm() {
        let meeting = event(at: date(2026, 3, 12, 14, 0))
        meeting.reminderLeadMinutes = -1
        let text = ICSExporter.calendar(events: [meeting], now: now, calendar: berlin)
        #expect(!text.contains("VALARM"))
    }

    @Test("Nachfass-Termine sind ganztägig")
    func followUps() {
        let item = application("Beispiel AG", followUp: date(2026, 3, 20))
        let text = ICSExporter.calendar(events: [], followUps: [item], now: now, calendar: berlin)
        #expect(text.contains("DTSTART;VALUE=DATE:20260320\r\n"))
        #expect(text.contains("DTEND;VALUE=DATE:20260321\r\n"))
        #expect(text.contains("SUMMARY:Nachfassen: Beispiel AG\r\n"))
    }

    @Test("Maskierung und Zeilenumbruch")
    func escapingAndFolding() {
        #expect(ICSExporter.escape("a;b,c\\d\ne") == "a\\;b\\,c\\\\d\\ne")

        let long = "DESCRIPTION:" + String(repeating: "ä", count: 80)
        let folded = ICSExporter.fold(long)
        #expect(folded.count > 1)
        #expect(folded.allSatisfy { $0.utf8.count <= 75 })
        #expect(folded.dropFirst().allSatisfy { $0.hasPrefix(" ") })
        let rejoined = folded.first! + folded.dropFirst().map { String($0.dropFirst()) }.joined()
        #expect(rejoined == long)
    }
}

// MARK: - Modelle

@Suite("Termine und Kontakte")
struct EventModelTests {
    @Test("Titel, Ende und Checklistenfortschritt")
    func derived() {
        let item = event(.technical, at: date(2026, 3, 12, 10, 0), minutes: 45)
        #expect(item.displayTitle == "Fachgespräch")
        item.title = "  Code-Review  "
        #expect(item.displayTitle == "  Code-Review  ".trimmingCharacters(in: .whitespaces) || item.displayTitle == "  Code-Review  ")
        #expect(item.end == date(2026, 3, 12, 10, 45))
        #expect(item.checklistProgress == nil)
        item.checklist = [ChecklistItem(text: "A", isDone: true), ChecklistItem(text: "B")]
        #expect(item.checklistProgress?.done == 1)
        #expect(item.checklistProgress?.total == 2)
    }

    @Test("Kontakt-Links nur bei brauchbaren Angaben")
    func contactLinks() {
        let contact = ContactPerson(name: "Mara", role: "Recruiterin")
        #expect(contact.mailURL == nil)
        #expect(contact.phoneURL == nil)
        contact.email = "mara@example.com"
        contact.phone = "+49 40 555 0123"
        #expect(contact.mailURL?.absoluteString == "mailto:mara@example.com")
        #expect(contact.phoneURL?.absoluteString == "tel:+49405550123")
        contact.email = "kein mail"
        #expect(contact.mailURL == nil)
    }

    @Test("Termine und Kontakte werden gespeichert; Löschen der Bewerbung räumt auf")
    @MainActor
    func persistenceAndCascade() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let item = application("Firma")
        let contact = ContactPerson(name: "Mara", role: "Lead")
        item.contacts.append(contact)
        let meeting = event(.interview, at: date(2026, 3, 12, 14), for: item)
        meeting.checklist = [ChecklistItem(text: "Fragen", isDone: true)]
        meeting.questions = ["Wie groß ist das Team?"]
        meeting.contact = contact
        context.insert(item)
        try context.save()

        let loaded = try context.fetch(FetchDescriptor<ApplicationEvent>())
        #expect(loaded.count == 1)
        #expect(loaded.first?.checklist.first?.text == "Fragen")
        #expect(loaded.first?.questions == ["Wie groß ist das Team?"])
        #expect(loaded.first?.contact?.name == "Mara")
        #expect(loaded.first?.application?.company == "Firma")

        context.delete(item)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ApplicationEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ContactPerson>()) == 0)
    }

    @Test("Wird ein Kontakt gelöscht, bleibt der Termin ohne Ansprechpartner")
    @MainActor
    func deletingContactKeepsEvent() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let item = application("Firma")
        let contact = ContactPerson(name: "Mara")
        item.contacts.append(contact)
        let meeting = event(at: date(2026, 3, 12, 14), for: item)
        meeting.contact = contact
        context.insert(item)
        try context.save()

        context.delete(contact)
        try context.save()

        let events = try context.fetch(FetchDescriptor<ApplicationEvent>())
        #expect(events.count == 1)
        #expect(events.first?.contact == nil)
    }
}

@MainActor
@Suite("ReminderSettings")
struct ReminderSettingsTests {
    @Test("Einstellungen werden gespeichert und wieder geladen")
    func persistence() {
        let suite = "careerpilot.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = ReminderSettings(defaults: defaults)
        #expect(settings.preferences == ReminderPreferences())
        settings.preferences.isEnabled = true
        settings.preferences.hour = 8
        settings.preferences.followUpDays = 10
        settings.preferences.dailyDigest = true

        let reloaded = ReminderSettings(defaults: defaults)
        #expect(reloaded.preferences.isEnabled)
        #expect(reloaded.preferences.hour == 8)
        #expect(reloaded.preferences.followUpDays == 10)
        #expect(reloaded.preferences.dailyDigest)
    }
}
