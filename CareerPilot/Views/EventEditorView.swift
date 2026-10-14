import SwiftData
import SwiftUI

/// Termin bearbeiten: Art, Zeit, Ort, Ansprechpartner, Vorbereitung, Fragen, Nachbereitung.
struct EventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderSettings.self) private var reminders

    @Bindable var event: ApplicationEvent
    let isNew: Bool

    @State private var newChecklistText = ""
    @State private var newQuestion = ""
    @State private var isExporting = false

    private static let leadOptions: [(minutes: Int, label: String)] = [
        (-1, "Keine Erinnerung"), (0, "Zum Beginn"), (15, "15 Minuten vorher"),
        (30, "30 Minuten vorher"), (60, "1 Stunde vorher"), (120, "2 Stunden vorher"),
        (1_440, "1 Tag vorher"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                basics
                contactSection
                checklistSection
                questionsSection
                Section("Nachbereitung") {
                    MarkdownEditor(text: $event.debrief, minHeight: 120)
                }
            }
            .formStyle(.grouped)
            Divider()
            footer
        }
        .frame(width: 560, height: 720)
        .fileExporter(
            isPresented: $isExporting,
            document: ICSDocument(
                text: ICSExporter.calendar(
                    events: [event], defaultLeadMinutes: reminders.preferences.eventLeadMinutes
                )
            ),
            contentType: .calendarEvent,
            defaultFilename: "\(event.displayTitle) \(event.application?.displayCompany ?? "")"
        ) { _ in }
    }

    // MARK: Teile

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isNew ? "Neuer Termin" : event.displayTitle)
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.6)
                if let application = event.application {
                    Text("\(application.displayCompany) · \(application.position)")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
    }

    private var basics: some View {
        Section("Termin") {
            Picker("Art", selection: $event.kind) {
                ForEach(EventKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                }
            }
            TextField("Titel", text: $event.title, prompt: Text(event.kind.title))
            DatePicker("Beginn", selection: $event.start)
            Picker("Dauer", selection: $event.durationMinutes) {
                ForEach([15, 30, 45, 60, 90, 120, 180, 240, 480], id: \.self) { minutes in
                    Text(durationLabel(minutes)).tag(minutes)
                }
                if ![15, 30, 45, 60, 90, 120, 180, 240, 480].contains(event.durationMinutes) {
                    Text(durationLabel(event.durationMinutes)).tag(event.durationMinutes)
                }
            }
            TextField("Ort", text: $event.location, prompt: Text("Adresse oder Raum"))
            HStack {
                TextField("Link", text: $event.meetingURLString, prompt: Text("Videolink einfügen"))
                if let url = event.meetingURL {
                    Link(destination: url) {
                        Image(systemName: "video")
                    }
                    .help("Link öffnen")
                }
            }
            Picker(
                "Erinnerung",
                selection: Binding(
                    get: { event.reminderLeadMinutes ?? Int.min },
                    set: { event.reminderLeadMinutes = $0 == Int.min ? nil : $0 }
                )
            ) {
                Text("Standard (\(leadLabel(reminders.preferences.eventLeadMinutes)))").tag(Int.min)
                ForEach(Self.leadOptions, id: \.minutes) { option in
                    Text(option.label).tag(option.minutes)
                }
            }
        }
    }

    @ViewBuilder
    private var contactSection: some View {
        if let application = event.application, !application.contacts.isEmpty {
            Section("Ansprechpartner") {
                Picker("Kontakt", selection: $event.contact) {
                    Text("Niemand").tag(ContactPerson?.none)
                    ForEach(application.contacts) { contact in
                        Text(contact.role.isEmpty ? contact.displayName : "\(contact.displayName) · \(contact.role)")
                            .tag(ContactPerson?.some(contact))
                    }
                }
            }
        }
    }

    private var checklistSection: some View {
        Section {
            ForEach($event.checklist) { $item in
                HStack {
                    Toggle("Erledigt", isOn: $item.isDone)
                        .labelsHidden()
                    TextField("Punkt", text: $item.text)
                        .strikethrough(item.isDone)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                    Button("Entfernen", systemImage: "minus.circle") {
                        event.checklist.removeAll { $0.id == item.id }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            TextField("Punkt hinzufügen", text: $newChecklistText)
                .onSubmit {
                    let text = newChecklistText.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    event.checklist.append(ChecklistItem(text: text))
                    newChecklistText = ""
                }
        } header: {
            HStack {
                Text("Vorbereitung")
                if let progress = event.checklistProgress {
                    Text("\(progress.done) von \(progress.total)")
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var questionsSection: some View {
        Section("Fragen an das Unternehmen") {
            ForEach(Array(event.questions.enumerated()), id: \.offset) { index, question in
                HStack {
                    Text(question)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Entfernen", systemImage: "minus.circle") {
                        event.questions.remove(at: index)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            TextField("Frage hinzufügen", text: $newQuestion)
                .onSubmit {
                    let text = newQuestion.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    event.questions.append(text)
                    newQuestion = ""
                }
        }
    }

    private var footer: some View {
        HStack {
            if !isNew {
                Button("Termin löschen", role: .destructive) {
                    modelContext.delete(event)
                    dismiss()
                }
            }
            Button("Als .ics exportieren …", systemImage: "square.and.arrow.up") {
                isExporting = true
            }
            Spacer()
            if isNew {
                Button("Abbrechen", role: .cancel) {
                    modelContext.delete(event)
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            Button(isNew ? "Anlegen" : "Fertig") {
                if isNew, let application = event.application {
                    let when = event.start.formatted(date: .abbreviated, time: .shortened)
                    application.timeline.append(
                        TimelineEntry(kind: .note, text: "\(event.displayTitle) vereinbart für \(when)")
                    )
                }
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    // MARK: Hilfen

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) Minuten" }
        let hours = minutes / 60
        let rest = minutes % 60
        if rest == 0 { return hours == 1 ? "1 Stunde" : "\(hours) Stunden" }
        return "\(hours) Std. \(rest) Min."
    }

    private func leadLabel(_ minutes: Int) -> String {
        Self.leadOptions.first { $0.minutes == minutes }?.label ?? "\(minutes) Minuten vorher"
    }
}
