import Foundation
import Testing

@testable import CareerPilot

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    calendar.firstWeekday = 2
    calendar.locale = Locale(identifier: "de_DE")
    return calendar
}()

private func day(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

/// Baut eine Bewerbung mit Verlauf: `history` ist die Reihenfolge der Stationen mit Datum.
private func application(
    _ company: String,
    status: ApplicationStatus,
    appliedOn: Date?,
    source: ApplicationSource? = nil,
    history: [(Date, ApplicationStatus)] = []
) -> JobApplication {
    let item = JobApplication(company: company, position: "Dev", status: status)
    item.appliedOn = appliedOn
    item.source = source
    item.createdAt = appliedOn ?? day(1, 1)
    var previous = ApplicationStatus.wishlist
    for (date, next) in history {
        item.timeline.append(TimelineEntry(kind: .statusChanged, date: date, from: previous, to: next))
        previous = next
    }
    return item
}

@Suite("Statistik")
struct StatisticsTests {
    private let now = day(3, 31)

    private func sample() -> [JobApplication] {
        [
            // Interview erreicht, Antwort nach 4 Tagen
            application("A", status: .interview, appliedOn: day(3, 1), source: .linkedIn, history: [
                (day(3, 1), .applied), (day(3, 5), .acknowledged), (day(3, 12), .interview),
            ]),
            // Angebot erreicht, Antwort nach 6 Tagen
            application("B", status: .offer, appliedOn: day(3, 2), source: .linkedIn, history: [
                (day(3, 2), .applied), (day(3, 8), .phoneScreen), (day(3, 15), .interview), (day(3, 25), .offer),
            ]),
            // Absage nach Interview: zählt für Antwort und Interview
            application("C", status: .rejected, appliedOn: day(3, 3), source: .indeed, history: [
                (day(3, 3), .applied), (day(3, 6), .interview), (day(3, 20), .rejected),
            ]),
            // Keine Antwort seit 20 Tagen
            application("D", status: .applied, appliedOn: day(3, 11), source: .indeed, history: [(day(3, 11), .applied)]),
            // Keine Antwort seit 10 Tagen, ohne Quelle
            application("E", status: .applied, appliedOn: day(3, 21), history: [(day(3, 21), .applied)]),
            // Nur auf der Wunschliste
            application("F", status: .wishlist, appliedOn: nil),
        ]
    }

    @Test("Kennzahlen: Anzahl, Quoten, offen, Absagen")
    func headlineNumbers() {
        let stats = StatisticsCalculator.compute(applications: sample(), range: .all, now: now, calendar: calendar)
        #expect(stats.applied == 5)
        #expect(stats.responded == 3)
        #expect(stats.interviewed == 3)
        #expect(stats.offers == 1)
        #expect(stats.rejected == 1)
        #expect(stats.accepted == 0)
        #expect(stats.open == 4)
        #expect(stats.responseRate == 3.0 / 5.0)
        #expect(stats.interviewRate == 3.0 / 5.0)
    }

    @Test("Ø Tage bis zur ersten Antwort aus dem Verlauf")
    func averageResponseTime() {
        let stats = StatisticsCalculator.compute(applications: sample(), range: .all, now: now, calendar: calendar)
        // A: 1.3. -> 5.3. = 4, B: 2.3. -> 8.3. = 6, C: 3.3. -> 6.3. = 3
        #expect(stats.responseTimeSamples == 3)
        let average = try? #require(stats.averageDaysToResponse)
        #expect(abs((average ?? 0) - 13.0 / 3.0) < 0.0001)
    }

    @Test("Ohne bekanntes Antwortdatum keine Durchschnittszeit")
    func noResponseDate() {
        let legacy = application("Alt", status: .interview, appliedOn: day(3, 1))
        let stats = StatisticsCalculator.compute(applications: [legacy], range: .all, now: now, calendar: calendar)
        #expect(stats.responded == 1)
        #expect(stats.averageDaysToResponse == nil)
        #expect(stats.responseTimeSamples == 0)
    }

    @Test("Am längsten wartend: nur Bewerbungen ohne Antwort")
    func longestWaiting() {
        let stats = StatisticsCalculator.compute(applications: sample(), range: .all, now: now, calendar: calendar)
        #expect(stats.longestWaiting == WaitingEntry(company: "D", position: "Dev", days: 20))
    }

    @Test("Trichter: Stufen und Anteile")
    func funnel() {
        let stats = StatisticsCalculator.compute(applications: sample(), range: .all, now: now, calendar: calendar)
        #expect(stats.funnel.map(\.title) == ["Beworben", "Antwort", "Interview", "Angebot"])
        #expect(stats.funnel.map(\.count) == [5, 3, 3, 1])
        #expect(stats.funnel[1].share == 0.6)
    }

    @Test("Ein Termin vom Typ Interview zählt als Gespräch, auch ohne Statuswechsel")
    func eventCountsAsInterview() {
        let item = application("G", status: .applied, appliedOn: day(3, 10))
        item.events.append(ApplicationEvent(kind: .interview, start: day(4, 2)))
        let stats = StatisticsCalculator.compute(applications: [item], range: .all, now: now, calendar: calendar)
        #expect(stats.interviewed == 1)
    }

    @Test("Zeitraum: 4 Wochen schließt ältere Bewerbungen aus")
    func rangeFilter() {
        let all = StatisticsCalculator.compute(applications: sample(), range: .all, now: now, calendar: calendar)
        let recent = StatisticsCalculator.compute(applications: sample(), range: .fourWeeks, now: day(3, 31), calendar: calendar)
        #expect(all.applied == 5)
        // 4 Wochen vor dem 31.3. ist der 3.3.: A (1.3.) und B (2.3.) fallen heraus.
        #expect(recent.applied == 3)
        let none = StatisticsCalculator.compute(applications: sample(), range: .fourWeeks, now: day(8, 1), calendar: calendar)
        #expect(none.applied == 0)
        #expect(none.weekly.allSatisfy { $0.count == 0 })
    }

    @Test("Wochen: lückenlos mit Nullwochen und richtigen Zählungen")
    func weekly() {
        let stats = StatisticsCalculator.compute(applications: sample(), range: .all, now: now, calendar: calendar)
        let weeks = stats.weekly
        #expect(weeks.first.map { calendar.isDate($0.weekStart, inSameDayAs: day(2, 23)) } == true)
        #expect(weeks.last.map { calendar.isDate($0.weekStart, inSameDayAs: day(3, 30)) } == true)
        #expect(weeks.map(\.count).reduce(0, +) == 5)
        let week = { (date: Date) in weeks.first { calendar.isDate($0.weekStart, inSameDayAs: date) }?.count }
        #expect(week(day(2, 23)) == 1)  // A am Sonntag 1.3.
        #expect(week(day(3, 2)) == 2)   // B und C
        #expect(week(day(3, 9)) == 1)   // D
        #expect(week(day(3, 16)) == 1)  // E am Samstag 21.3.
        #expect(week(day(3, 23)) == 0)
        // Wochenabstand überall genau 7 Tage
        for pair in zip(weeks, weeks.dropFirst()) {
            #expect(calendar.dateComponents([.day], from: pair.0.weekStart, to: pair.1.weekStart).day == 7)
        }
    }

    @Test("Ergebnis nach Onlineportal, größte Quelle zuerst, bei Gleichstand alphabetisch")
    func sourceOutcomes() {
        let stats = StatisticsCalculator.compute(applications: sample(), range: .all, now: now, calendar: calendar)
        let rows = stats.sourceOutcomes
        let order = rows.reduce(into: [String]()) { names, row in
            if names.last != row.source { names.append(row.source) }
        }
        #expect(order == ["Indeed", "LinkedIn", "Ohne Angabe"])
        func count(_ source: String, _ outcome: Outcome) -> Int {
            rows.first { $0.source == source && $0.outcome == outcome }?.count ?? 0
        }
        #expect(count("LinkedIn", .inTalks) == 1)
        #expect(count("LinkedIn", .offer) == 1)
        #expect(count("Indeed", .rejected) == 1)
        #expect(count("Indeed", .open) == 1)
        #expect(count("Ohne Angabe", .open) == 1)
    }

    @Test("Verteilung nach Status zählt auch die Wunschliste")
    func statusDistribution() {
        let stats = StatisticsCalculator.compute(applications: sample(), range: .all, now: now, calendar: calendar)
        let byStatus = Dictionary(uniqueKeysWithValues: stats.statusDistribution.map { ($0.status, $0.count) })
        #expect(byStatus[.applied] == 2)
        #expect(byStatus[.wishlist] == 1)
        #expect(byStatus[.offer] == 1)
        #expect(byStatus[.accepted] == nil)
    }

    @Test("Archivierte Bewerbungen zählen mit, sind aber nicht mehr offen")
    func archived() {
        let items = sample()
        items[3].isArchived = true  // D
        let stats = StatisticsCalculator.compute(applications: items, range: .all, now: now, calendar: calendar)
        #expect(stats.applied == 5)
        #expect(stats.open == 3)
        #expect(stats.longestWaiting?.company == "E")
    }

    @Test("Leere Daten ergeben keine Quoten und eine lückenlose Wochenreihe")
    func empty() {
        let stats = StatisticsCalculator.compute(applications: [], range: .all, now: now, calendar: calendar)
        #expect(stats.applied == 0)
        #expect(stats.responseRate == nil)
        #expect(stats.interviewRate == nil)
        #expect(stats.longestWaiting == nil)
        #expect(stats.funnel.allSatisfy { $0.count == 0 && $0.share == nil })
        #expect(stats.weekly.count == 1)
    }

    @Test("Der Wochenverlauf zeigt höchstens ein Jahr")
    func weeklyLimit() {
        let old = application("Alt", status: .applied, appliedOn: day(1, 5, year: 2020))
        let stats = StatisticsCalculator.compute(applications: [old], range: .all, now: now, calendar: calendar)
        #expect(stats.weekly.count == 52)
        #expect(stats.applied == 1)
    }

    @Test("Ergebnis aus dem aktuellen Status")
    func outcomeMapping() {
        #expect(Outcome(status: .accepted) == .accepted)
        #expect(Outcome(status: .offer) == .offer)
        #expect(Outcome(status: .phoneScreen) == .inTalks)
        #expect(Outcome(status: .interview) == .inTalks)
        #expect(Outcome(status: .acknowledged) == .open)
        #expect(Outcome(status: .rejected) == .rejected)
    }
}
