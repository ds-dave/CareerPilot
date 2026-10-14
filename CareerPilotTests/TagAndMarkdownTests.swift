import Foundation
import SwiftData
import Testing

@testable import CareerPilot

@Suite("Tags")
struct TagTests {
    @Test("Tags werden bereinigt")
    func clean() {
        #expect(TagList.clean("  #Swift ") == "Swift")
        #expect(TagList.clean("Remote   First") == "Remote First")
        #expect(TagList.clean("   ") == nil)
        #expect(TagList.clean("#") == nil)
        #expect(TagList.clean(String(repeating: "a", count: 80))?.count == TagList.maxLength)
    }

    @Test("Hinzufügen trennt an Komma und ignoriert Doppelte")
    func adding() {
        let result = TagList.adding("swift, Java; remote, SWIFT", to: ["Swift"])
        #expect(result == ["Swift", "Java", "remote"])
    }

    @Test("Tags sind durchsuchbar")
    func searchFindsTags() {
        let application = JobApplication(company: "Firma", position: "Dev")
        application.tags = ["Startup", "Hamburg-Nord"]
        #expect(application.matches(search: "startup"))
        #expect(!application.matches(search: "konzern"))
    }
}

@Suite("Markdown")
struct MarkdownTests {
    @Test("Überschriften, Listen, Aufgaben, Zitate und Absätze")
    func blocks() {
        let source = """
        # Titel
        Erste Zeile
        zweite Zeile

        - Punkt eins
        * [ ] offen
        - [x] erledigt
        1. Eins
        > Zitat
        ---
        """
        #expect(MarkdownParser.blocks(from: source) == [
            .heading(level: 1, text: "Titel"),
            .paragraph("Erste Zeile\nzweite Zeile"),
            .bullet(text: "Punkt eins", checked: nil),
            .bullet(text: "offen", checked: false),
            .bullet(text: "erledigt", checked: true),
            .numbered(number: 1, text: "Eins"),
            .quote("Zitat"),
            .rule,
        ])
    }

    @Test("Eine Raute ohne Leerzeichen ist keine Überschrift")
    func hashWithoutSpace() {
        #expect(MarkdownParser.blocks(from: "#hashtag") == [.paragraph("#hashtag")])
    }

    @Test("Leerer Text ergibt keine Blöcke")
    func empty() {
        #expect(MarkdownParser.blocks(from: " \n \n").isEmpty)
    }
}

@Suite("Verlauf")
struct TimelineTests {
    @Test("Statuswechsel landen im Verlauf, gleicher Status nicht")
    func logsChanges() {
        let application = JobApplication(company: "Firma", position: "Dev", status: .wishlist)
        application.change(status: .applied)
        application.change(status: .applied)
        application.change(status: .interview)
        #expect(application.timeline.count == 2)
        #expect(application.timeline.map(\.toStatus) == [.applied, .interview])
    }

    @Test("Der Verlauf wird mit der Bewerbung gelöscht")
    @MainActor
    func cascadeDelete() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let application = JobApplication(company: "Firma", position: "Dev")
        application.timeline.append(TimelineEntry(kind: .note, text: "Hallo"))
        context.insert(application)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<TimelineEntry>()) == 1)

        context.delete(application)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<TimelineEntry>()) == 0)
    }
}
