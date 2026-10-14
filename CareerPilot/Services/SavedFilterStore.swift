import Foundation
import Observation

/// Verwaltet die gespeicherten Filter und legt sie in den Benutzereinstellungen ab.
@MainActor
@Observable
final class SavedFilterStore {
    private(set) var filters: [SavedFilter]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(defaults: UserDefaults = .standard, key: String = "savedFilters.v1") {
        self.defaults = defaults
        self.key = key
        self.filters = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([SavedFilter].self, from: $0) } ?? []
    }

    func filter(withID id: UUID) -> SavedFilter? {
        filters.first { $0.id == id }
    }

    /// Speichert einen Filter. Leere Namen und leere Filter werden abgelehnt (Rückgabe `nil`).
    @discardableResult
    func add(name: String, filter: ApplicationFilter) -> SavedFilter? {
        let trimmed = String(name.trimmingCharacters(in: .whitespaces).prefix(40))
        guard !trimmed.isEmpty, !filter.isEmpty else { return nil }
        let saved = SavedFilter(name: trimmed, filter: filter)
        filters.append(saved)
        save()
        return saved
    }

    func rename(id: UUID, to name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespaces).prefix(40))
        guard !trimmed.isEmpty, let index = filters.firstIndex(where: { $0.id == id }) else { return }
        filters[index].name = trimmed
        save()
    }

    func remove(id: UUID) {
        filters.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(filters) {
            defaults.set(data, forKey: key)
        }
    }
}
