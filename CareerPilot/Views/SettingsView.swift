import SwiftUI

struct SettingsView: View {
    @Environment(ReminderSettings.self) private var reminders
    @Environment(NotificationScheduler.self) private var scheduler
    @AppStorage(SplashGate.preferenceKey) private var showsSplash = true

    var body: some View {
        @Bindable var reminders = reminders

        Form {
            Section("Allgemein") {
                Toggle("Logo-Animation beim Start zeigen", isOn: $showsSplash)
            }

            Section {
                Toggle("Erinnerungen aktivieren", isOn: $reminders.preferences.isEnabled)
                    .onChange(of: reminders.preferences.isEnabled) { _, isEnabled in
                        if isEnabled {
                            Task { await scheduler.requestAuthorization() }
                        }
                    }

                if reminders.preferences.isEnabled {
                    authorizationNote

                    Picker("Uhrzeit für Nachfassen", selection: $reminders.preferences.hour) {
                        ForEach(6..<22, id: \.self) { hour in
                            Text(String(format: "%02d:00 Uhr", hour)).tag(hour)
                        }
                    }
                    Toggle("Bei Nachfass-Terminen erinnern", isOn: $reminders.preferences.notifyFollowUps)
                    Toggle("Tägliche Zusammenfassung am Morgen", isOn: $reminders.preferences.dailyDigest)
                    Picker("Vor Terminen erinnern", selection: $reminders.preferences.eventLeadMinutes) {
                        Text("Nicht erinnern").tag(-1)
                        Text("Zum Beginn").tag(0)
                        Text("15 Minuten vorher").tag(15)
                        Text("30 Minuten vorher").tag(30)
                        Text("1 Stunde vorher").tag(60)
                        Text("2 Stunden vorher").tag(120)
                        Text("1 Tag vorher").tag(1_440)
                    }
                }
            } header: {
                Text("Benachrichtigungen")
            } footer: {
                Text("Die Benachrichtigungen entstehen lokal auf deinem Mac. Es wird nichts an einen Server gesendet.")
            }

            Section {
                Stepper(
                    "Nachfassen vorschlagen nach \(reminders.preferences.followUpDays) Tagen",
                    value: $reminders.preferences.followUpDays,
                    in: 2...60
                )
            } header: {
                Text("Nachfassen")
            } footer: {
                Text("Hat sich nach so vielen Tagen niemand gemeldet, schlägt CareerPilot ein Nachfass-Datum vor.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .task { await scheduler.refreshAuthorization() }
    }

    @ViewBuilder
    private var authorizationNote: some View {
        switch scheduler.authorization {
        case .denied:
            Label(
                "Benachrichtigungen sind für CareerPilot in den Systemeinstellungen ausgeschaltet.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.callout)
            .foregroundStyle(.orange)
        case .notDetermined:
            Label("macOS fragt beim Aktivieren nach der Erlaubnis.", systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .authorized, .unknown:
            EmptyView()
        }
    }
}
