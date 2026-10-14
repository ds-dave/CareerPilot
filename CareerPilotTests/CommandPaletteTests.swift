import Foundation
import Testing

@testable import CareerPilot

@MainActor
@Suite("Befehlspalette")
struct CommandPaletteTests {
    private func application(_ company: String, position: String = "Dev", status: ApplicationStatus = .applied,
                             created: TimeInterval = 0) -> JobApplication {
        let item = JobApplication(company: company, position: position, status: status)
        item.createdAt = Date(timeIntervalSince1970: created)
        return item
    }

    private func items(_ applications: [JobApplication] = [], tags: [String] = [],
                       filters: [SavedFilter] = []) -> [PaletteItem] {
        CommandPalette.items(
            applications: applications, savedFilters: filters, tags: tags,
            statusTitle: { $0.title }, visibleStatuses: ApplicationStatus.allCases
        )
    }

    private func titles(_ query: String, in items: [PaletteItem]) -> [String] {
        CommandPalette.search(items, query: query).map(\.title)
    }

    @Test("Ohne Suchtext: Befehle, Ansichten und die neuesten Bewerbungen")
    func defaultList() {
        let apps = (0..<8).map { application("Firma \($0)", created: TimeInterval($0)) }
        let result = CommandPalette.search(items(apps), query: "", limit: 100)
        #expect(result.first?.title == "Neue Bewerbung")
        #expect(result.contains { $0.title == "Statistik" })
        let companies = result.filter { $0.group == .application }.map(\.title)
        #expect(companies == ["Firma 7", "Firma 6", "Firma 5", "Firma 4", "Firma 3"])
    }

    @Test("Anfang des Titels schlägt Treffer mitten im Wort")
    func prefixRanking() {
        let all = items([application("Beispiel AG"), application("Probe Robotics"), application("Notbeispiel")])
        let result = titles("bei", in: all)
        #expect(result.first == "Beispiel AG")
        #expect(result.contains("Notbeispiel"))
    }

    @Test("Akzente und Groß-/Kleinschreibung spielen keine Rolle")
    func folding() {
        let all = items([application("Müller & Söhne")])
        #expect(titles("muller", in: all).contains("Müller & Söhne"))
        #expect(titles("SOEHNE", in: all).isEmpty)  // ö wird zu o, nicht zu oe
        #expect(titles("sohne", in: all).contains("Müller & Söhne"))
    }

    @Test("Mehrere Begriffe müssen alle vorkommen, auch in Untertitel und Stichwörtern")
    func multipleTokens() {
        let all = items([
            application("Nordlicht", position: "Backend-Entwickler", status: .interview),
            application("Beispiel", position: "Frontend-Entwickler", status: .applied),
        ])
        #expect(titles("nordlicht interview", in: all) == ["Nordlicht"])
        #expect(titles("entwickler", in: all).filter { $0 == "Nordlicht" || $0 == "Beispiel" }.count == 2)
        #expect(titles("nordlicht frontend", in: all).isEmpty)
    }

    @Test("Befehle sind über Stichwörter auffindbar")
    func keywords() {
        let result = CommandPalette.search(items(), query: "excel")
        #expect(result.first?.action == .data(.exportCSV))
        #expect(CommandPalette.search(items(), query: "kanban").first?.action == .setViewMode(.board))
        #expect(CommandPalette.search(items(), query: "erinnerungen").contains { $0.action == .openSettings })
    }

    @Test("Tags, gespeicherte Ansichten und Status erscheinen als Ziele")
    func destinations() {
        let saved = SavedFilter(name: "Remote und wichtig", filter: ApplicationFilter(priorities: [.high]))
        let all = items(tags: ["Swift"], filters: [saved])
        #expect(CommandPalette.search(all, query: "#swift").first?.action == .show(.tag("Swift")))
        #expect(CommandPalette.search(all, query: "remote wichtig").first?.action == .show(.savedFilter(saved.id)))
        #expect(CommandPalette.search(all, query: "telefonat").contains { $0.action == .show(.status(.phoneScreen)) })
    }

    @Test("Archivierte Bewerbungen sind auffindbar und gekennzeichnet")
    func archived() {
        let old = application("Altfirma")
        old.isArchived = true
        let result = CommandPalette.search(items([old]), query: "altfirma")
        #expect(result.first?.subtitle?.contains("archiviert") == true)
    }

    @Test("Das Ergebnis ist begrenzt, Einträge haben eindeutige IDs")
    func limitAndIDs() {
        let apps = (0..<40).map { application("Firma \($0)") }
        let all = items(apps)
        #expect(CommandPalette.search(all, query: "firma").count == CommandPalette.resultLimit)
        #expect(Set(all.map(\.id)).count == all.count)
    }

    @Test("Ein anstehender Termin erscheint, ein vergangener nicht")
    func events() {
        let item = application("Terminfirma")
        let now = Date(timeIntervalSince1970: 1_000_000)
        item.events.append(ApplicationEvent(kind: .interview, start: now.addingTimeInterval(3_600)))
        item.events.append(ApplicationEvent(kind: .phone, start: now.addingTimeInterval(-3_600)))
        let all = CommandPalette.items(
            applications: [item], savedFilters: [], tags: [], statusTitle: { $0.title },
            visibleStatuses: [], now: now
        )
        let events = all.filter { $0.group == .event }
        #expect(events.count == 1)
        #expect(events.first?.title == "Interview · Terminfirma")
    }
}
