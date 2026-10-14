import SwiftData
import SwiftUI

/// "Termine": Monatsansicht oder Liste, dazu Export als `.ics`.
struct EventsView: View {
    @Environment(ReminderSettings.self) private var reminders

    enum Mode: String, CaseIterable, Identifiable {
        case month, list
        var id: String { rawValue }
        var title: String { self == .month ? "Monat" : "Liste" }
        var systemImage: String { self == .month ? "calendar" : "list.bullet" }
    }

    let applications: [JobApplication]
    let onOpenEvent: (ApplicationEvent) -> Void
    let onSelect: (JobApplication) -> Void

    @AppStorage("eventsMode") private var mode: Mode = .month
    @State private var month = Date.now
    @State private var showsPast = false
    @State private var isExporting = false

    private var active: [JobApplication] {
        applications.filter { !$0.isArchived }
    }

    private var events: [ApplicationEvent] {
        active.flatMap(\.events)
    }

    private var followUps: [JobApplication] {
        active.filter { $0.followUpOn != nil && !$0.status.isFinished }
    }

    private var icsText: String {
        ICSExporter.calendar(
            events: events,
            followUps: followUps,
            defaultLeadMinutes: reminders.preferences.eventLeadMinutes
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .padding(.top, 12)

            switch mode {
            case .month:
                MonthCalendarView(
                    events: events, followUps: followUps, month: $month,
                    onOpenEvent: onOpenEvent, onSelect: onSelect
                )
            case .list:
                listView
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Als .ics exportieren …", systemImage: "square.and.arrow.up") {
                    isExporting = true
                }
                .help("Alle Termine und Nachfass-Termine als Kalenderdatei exportieren")
                .disabled(events.isEmpty && followUps.isEmpty)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: ICSDocument(text: icsText),
            contentType: .calendarEvent,
            defaultFilename: "CareerPilot Termine"
        ) { _ in }
    }

    // MARK: Liste

    private var listView: some View {
        let now = Date.now
        let startOfToday = Calendar.current.startOfDay(for: now)
        let visible = events
            .filter { showsPast || $0.start >= startOfToday }
            .sorted { $0.start < $1.start }
        let byDay = Dictionary(grouping: visible) { Calendar.current.startOfDay(for: $0.start) }
        let days = byDay.keys.sorted()

        return Group {
            if visible.isEmpty {
                ContentUnavailableView(
                    "Keine Termine",
                    systemImage: "calendar.badge.plus",
                    description: Text("Termine legst du in der Bewerbung unter „Termine“ an.")
                )
            } else {
                List {
                    ForEach(days, id: \.self) { day in
                        Section(day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                            ForEach(byDay[day] ?? []) { event in
                                row(event)
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Toggle("Vergangene Termine zeigen", isOn: $showsPast)
                .toggleStyle(.checkbox)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ event: ApplicationEvent) -> some View {
        Button {
            onOpenEvent(event)
        } label: {
            HStack(spacing: 12) {
                Text(event.start.formatted(date: .omitted, time: .shortened))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .leading)
                    .foregroundStyle(.secondary)
                Image(systemName: event.kind.systemImage)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.displayTitle) · \(event.application?.displayCompany ?? "")")
                        .font(.headline)
                    let detail = [event.application?.position, event.location].compactMap { $0 }.filter { !$0.isEmpty }
                    if !detail.isEmpty {
                        Text(detail.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if event.meetingURL != nil {
                    Image(systemName: "video").foregroundStyle(.secondary)
                }
                if let progress = event.checklistProgress {
                    Text("\(progress.done)/\(progress.total)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
