import Foundation
import SwiftData
import Testing

@testable import CareerPilot

@Suite("JobApplication")
struct JobApplicationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func application(
        status: ApplicationStatus = .applied,
        followUp: Date? = nil,
        archived: Bool = false
    ) -> JobApplication {
        let application = JobApplication(company: "Nordlicht Software", position: "Backend-Entwickler", status: status)
        application.followUpOn = followUp
        application.isArchived = archived
        return application
    }

    // MARK: Tage seit Bewerbung

    @Test("Tage seit Bewerbung zählen Kalendertage, nicht 24-Stunden-Blöcke")
    func daysSinceAppliedUsesCalendarDays() {
        let item = application()
        item.appliedOn = date(2026, 3, 1, hour: 23)
        let now = date(2026, 3, 2, hour: 1)
        #expect(item.daysSinceApplied(now: now, calendar: calendar) == 1)
    }

    @Test("Ohne Bewerbungsdatum gibt es keine Tage")
    func daysSinceAppliedIsNilWithoutDate() {
        #expect(application().daysSinceApplied(now: date(2026, 3, 2), calendar: calendar) == nil)
    }

    // MARK: Nachfassen

    @Test("Nachfassen: überfällig, heute, bald")
    func followUpStates() {
        let now = date(2026, 3, 10)
        #expect(application(followUp: date(2026, 3, 8)).followUpState(now: now, calendar: calendar) == .overdue(days: 2))
        #expect(application(followUp: date(2026, 3, 10, hour: 18)).followUpState(now: now, calendar: calendar) == .dueToday)
        #expect(application(followUp: date(2026, 3, 13)).followUpState(now: now, calendar: calendar) == .upcoming(days: 3))
        #expect(application().followUpState(now: now, calendar: calendar) == .none)
    }

    @Test("Abgeschlossene und archivierte Bewerbungen erinnern nicht")
    func finishedApplicationsDoNotRemind() {
        let now = date(2026, 3, 10)
        let overdue = date(2026, 3, 1)
        #expect(application(status: .rejected, followUp: overdue).followUpState(now: now, calendar: calendar) == .none)
        #expect(application(status: .accepted, followUp: overdue).followUpState(now: now, calendar: calendar) == .none)
        #expect(application(followUp: overdue, archived: true).followUpState(now: now, calendar: calendar) == .none)
    }

    // MARK: Statuswechsel

    @Test("Beim Abschicken wird das Bewerbungsdatum gesetzt")
    func submittingSetsAppliedDate() {
        let item = application(status: .wishlist)
        let now = date(2026, 3, 10, hour: 15)
        item.change(status: .applied, now: now, calendar: calendar)
        #expect(item.status == .applied)
        #expect(item.appliedOn == calendar.startOfDay(for: now))
    }

    @Test("Ein vorhandenes Bewerbungsdatum bleibt erhalten")
    func existingAppliedDateIsKept() {
        let item = application(status: .wishlist)
        let original = date(2026, 2, 1)
        item.appliedOn = original
        item.change(status: .interview, now: date(2026, 3, 10), calendar: calendar)
        #expect(item.appliedOn == original)
    }

    @Test("Zurück auf die Wunschliste setzt kein Datum")
    func wishlistDoesNotSetDate() {
        let item = application(status: .applied)
        item.change(status: .wishlist, now: date(2026, 3, 10), calendar: calendar)
        #expect(item.appliedOn == nil)
    }

    // MARK: Suche

    @Test("Die Suche verlangt alle Begriffe und ignoriert Groß- und Kleinschreibung")
    func searchMatchesAllTerms() {
        let item = application()
        item.location = "Hamburg"
        item.notes = "Nette Leute beim Telefonat"
        #expect(item.matches(search: ""))
        #expect(item.matches(search: "nordlicht"))
        #expect(item.matches(search: "backend hamburg"))
        #expect(item.matches(search: "TELEFONAT"))
        #expect(!item.matches(search: "backend berlin"))
    }

    // MARK: Link

    @Test("Nur http- und https-Links gelten als Anzeige-Link")
    func jobURLValidation() {
        let item = application()
        item.jobURLString = " https://example.com/jobs/42 "
        #expect(item.jobURL?.absoluteString == "https://example.com/jobs/42")
        item.jobURLString = "http://example.com"
        #expect(item.jobURL?.scheme == "http")
        item.jobURLString = "javascript:alert(document.cookie)"
        #expect(item.jobURL == nil)
        item.jobURLString = "mailto:jobs@example.com"
        #expect(item.jobURL == nil)
        item.jobURLString = "ftp://example.com/file"
        #expect(item.jobURL == nil)
        item.jobURLString = "keine adresse"
        #expect(item.jobURL == nil)
        item.jobURLString = "bewerbung"
        #expect(item.jobURL == nil)
        item.jobURLString = ""
        #expect(item.jobURL == nil)
    }

    @Test("Eine Adresse ohne Schema wird als https-Link gelesen")
    func jobURLWithoutScheme() {
        let item = application()
        item.jobURLString = "www.stepstone.de/jobs/42"
        #expect(item.jobURL?.absoluteString == "https://www.stepstone.de/jobs/42")
        item.jobURLString = "example.com:8080/path"
        #expect(item.jobURL?.host() == "example.com")
    }

    @Test("Bekannte Portale werden am Link erkannt, eine gesetzte Quelle bleibt")
    func sourceDetection() {
        let item = application()
        item.jobURLString = "https://www.linkedin.com/jobs/view/123"
        item.detectSourceFromLink()
        #expect(item.source == .linkedIn)

        item.jobURLString = "https://de.indeed.com/viewjob?jk=abc"
        item.detectSourceFromLink()
        #expect(item.source == .linkedIn)

        let other = application()
        other.jobURLString = "https://karriere.beispiel.de/stelle"
        other.detectSourceFromLink()
        #expect(other.source == nil)
    }

    @Test("Der Portalname zeigt bei Sonstiges den eigenen Namen")
    func portalTitle() {
        let item = application()
        #expect(item.portalTitle == nil)
        item.source = .stepStone
        #expect(item.portalTitle == "StepStone")
        item.source = .other
        #expect(item.portalTitle == "Sonstiges")
        item.sourceName = "  Honeypot "
        #expect(item.portalTitle == "Honeypot")
    }

    // MARK: Duplizieren

    @Test("Eine Kopie übernimmt die Stelle, aber nicht Status und Termine")
    func duplicateKeepsPostingButResetsProgress() {
        let item = application(status: .interview, followUp: date(2026, 3, 12))
        item.location = "Hamburg"
        item.priority = .high
        item.appliedOn = date(2026, 3, 1)
        let copy = item.duplicated()
        #expect(copy.company == item.company)
        #expect(copy.location == "Hamburg")
        #expect(copy.priority == .high)
        #expect(copy.status == .wishlist)
        #expect(copy.appliedOn == nil)
        #expect(copy.followUpOn == nil)
        #expect(copy.uuid != item.uuid)
    }

    // MARK: Persistenz

    @Test("Bewerbungen lassen sich speichern und wieder laden")
    @MainActor
    func persistsApplications() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let item = application(status: .phoneScreen)
        item.workModel = .remote
        item.salaryMin = 60_000
        context.insert(item)
        try context.save()

        let loaded = try context.fetch(FetchDescriptor<JobApplication>())
        #expect(loaded.count == 1)
        #expect(loaded.first?.status == .phoneScreen)
        #expect(loaded.first?.workModel == .remote)
        #expect(loaded.first?.salaryMin == 60_000)
    }

    @Test("Beispieldaten sind vollständig und enthalten einen überfälligen Eintrag")
    @MainActor
    func sampleDataIsUsable() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        SampleData.insert(into: container.mainContext, now: date(2026, 3, 10), calendar: calendar)
        let items = try container.mainContext.fetch(FetchDescriptor<JobApplication>())
        #expect(items.count >= 5)
        #expect(items.allSatisfy { !$0.company.isEmpty && !$0.position.isEmpty })
        #expect(items.contains {
            if case .overdue = $0.followUpState(now: date(2026, 3, 10), calendar: calendar) { true } else { false }
        })
    }
}
