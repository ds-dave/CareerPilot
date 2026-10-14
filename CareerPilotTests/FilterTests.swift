import Foundation
import Testing

@testable import CareerPilot

private func application(
    _ company: String,
    priority: Priority = .medium,
    workModel: WorkModel? = nil,
    source: ApplicationSource? = nil,
    status: ApplicationStatus = .applied,
    tags: [String] = []
) -> JobApplication {
    let item = JobApplication(company: company, position: "Dev", status: status)
    item.priority = priority
    item.workModel = workModel
    item.source = source
    item.tags = tags
    return item
}

@Suite("Filter")
struct FilterTests {
    private let all = [
        application("A", priority: .high, workModel: .remote, source: .linkedIn, tags: ["Swift"]),
        application("B", priority: .high, workModel: .onsite, source: .indeed, tags: ["Java"]),
        application("C", priority: .low, workModel: .remote, source: .linkedIn, status: .interview),
        application("D", priority: .medium, workModel: nil, source: nil),
    ]

    private func names(_ filter: ApplicationFilter) -> [String] {
        all.filter(filter.matches).map(\.company)
    }

    @Test("Ein leerer Filter lässt alles durch")
    func empty() {
        #expect(ApplicationFilter().isEmpty)
        #expect(names(ApplicationFilter()) == ["A", "B", "C", "D"])
    }

    @Test("Innerhalb einer Kategorie genügt ein Treffer")
    func orWithinCategory() {
        var filter = ApplicationFilter()
        filter.priorities = [.high, .low]
        #expect(names(filter) == ["A", "B", "C"])
    }

    @Test("Zwischen Kategorien müssen alle passen")
    func andAcrossCategories() {
        var filter = ApplicationFilter()
        filter.priorities = [.high]
        filter.workModels = [.remote]
        #expect(names(filter) == ["A"])
    }

    @Test("Ohne Angabe passt nicht auf einen gesetzten Filter")
    func missingValues() {
        var filter = ApplicationFilter()
        filter.sources = [.linkedIn]
        #expect(names(filter) == ["A", "C"])
        filter = ApplicationFilter()
        filter.workModels = [.remote, .onsite, .hybrid]
        #expect(!names(filter).contains("D"))
    }

    @Test("Status, Tags (ohne Beachtung der Schreibweise) und Suche")
    func statusTagsSearch() {
        var filter = ApplicationFilter()
        filter.statuses = [.interview]
        #expect(names(filter) == ["C"])

        filter = ApplicationFilter()
        filter.tags = ["swift"]
        #expect(names(filter) == ["A"])

        let hamburg = application("Nordlicht")
        hamburg.location = "Hamburg"
        let berlin = application("Beispiel")
        berlin.location = "Berlin"
        filter = ApplicationFilter()
        filter.search = "nordlicht dev"
        #expect([hamburg, berlin].filter(filter.matches).map(\.company) == ["Nordlicht"])
        filter.search = "hamburg berlin"
        #expect([hamburg, berlin].filter(filter.matches).isEmpty)
    }

    @Test("Überlagern ersetzt nur gesetzte Kategorien")
    func overlay() {
        var base = ApplicationFilter()
        base.priorities = [.high]
        base.workModels = [.remote]
        var top = ApplicationFilter()
        top.workModels = [.onsite]
        top.tags = ["Java"]

        let merged = base.overlaid(with: top)
        #expect(merged.priorities == [.high])
        #expect(merged.workModels == [.onsite])
        #expect(merged.tags == ["Java"])
    }

    @Test("Zählung aktiver Einschränkungen")
    func activeCount() {
        var filter = ApplicationFilter()
        #expect(filter.activeCount == 0)
        filter.priorities = [.high, .low]
        filter.tags = ["x"]
        filter.search = "  "
        #expect(filter.activeCount == 3)
        filter.search = "swift"
        #expect(filter.activeCount == 4)
    }
}

@MainActor
@Suite("Gespeicherte Filter")
struct SavedFilterStoreTests {
    private func makeStore() -> (SavedFilterStore, UserDefaults) {
        let suite = "careerpilot.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (SavedFilterStore(defaults: defaults), defaults)
    }

    @Test("Speichern, Laden, Umbenennen, Löschen")
    func lifecycle() {
        let (store, defaults) = makeStore()
        var filter = ApplicationFilter()
        filter.priorities = [.high]
        filter.workModels = [.remote]

        let saved = store.add(name: "  Remote, wichtig ", filter: filter)
        #expect(saved?.name == "Remote, wichtig")
        #expect(store.filters.count == 1)

        let reloaded = SavedFilterStore(defaults: defaults)
        #expect(reloaded.filters.first?.filter == filter)

        store.rename(id: saved!.id, to: "Top-Remote")
        #expect(SavedFilterStore(defaults: defaults).filters.first?.name == "Top-Remote")

        store.remove(id: saved!.id)
        #expect(SavedFilterStore(defaults: defaults).filters.isEmpty)
    }

    @Test("Leere Namen und leere Filter werden nicht gespeichert")
    func rejects() {
        let (store, _) = makeStore()
        var filter = ApplicationFilter()
        filter.priorities = [.high]
        #expect(store.add(name: "   ", filter: filter) == nil)
        #expect(store.add(name: "Leer", filter: ApplicationFilter()) == nil)
        #expect(store.filters.isEmpty)
    }

    @Test("Eine Suche allein ist ein gültiger Filter")
    func searchOnly() {
        let (store, _) = makeStore()
        var filter = ApplicationFilter()
        filter.search = "Hamburg"
        #expect(store.add(name: "Hamburg", filter: filter) != nil)
    }
}
