import Foundation
import SwiftData

/// Was die Befehlspalette auslösen kann.
enum PaletteAction: Equatable {
    case newApplication
    case show(SidebarItem)
    case setViewMode(ViewMode)
    case openApplication(PersistentIdentifier)
    case openEvent(PersistentIdentifier)
    case editColumns
    case openSettings
    case data(DataAction)
}

struct PaletteItem: Identifiable, Equatable {
    /// Reihenfolge der Gruppen bei gleichem Treffer.
    enum Group: Int {
        case command, view, application, event
    }

    let id: String
    let title: String
    var subtitle: String?
    let systemImage: String
    let group: Group
    var keywords: [String] = []
    let action: PaletteAction
}

enum CommandPalette {
    // MARK: Einträge

    /// Alle Einträge, die die Palette kennt. Die Reihenfolge ist die Standardansicht ohne Suchtext.
    static func items(
        applications: [JobApplication],
        savedFilters: [SavedFilter],
        tags: [String],
        statusTitle: (ApplicationStatus) -> String,
        visibleStatuses: [ApplicationStatus],
        now: Date = .now
    ) -> [PaletteItem] {
        var items: [PaletteItem] = [
            command("new", "Neue Bewerbung", "plus", .newApplication, ["anlegen", "hinzufügen", "erstellen"]),
            command("board", "Als Board anzeigen", "rectangle.split.3x1", .setViewMode(.board), ["kanban", "spalten"]),
            command("list", "Als Liste anzeigen", "list.bullet", .setViewMode(.list), ["tabelle"]),
            command("columns", "Spalten anpassen", "slider.horizontal.3", .editColumns, ["umbenennen", "ausblenden", "sortieren"]),
            command("export-csv", "Als CSV exportieren", "tablecells", .data(.exportCSV), ["excel", "numbers", "tabelle"]),
            command("export-json", "Backup als JSON exportieren", "externaldrive", .data(.exportBackup), ["sichern", "sicherung"]),
            command("import", "Backup importieren", "square.and.arrow.down", .data(.importBackup), ["wiederherstellen", "laden"]),
            command("settings", "Einstellungen öffnen", "gearshape", .openSettings, ["erinnerungen", "benachrichtigungen", "animation"]),
        ]

        let views: [(String, String, String, SidebarItem, [String])] = [
            ("agenda", "Heute", "sun.max", .agenda, ["überfällig", "fällig", "agenda"]),
            ("calendar", "Termine", "calendar", .calendar, ["kalender", "interview"]),
            ("statistics", "Statistik", "chart.bar", .statistics, ["auswertung", "quote", "diagramm"]),
            ("all", "Alle Bewerbungen", "tray.full", .all, ["übersicht"]),
            ("open", "Offene Bewerbungen", "circle.dotted", .open, []),
            ("followUp", "Nachfassen", "bell", .followUp, ["erinnerung"]),
            ("archive", "Archiv", "archivebox", .archive, []),
        ]
        for (id, title, image, item, keywords) in views {
            items.append(PaletteItem(
                id: "view-\(id)", title: title, subtitle: "Ansicht", systemImage: image,
                group: .view, keywords: keywords, action: .show(item)
            ))
        }
        for status in visibleStatuses {
            items.append(PaletteItem(
                id: "status-\(status.rawValue)", title: statusTitle(status), subtitle: "Status",
                systemImage: status.systemImage, group: .view, keywords: ["status"],
                action: .show(.status(status))
            ))
        }
        for tag in tags {
            items.append(PaletteItem(
                id: "tag-\(tag.lowercased())", title: "#\(tag)", subtitle: "Tag", systemImage: "tag",
                group: .view, keywords: ["tag"], action: .show(.tag(tag))
            ))
        }
        for saved in savedFilters {
            items.append(PaletteItem(
                id: "filter-\(saved.id.uuidString)", title: saved.name, subtitle: "Gespeicherte Ansicht",
                systemImage: "line.3.horizontal.decrease.circle", group: .view, keywords: ["filter"],
                action: .show(.savedFilter(saved.id))
            ))
        }

        // Bewerbungen: zuletzt angelegte zuerst.
        for application in applications.sorted(by: { $0.createdAt > $1.createdAt }) {
            var parts = [application.position, statusTitle(application.status)]
            if application.isArchived { parts.append("archiviert") }
            items.append(PaletteItem(
                id: "app-\(application.uuid.uuidString)",
                title: application.displayCompany,
                subtitle: parts.filter { !$0.isEmpty }.joined(separator: " · "),
                systemImage: "briefcase",
                group: .application,
                keywords: [application.location] + application.tags,
                action: .openApplication(application.persistentModelID)
            ))
        }

        // Anstehende Termine.
        let upcoming = applications.filter { !$0.isArchived }.flatMap(\.events)
            .filter { $0.start >= now }
            .sorted { $0.start < $1.start }
        for event in upcoming.prefix(20) {
            items.append(PaletteItem(
                id: "event-\(event.uuid.uuidString)",
                title: "\(event.displayTitle) · \(event.application?.displayCompany ?? "")",
                subtitle: event.start.formatted(date: .abbreviated, time: .shortened),
                systemImage: event.kind.systemImage,
                group: .event,
                keywords: ["termin"],
                action: .openEvent(event.persistentModelID)
            ))
        }
        return items
    }

    private static func command(
        _ id: String, _ title: String, _ image: String, _ action: PaletteAction, _ keywords: [String]
    ) -> PaletteItem {
        PaletteItem(id: "cmd-\(id)", title: title, subtitle: "Befehl", systemImage: image,
                    group: .command, keywords: keywords, action: action)
    }

    // MARK: Suche

    static let resultLimit = 12
    static let defaultApplicationCount = 5

    /// Filtert und sortiert die Einträge. Jeder Suchbegriff muss irgendwo vorkommen;
    /// Treffer am Wortanfang des Titels stehen vor Treffern in Untertitel und Stichwörtern.
    static func search(_ items: [PaletteItem], query: String, limit: Int = resultLimit) -> [PaletteItem] {
        let tokens = fold(query).split(whereSeparator: \.isWhitespace).map(String.init)

        guard !tokens.isEmpty else {
            // Ohne Suchtext: Befehle und Ansichten, dazu die zuletzt angelegten Bewerbungen.
            let base = items.filter { $0.group == .command || $0.group == .view }
            let recent = items.filter { $0.group == .application }.prefix(defaultApplicationCount)
            return Array((base + recent).prefix(limit))
        }

        struct Scored {
            let item: PaletteItem
            let score: Int
            let order: Int
        }

        var scored: [Scored] = []
        for (order, item) in items.enumerated() {
            let title = fold(item.title)
            let rest = fold(([item.subtitle].compactMap { $0 } + item.keywords).joined(separator: " "))
            var total = 0
            var matchesAll = true
            for token in tokens {
                if title.hasPrefix(token) {
                    total += 0
                } else if title.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(token) }) {
                    total += 1
                } else if title.contains(token) {
                    total += 2
                } else if rest.contains(token) {
                    total += 3
                } else {
                    matchesAll = false
                    break
                }
            }
            if matchesAll {
                scored.append(Scored(item: item, score: total, order: order))
            }
        }

        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            if lhs.item.group != rhs.item.group { return lhs.item.group.rawValue < rhs.item.group.rawValue }
            return lhs.order < rhs.order
        }
        return scored.prefix(limit).map(\.item)
    }

    /// Kleinschreibung und ohne Akzente, damit "muller" auch "Müller" findet.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .trimmingCharacters(in: .whitespaces)
    }
}
