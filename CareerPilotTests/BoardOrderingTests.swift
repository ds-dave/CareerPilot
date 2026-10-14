import Foundation
import Testing

@testable import CareerPilot

@Suite("BoardOrdering")
struct BoardOrderingTests {
    private func make(
        _ company: String, _ status: ApplicationStatus, index: Int, archived: Bool = false
    ) -> JobApplication {
        let application = JobApplication(company: company, position: "Dev", status: status)
        application.sortIndex = index
        application.isArchived = archived
        return application
    }

    private func names(_ items: [JobApplication]) -> [String] {
        items.map(\.company)
    }

    @Test("Eine Spalte ist nach Index sortiert und ohne Archiv")
    func columnIsSortedAndSkipsArchived() {
        let apps = [
            make("C", .applied, index: 2),
            make("A", .applied, index: 0),
            make("B", .applied, index: 1),
            make("X", .applied, index: 3, archived: true),
            make("Y", .interview, index: 0),
        ]
        #expect(names(BoardOrdering.column(.applied, in: apps)) == ["A", "B", "C"])
    }

    @Test("Bei gleichem Index steht die neuere Karte oben")
    func ties() {
        let older = make("Alt", .applied, index: 0)
        older.createdAt = Date(timeIntervalSince1970: 1_000)
        let newer = make("Neu", .applied, index: 0)
        newer.createdAt = Date(timeIntervalSince1970: 2_000)
        #expect(names(BoardOrdering.column(.applied, in: [older, newer])) == ["Neu", "Alt"])
    }

    @Test("Verschieben in eine andere Spalte hängt ans Ende und protokolliert den Wechsel")
    func moveToOtherColumnAppendsAndLogs() {
        let a = make("A", .wishlist, index: 0)
        let x = make("X", .applied, index: 0)
        let y = make("Y", .applied, index: 1)
        let apps = [a, x, y]

        BoardOrdering.move(a, to: .applied, among: apps)

        #expect(a.status == .applied)
        #expect(names(BoardOrdering.column(.applied, in: apps)) == ["X", "Y", "A"])
        #expect(a.timeline.count == 1)
        #expect(a.timeline.first?.kind == .statusChanged)
        #expect(a.timeline.first?.fromStatus == .wishlist)
        #expect(a.timeline.first?.toStatus == .applied)
    }

    @Test("Verschieben vor eine Karte fügt an dieser Stelle ein")
    func moveBeforeTarget() {
        let a = make("A", .wishlist, index: 0)
        let x = make("X", .applied, index: 0)
        let y = make("Y", .applied, index: 1)
        let apps = [a, x, y]

        BoardOrdering.move(a, to: .applied, before: y, among: apps)

        #expect(names(BoardOrdering.column(.applied, in: apps)) == ["X", "A", "Y"])
        #expect(apps.filter { $0.status == .applied }.map(\.sortIndex).sorted() == [0, 1, 2])
    }

    @Test("Umsortieren innerhalb einer Spalte ändert den Status nicht und schreibt keinen Verlauf")
    func reorderWithinColumn() {
        let x = make("X", .applied, index: 0)
        let y = make("Y", .applied, index: 1)
        let z = make("Z", .applied, index: 2)
        let apps = [x, y, z]

        BoardOrdering.move(z, to: .applied, before: x, among: apps)

        #expect(names(BoardOrdering.column(.applied, in: apps)) == ["Z", "X", "Y"])
        #expect(z.timeline.isEmpty)
    }

    @Test("Leere Spalte: die Karte wird die erste")
    func moveIntoEmptyColumn() {
        let a = make("A", .applied, index: 4)
        BoardOrdering.move(a, to: .interview, among: [a])
        #expect(a.sortIndex == 0)
        #expect(a.status == .interview)
    }

    @Test("Status-Versatz für Tastaturbedienung bleibt in den sichtbaren Spalten")
    func statusOffset() {
        let visible: [ApplicationStatus] = [.wishlist, .applied, .interview]
        #expect(BoardOrdering.status(offsetBy: 1, from: .applied, within: visible) == .interview)
        #expect(BoardOrdering.status(offsetBy: -1, from: .applied, within: visible) == .wishlist)
        #expect(BoardOrdering.status(offsetBy: 1, from: .interview, within: visible) == nil)
        #expect(BoardOrdering.status(offsetBy: -1, from: .wishlist, within: visible) == nil)
        #expect(BoardOrdering.status(offsetBy: 1, from: .offer, within: visible) == nil)
    }
}
