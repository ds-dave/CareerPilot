import SwiftData
import SwiftUI

/// "Heute": Was ist überfällig, was steht heute und in den nächsten Tagen an, wo wartest du auf Antwort.
struct AgendaView: View {
    @Environment(ReminderSettings.self) private var reminders

    let applications: [JobApplication]
    let onSelect: (JobApplication) -> Void
    let onOpen: (ApplicationEvent) -> Void

    private var agenda: Agenda {
        AgendaBuilder.build(
            applications: applications,
            waitingAfterDays: reminders.preferences.followUpDays
        )
    }

    var body: some View {
        let agenda = agenda
        if agenda.isEmpty {
            ContentUnavailableView(
                "Alles erledigt",
                systemImage: "checkmark.circle",
                description: Text("Heute ist nichts fällig, und es stehen keine Termine in den nächsten Tagen an.")
            )
        } else {
            List {
                if !agenda.overdue.isEmpty {
                    Section("Überfällig") {
                        ForEach(agenda.overdue) { application in
                            followUpRow(application, tint: .red)
                        }
                    }
                }
                if !agenda.followUpsToday.isEmpty || !agenda.eventsToday.isEmpty {
                    Section("Heute") {
                        ForEach(agenda.eventsToday) { event in
                            eventRow(event, showDay: false)
                        }
                        ForEach(agenda.followUpsToday) { application in
                            followUpRow(application, tint: .primary)
                        }
                    }
                }
                if !agenda.upcomingEvents.isEmpty || !agenda.upcomingFollowUps.isEmpty {
                    Section("Nächste 7 Tage") {
                        ForEach(agenda.upcomingEvents) { event in
                            eventRow(event, showDay: true)
                        }
                        ForEach(agenda.upcomingFollowUps) { application in
                            followUpRow(application, tint: .primary)
                        }
                    }
                }
                if !agenda.waiting.isEmpty {
                    Section("Keine Antwort seit \(reminders.preferences.followUpDays)+ Tagen") {
                        ForEach(agenda.waiting) { application in
                            waitingRow(application)
                        }
                    }
                }
            }
        }
    }

    // MARK: Zeilen

    private func followUpRow(_ application: JobApplication, tint: Color) -> some View {
        Button {
            onSelect(application)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell")
                    .foregroundStyle(tint == .red ? Color.red : Color.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.displayCompany).font(.headline)
                    Text(application.position).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    StatusBadge(status: application.status)
                    if let due = application.followUpOn {
                        Text("Nachfassen \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(tint == .red ? Color.red : Color.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func eventRow(_ event: ApplicationEvent, showDay: Bool) -> some View {
        Button {
            onOpen(event)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: event.kind.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.displayTitle) · \(event.application?.displayCompany ?? "")").font(.headline)
                    if !event.location.isEmpty {
                        Text(event.location).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(
                    showDay
                        ? event.start.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute())
                        : event.start.formatted(date: .omitted, time: .shortened)
                )
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func waitingRow(_ application: JobApplication) -> some View {
        Button {
            onSelect(application)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.displayCompany).font(.headline)
                    Text(application.position).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let days = application.daysSinceApplied() {
                    Text("\(days) Tage")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
