import Foundation
import Observation
import SwiftUI

/// Persönliche Einstellungen für die Board-Spalten: Reihenfolge, Beschriftung, Sichtbarkeit.
/// Der Status selbst bleibt ein fester Schlüssel, nur die Darstellung ist anpassbar.
@MainActor
@Observable
final class ColumnSettings {
    private struct Stored: Codable {
        var order: [String]
        var hidden: [String]
        var labels: [String: String]
    }

    private(set) var order: [ApplicationStatus]
    private(set) var hidden: Set<ApplicationStatus>
    private(set) var labels: [ApplicationStatus: String]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(defaults: UserDefaults = .standard, key: String = "columnSettings.v1") {
        self.defaults = defaults
        self.key = key
        let stored = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        let savedOrder = (stored?.order ?? []).compactMap(ApplicationStatus.init(rawValue:))
        // Neue Status, die es beim Speichern noch nicht gab, hängen hinten an.
        self.order = savedOrder + ApplicationStatus.allCases.filter { !savedOrder.contains($0) }
        self.hidden = Set((stored?.hidden ?? []).compactMap(ApplicationStatus.init(rawValue:)))
        self.labels = Dictionary(
            uniqueKeysWithValues: (stored?.labels ?? [:]).compactMap { raw, label in
                ApplicationStatus(rawValue: raw).map { ($0, label) }
            }
        )
    }

    /// Angezeigte Beschriftung: eigene, sonst die Standardbeschriftung.
    func title(for status: ApplicationStatus) -> String {
        labels[status] ?? status.title
    }

    func isHidden(_ status: ApplicationStatus) -> Bool {
        hidden.contains(status)
    }

    /// Sichtbare Spalten in der gewählten Reihenfolge.
    var visibleStatuses: [ApplicationStatus] {
        order.filter { !hidden.contains($0) }
    }

    func rename(_ status: ApplicationStatus, to label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == status.title {
            labels[status] = nil
        } else {
            labels[status] = String(trimmed.prefix(40))
        }
        save()
    }

    func setHidden(_ isHidden: Bool, for status: ApplicationStatus) {
        // Mindestens eine Spalte bleibt sichtbar, sonst wäre das Board leer.
        if isHidden, visibleStatuses.count <= 1, !hidden.contains(status) { return }
        if isHidden { hidden.insert(status) } else { hidden.remove(status) }
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var updated = order
        updated.move(fromOffsets: source, toOffset: destination)
        order = updated
        save()
    }

    func reset() {
        order = ApplicationStatus.allCases
        hidden = []
        labels = [:]
        defaults.removeObject(forKey: key)
    }

    private func save() {
        let stored = Stored(
            order: order.map(\.rawValue),
            hidden: hidden.map(\.rawValue),
            labels: Dictionary(uniqueKeysWithValues: labels.map { ($0.key.rawValue, $0.value) })
        )
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: key)
        }
    }
}
