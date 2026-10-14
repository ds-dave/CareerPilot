import Foundation
import Observation

/// Was und wann die App erinnern soll.
struct ReminderPreferences: Equatable, Sendable {
    var isEnabled = false
    /// Uhrzeit (volle Stunde) für Nachfass-Erinnerungen und die Zusammenfassung.
    var hour = 9
    /// Nach so vielen Tagen ohne Antwort schlägt die App das Nachfassen vor.
    var followUpDays = 7
    /// Minuten vor einem Termin; negativ heißt keine Erinnerung.
    var eventLeadMinutes = 60
    var notifyFollowUps = true
    var dailyDigest = false
}

@MainActor
@Observable
final class ReminderSettings {
    var preferences: ReminderPreferences {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(defaults: UserDefaults = .standard, key: String = "reminderSettings.v1") {
        self.defaults = defaults
        self.key = key
        var loaded = ReminderPreferences()
        if let dictionary = defaults.dictionary(forKey: key) {
            loaded.isEnabled = dictionary["isEnabled"] as? Bool ?? loaded.isEnabled
            loaded.hour = dictionary["hour"] as? Int ?? loaded.hour
            loaded.followUpDays = dictionary["followUpDays"] as? Int ?? loaded.followUpDays
            loaded.eventLeadMinutes = dictionary["eventLeadMinutes"] as? Int ?? loaded.eventLeadMinutes
            loaded.notifyFollowUps = dictionary["notifyFollowUps"] as? Bool ?? loaded.notifyFollowUps
            loaded.dailyDigest = dictionary["dailyDigest"] as? Bool ?? loaded.dailyDigest
        }
        loaded.hour = min(max(loaded.hour, 0), 23)
        loaded.followUpDays = min(max(loaded.followUpDays, 1), 90)
        self.preferences = loaded
    }

    private func save() {
        defaults.set(
            [
                "isEnabled": preferences.isEnabled,
                "hour": preferences.hour,
                "followUpDays": preferences.followUpDays,
                "eventLeadMinutes": preferences.eventLeadMinutes,
                "notifyFollowUps": preferences.notifyFollowUps,
                "dailyDigest": preferences.dailyDigest,
            ] as [String: Any],
            forKey: key
        )
    }
}
