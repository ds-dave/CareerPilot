import Foundation

/// Reihenfolge der Karten im Board. Reine Logik, ohne Oberfläche testbar.
enum BoardOrdering {
    /// Karten einer Spalte in Anzeigereihenfolge. Archivierte Bewerbungen gehören nicht aufs Board.
    static func column(_ status: ApplicationStatus, in applications: [JobApplication]) -> [JobApplication] {
        applications
            .filter { !$0.isArchived && $0.status == status }
            .sorted { lhs, rhs in
                lhs.sortIndex != rhs.sortIndex ? lhs.sortIndex < rhs.sortIndex : lhs.createdAt > rhs.createdAt
            }
    }

    /// Verschiebt eine Karte in eine Spalte, vor `target` (oder ans Ende, wenn `nil`).
    /// Ein Spaltenwechsel wird dabei im Verlauf protokolliert.
    static func move(
        _ application: JobApplication,
        to status: ApplicationStatus,
        before target: JobApplication? = nil,
        among applications: [JobApplication],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        var destination = column(status, in: applications).filter { $0 !== application }
        let index = target.flatMap { target in destination.firstIndex { $0 === target } } ?? destination.endIndex
        destination.insert(application, at: index)
        application.change(status: status, now: now, calendar: calendar)
        for (position, item) in destination.enumerated() {
            item.sortIndex = position
        }
    }

    /// Der Status, den eine Karte um `offset` Spalten weiter links (negativ) oder rechts (positiv) hat.
    static func status(
        offsetBy offset: Int,
        from status: ApplicationStatus,
        within visible: [ApplicationStatus]
    ) -> ApplicationStatus? {
        guard let index = visible.firstIndex(of: status) else { return nil }
        let target = index + offset
        guard visible.indices.contains(target) else { return nil }
        return visible[target]
    }
}
