import SwiftData
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ColumnSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(ReminderSettings.self) private var reminders
    @Query private var allApplications: [JobApplication]
    @Bindable var application: JobApplication

    @State private var noteDraft = ""
    @State private var editingEvent: ApplicationEvent?
    @State private var editingContact: ContactPerson?
    @State private var editingContactIsNew = false
    @State private var editingEventIsNew = false
    @State private var isImportingDocument = false
    @State private var documentError: String?

    /// Tags, die es schon bei anderen Bewerbungen gibt.
    private var tagSuggestions: [String] {
        var seen: [String: String] = [:]
        for other in allApplications where other !== application {
            for tag in other.tags {
                seen[tag.lowercased()] = seen[tag.lowercased()] ?? tag
            }
        }
        return seen.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                header
            }

            Section("Stelle") {
                TextField("Ort", text: $application.location)
                Picker("Arbeitsmodell", selection: $application.workModel) {
                    Text("Keine Angabe").tag(WorkModel?.none)
                    ForEach(WorkModel.allCases) { model in
                        Text(model.title).tag(WorkModel?.some(model))
                    }
                }
            }

            postingSection

            Section("Bewerbung") {
                Picker(
                    "Status",
                    selection: Binding(
                        get: { application.status },
                        set: { BoardOrdering.move(application, to: $0, among: allApplications) }
                    )
                ) {
                    ForEach(settings.order) { status in
                        Text(settings.title(for: status)).tag(status)
                    }
                }
                Picker("Priorität", selection: $application.priority) {
                    ForEach(Priority.allCases) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
                OptionalDateField(title: "Beworben am", date: $application.appliedOn)
                OptionalDateField(title: "Nachfassen am", date: $application.followUpOn)
                if let suggestion = application.suggestedFollowUp(afterDays: reminders.preferences.followUpDays) {
                    Button {
                        application.followUpOn = suggestion
                    } label: {
                        Label(
                            "Vorschlag übernehmen: \(suggestion.formatted(date: .abbreviated, time: .omitted))",
                            systemImage: "lightbulb"
                        )
                    }
                    .help("\(reminders.preferences.followUpDays) Tage nach der Bewerbung, falls keine Antwort kommt")
                }
            }

            eventsSection
            contactsSection
            documentsSection

            Section("Tags") {
                TagEditor(tags: $application.tags, suggestions: tagSuggestions)
            }

            Section("Gehalt (€ pro Jahr)") {
                TextField("Von", value: $application.salaryMin, format: .number.grouping(.never))
                TextField("Bis", value: $application.salaryMax, format: .number.grouping(.never))
            }

            Section {
                MarkdownEditor(text: $application.notes)
            } header: {
                Text("Notizen")
            } footer: {
                Text("Markdown: # Überschrift, - Liste, - [ ] Aufgabe, > Zitat, **fett**, *kursiv*.")
            }

            timelineSection
        }
        .formStyle(.grouped)
        .sheet(item: $editingEvent) { event in
            EventEditorView(event: event, isNew: editingEventIsNew)
        }
        .sheet(item: $editingContact) { contact in
            ContactEditorSheet(contact: contact, isNew: editingContactIsNew)
        }
        .fileImporter(
            isPresented: $isImportingDocument,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                addDocuments(from: urls)
            }
        }
        .alert(
            "Dokument nicht hinzugefügt",
            isPresented: Binding(get: { documentError != nil }, set: { if !$0 { documentError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(documentError ?? "")
        }
    }

    // MARK: Dokumente

    private var documentsSection: some View {
        Section {
            ForEach(application.documents.sorted { $0.addedAt > $1.addedAt }) { document in
                DocumentRow(document: document) {
                    modelContext.delete(document)
                }
            }
            Button("Dokument hinzufügen …", systemImage: "paperclip") {
                isImportingDocument = true
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Dokumente")
        } footer: {
            Text("PDF-Dateien bis 20 MB. Du kannst sie auch hierher ziehen.")
        }
        .dropDestination(for: URL.self) { urls, _ in
            addDocuments(from: urls)
            return !urls.isEmpty
        }
    }

    /// Hängt mehrere Dateien an. Fehler werden gesammelt und einmal gemeldet.
    private func addDocuments(from urls: [URL]) {
        var problems: [String] = []
        for url in urls {
            do {
                let file = try DocumentImporter.load(url: url)
                try application.addDocument(data: file.data, fileName: file.fileName)
            } catch {
                problems.append(error.localizedDescription)
            }
        }
        if !problems.isEmpty {
            documentError = problems.joined(separator: "\n")
        }
    }

    // MARK: Termine und Kontakte

    private var eventsSection: some View {
        Section("Termine") {
            ForEach(application.events.sorted { $0.start < $1.start }) { event in
                Button {
                    editingEventIsNew = false
                    editingEvent = event
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: event.kind.systemImage)
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.displayTitle)
                            Text(event.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let progress = event.checklistProgress {
                            Text("\(progress.done)/\(progress.total)")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .help("Vorbereitung")
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button("Termin hinzufügen", systemImage: "plus") {
                let event = ApplicationEvent(kind: .interview, start: Self.nextFullHour())
                event.application = application
                modelContext.insert(event)
                editingEventIsNew = true
                editingEvent = event
            }
            .buttonStyle(.borderless)
        }
    }

    private var contactsSection: some View {
        Section("Kontakte") {
            ForEach(application.contacts) { contact in
                HStack {
                    Button {
                        editingContactIsNew = false
                        editingContact = contact
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.displayName)
                            if !contact.role.isEmpty {
                                Text(contact.role)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if let mail = contact.mailURL {
                        Link(destination: mail) { Image(systemName: "envelope") }
                            .help(contact.email)
                    }
                    if let phone = contact.phoneURL {
                        Link(destination: phone) { Image(systemName: "phone") }
                            .help(contact.phone)
                    }
                }
            }
            Button("Kontakt hinzufügen", systemImage: "plus") {
                let contact = ContactPerson()
                contact.application = application
                modelContext.insert(contact)
                editingContactIsNew = true
                editingContact = contact
            }
            .buttonStyle(.borderless)
        }
    }

    private static func nextFullHour(from date: Date = .now, calendar: Calendar = .current) -> Date {
        let hour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: hour) ?? date
    }

    // MARK: Kopf

    /// Logo, Firmenname und Position wie der Seitenkopf in Notion.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            LogoWell(application: application, size: 64)

            TextField("Firma", text: $application.company, prompt: Text("Firma"), axis: .vertical)
                .labelsHidden()
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.8)
                .lineLimit(1...3)

            TextField("Position", text: $application.position, prompt: Text("Position"), axis: .vertical)
                .labelsHidden()
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1...3)
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
    }

    // MARK: Stellenanzeige

    private var postingSection: some View {
        Section("Stellenanzeige") {
            Picker("Onlineportal", selection: $application.source) {
                Text("Keine Angabe").tag(ApplicationSource?.none)
                ForEach(ApplicationSource.allCases) { source in
                    Text(source.title).tag(ApplicationSource?.some(source))
                }
            }
            if application.source == .other {
                TextField("Name des Portals", text: $application.sourceName)
            }

            HStack(spacing: 8) {
                TextField("Link", text: $application.jobURLString, prompt: Text("Link der Stellenanzeige einfügen"))
                    .onSubmit { application.detectSourceFromLink() }
                Button("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard", action: pasteLink)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Link aus der Zwischenablage einfügen")
                Button("Anzeige öffnen", systemImage: "arrow.up.right.square") {
                    if let url = application.jobURL { openURL(url) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(application.jobURL == nil)
                .help("Anzeige im Browser öffnen")
            }

            if let url = application.jobURL {
                Link(destination: url) {
                    Label(url.host() ?? url.absoluteString, systemImage: "link")
                }
            } else if !application.jobURLString.trimmingCharacters(in: .whitespaces).isEmpty {
                Label("Das sieht noch nicht wie ein Link aus.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: application.jobURLString) {
            application.detectSourceFromLink()
        }
    }

    private func pasteLink() {
        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
        else { return }
        application.jobURLString = text
    }

    // MARK: Verlauf

    private var timelineSection: some View {
        Section("Verlauf") {
            HStack {
                TextField("Notiz zum Verlauf hinzufügen", text: $noteDraft)
                    .onSubmit(addNote)
                Button("Hinzufügen", action: addNote)
                    .disabled(noteDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ForEach(application.timeline.sorted { $0.date > $1.date }) { entry in
                TimelineRow(entry: entry)
                    .contextMenu {
                        if entry.kind == .note {
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                application.timeline.removeAll { $0 === entry }
                            }
                        }
                    }
            }

            LabeledContent {
                Text(application.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            } label: {
                Label("Angelegt", systemImage: "plus.circle")
            }
        }
    }

    private func addNote() {
        let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        application.timeline.append(TimelineEntry(kind: .note, text: text))
        noteDraft = ""
    }
}

private struct TimelineRow: View {
    @Environment(ColumnSettings.self) private var settings
    let entry: TimelineEntry

    var body: some View {
        LabeledContent {
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.secondary)
        } label: {
            switch entry.kind {
            case .statusChanged:
                Label {
                    if let from = entry.fromStatus, let to = entry.toStatus {
                        Text("\(settings.title(for: from)) → \(settings.title(for: to))")
                    } else {
                        Text("Status geändert")
                    }
                } icon: {
                    Image(systemName: "arrow.right.circle")
                }
            case .note:
                Label(entry.text, systemImage: "text.bubble")
            }
        }
    }
}

private struct DocumentRow: View {
    @Bindable var document: ApplicationDocument
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: document.kind.systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            Button {
                DocumentOpener.open(document)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.fileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("\(document.kind.title) · \(document.formattedSize) · \(document.addedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Öffnen")

            Menu {
                Button("Öffnen", systemImage: "arrow.up.right.square") {
                    DocumentOpener.open(document)
                }
                Button("Sichern unter …", systemImage: "square.and.arrow.down") {
                    DocumentOpener.saveCopy(of: document)
                }
                Picker("Art", selection: $document.kind) {
                    ForEach(DocumentKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                Divider()
                Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
