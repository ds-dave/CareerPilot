import Foundation
import Testing

@testable import CareerPilot

@MainActor
@Suite("ColumnSettings")
struct ColumnSettingsTests {
    private func makeSettings() -> (ColumnSettings, UserDefaults, String) {
        let suite = "careerpilot.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (ColumnSettings(defaults: defaults), defaults, suite)
    }

    @Test("Standard: alle Spalten sichtbar in Standardreihenfolge und -beschriftung")
    func defaults() {
        let (settings, _, _) = makeSettings()
        #expect(settings.visibleStatuses == ApplicationStatus.allCases)
        #expect(settings.title(for: .interview) == "Interview")
    }

    @Test("Umbenennen und Zurücknennen auf den Standard")
    func renaming() {
        let (settings, _, _) = makeSettings()
        settings.rename(.applied, to: "  Abgeschickt ")
        #expect(settings.title(for: .applied) == "Abgeschickt")
        settings.rename(.applied, to: "")
        #expect(settings.title(for: .applied) == "Beworben")
    }

    @Test("Ausblenden entfernt die Spalte, die letzte sichtbare bleibt aber")
    func hiding() {
        let (settings, _, _) = makeSettings()
        settings.setHidden(true, for: .rejected)
        #expect(!settings.visibleStatuses.contains(.rejected))

        for status in ApplicationStatus.allCases { settings.setHidden(true, for: status) }
        #expect(settings.visibleStatuses.count == 1)
    }

    @Test("Umsortieren")
    func reordering() {
        let (settings, _, _) = makeSettings()
        settings.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(Array(settings.order.prefix(3)) == [.applied, .acknowledged, .wishlist])
    }

    @Test("Einstellungen überleben einen Neustart")
    func persistence() {
        let (settings, defaults, _) = makeSettings()
        settings.rename(.offer, to: "Vertrag")
        settings.setHidden(true, for: .phoneScreen)
        settings.move(fromOffsets: IndexSet(integer: 7), toOffset: 0)

        let reloaded = ColumnSettings(defaults: defaults)
        #expect(reloaded.title(for: .offer) == "Vertrag")
        #expect(reloaded.isHidden(.phoneScreen))
        #expect(reloaded.order.first == .rejected)
    }

    @Test("Zurücksetzen stellt alles wieder her")
    func reset() {
        let (settings, defaults, _) = makeSettings()
        settings.rename(.offer, to: "Vertrag")
        settings.setHidden(true, for: .phoneScreen)
        settings.reset()
        #expect(settings.title(for: .offer) == "Angebot")
        #expect(settings.visibleStatuses == ApplicationStatus.allCases)
        #expect(ColumnSettings(defaults: defaults).title(for: .offer) == "Angebot")
    }
}
