import SwiftData
import SwiftUI

struct BoardView: View {
    @Environment(ColumnSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    /// Die gerade sichtbaren Bewerbungen (Seitenleiste und Suche bereits angewendet).
    let applications: [JobApplication]
    /// Alle Bewerbungen, damit die Spaltenreihenfolge vollständig neu berechnet werden kann.
    let allApplications: [JobApplication]
    @Binding var selection: PersistentIdentifier?
    var onDelete: (JobApplication) -> Void
    /// Meldet eine rückgängig zu machende Aktion mit einem Satz für den Hinweis.
    var onAction: (String) -> Void = { _ in }

    private var hiddenCount: Int {
        applications.filter { !$0.isArchived && settings.isHidden($0.status) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(settings.visibleStatuses) { status in
                        BoardColumnView(
                            status: status,
                            cards: BoardOrdering.column(status, in: applications),
                            selection: selection,
                            onSelect: { selection = $0.persistentModelID },
                            onDrop: drop,
                            onMove: { card, target in
                                BoardOrdering.move(card, to: target, among: allApplications)
                                onAction("„\(card.displayCompany)“ nach „\(settings.title(for: target))“ verschoben")
                            },
                            onToggleArchive: { card in
                                card.isArchived.toggle()
                                onAction("„\(card.displayCompany)“ \(card.isArchived ? "archiviert" : "aus dem Archiv geholt")")
                            },
                            onDelete: onDelete
                        )
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.automatic)

            if hiddenCount > 0 {
                Text("\(hiddenCount) Bewerbung\(hiddenCount == 1 ? "" : "en") in ausgeblendeten Spalten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
    }

    private func drop(uuid: UUID, status: ApplicationStatus, target: JobApplication?) -> Bool {
        guard let card = allApplications.first(where: { $0.uuid == uuid }) else { return false }
        if let target, target === card { return false }
        let moved = card.status != status
        BoardOrdering.move(card, to: status, before: target, among: allApplications)
        selection = card.persistentModelID
        onAction(
            moved
                ? "„\(card.displayCompany)“ nach „\(settings.title(for: status))“ verschoben"
                : "„\(card.displayCompany)“ neu angeordnet"
        )
        return true
    }
}
