import SwiftUI

/// Einträge der Seitenleiste. Jeder Eintrag entscheidet selbst, welche Bewerbungen er zeigt.
enum SidebarItem: Hashable {
    case agenda
    case calendar
    case statistics
    case all
    case open
    case followUp
    case status(ApplicationStatus)
    case tag(String)
    case savedFilter(UUID)
    case archive

    @MainActor
    func title(using settings: ColumnSettings, savedFilters: SavedFilterStore? = nil) -> String {
        switch self {
        case .agenda: "Heute"
        case .calendar: "Termine"
        case .statistics: "Statistik"
        case .all: "Alle"
        case .open: "Offen"
        case .followUp: "Nachfassen"
        case .status(let status): settings.title(for: status)
        case .tag(let tag): "#\(tag)"
        case .savedFilter(let id): savedFilters?.filter(withID: id)?.name ?? "Ansicht"
        case .archive: "Archiv"
        }
    }

    var systemImage: String {
        switch self {
        case .agenda: "sun.max"
        case .calendar: "calendar"
        case .statistics: "chart.bar"
        case .all: "tray.full"
        case .open: "circle.dotted"
        case .followUp: "bell"
        case .status(let status): status.systemImage
        case .tag: "tag"
        case .savedFilter: "line.3.horizontal.decrease.circle"
        case .archive: "archivebox"
        }
    }

    /// Zeigt diese Ansicht Bewerbungen als Board oder Liste (im Gegensatz zu "Heute" und "Termine")?
    var showsApplications: Bool {
        switch self {
        case .agenda, .calendar, .statistics: false
        default: true
        }
    }

    /// Farbe des Symbols. Nur Status haben eine eigene Farbe.
    var tint: Color? {
        if case .status(let status) = self { return status.color }
        return nil
    }

    func includes(_ application: JobApplication) -> Bool {
        switch self {
        case .agenda, .calendar, .statistics: false
        case .all: !application.isArchived
        case .open: application.isOpen
        case .followUp: application.followUpState().needsAttention
        case .status(let status): !application.isArchived && application.status == status
        case .tag(let tag): !application.isArchived && TagList.contains(application.tags, tag)
        // Der gespeicherte Filter selbst wird von der Ansicht angewendet, hier zählt nur "nicht archiviert".
        case .savedFilter: !application.isArchived
        case .archive: application.isArchived
        }
    }
}
