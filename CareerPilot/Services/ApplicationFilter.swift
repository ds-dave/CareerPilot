import Foundation

/// Ein Filter über Bewerbungen. Innerhalb einer Kategorie reicht ein Treffer ("Hoch oder Mittel"),
/// zwischen den Kategorien müssen alle passen ("Hoch und Remote").
struct ApplicationFilter: Codable, Equatable, Sendable {
    var priorities: Set<Priority> = []
    var workModels: Set<WorkModel> = []
    var sources: Set<ApplicationSource> = []
    var statuses: Set<ApplicationStatus> = []
    var tags: Set<String> = []
    var search: String = ""

    var isEmpty: Bool {
        priorities.isEmpty && workModels.isEmpty && sources.isEmpty
            && statuses.isEmpty && tags.isEmpty && search.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Anzahl aktiver Einschränkungen, für das Zählzeichen am Filterknopf.
    var activeCount: Int {
        priorities.count + workModels.count + sources.count + statuses.count + tags.count
            + (search.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
    }

    func matches(_ application: JobApplication) -> Bool {
        if !priorities.isEmpty, !priorities.contains(application.priority) { return false }
        if !workModels.isEmpty {
            guard let model = application.workModel, workModels.contains(model) else { return false }
        }
        if !sources.isEmpty {
            guard let source = application.source, sources.contains(source) else { return false }
        }
        if !statuses.isEmpty, !statuses.contains(application.status) { return false }
        if !tags.isEmpty {
            guard tags.contains(where: { TagList.contains(application.tags, $0) }) else { return false }
        }
        return application.matches(search: search)
    }

    /// Legt `other` über diesen Filter: Kategorien, die dort gesetzt sind, ersetzen die hiesigen.
    func overlaid(with other: ApplicationFilter) -> ApplicationFilter {
        var result = self
        if !other.priorities.isEmpty { result.priorities = other.priorities }
        if !other.workModels.isEmpty { result.workModels = other.workModels }
        if !other.sources.isEmpty { result.sources = other.sources }
        if !other.statuses.isEmpty { result.statuses = other.statuses }
        if !other.tags.isEmpty { result.tags = other.tags }
        if !other.search.trimmingCharacters(in: .whitespaces).isEmpty { result.search = other.search }
        return result
    }
}

/// Ein benannter, gespeicherter Filter. Er erscheint in der Seitenleiste.
struct SavedFilter: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var filter: ApplicationFilter
}
