import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ColumnSettings.self) private var settings
    @Environment(ReminderSettings.self) private var reminders
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(SavedFilterStore.self) private var savedFilters
    @Environment(\.openSettings) private var openSettings
    @Environment(\.undoManager) private var undoManager
    @Query(sort: \JobApplication.createdAt, order: .reverse) private var applications: [JobApplication]

    @AppStorage("viewMode") private var viewMode: ViewMode = .board
    @State private var sidebarItem: SidebarItem? = RootView.initialSidebarItem()
    @State private var selection: PersistentIdentifier?
    @State private var searchText = ""
    @State private var isPresentingNew = false
    @State private var isPresentingColumns = false
    @State private var isConfirmingDeleteAll = false
    @State private var isInspectorPresented = false
    @State private var editingEvent: ApplicationEvent?
    @State private var dataMessage: DataMessage?
    @State private var activeFilter = ApplicationFilter()
    @State private var isNamingFilter = false
    @State private var isShowingPalette = false
    @State private var newFilterName = ""
    @State private var undoNotice: UndoNotice?
    @State private var isShowingSplash = SplashGate.consume(
        isRunningTests: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    )

    /// Rückmeldung nach Export oder Import.
    private struct DataMessage: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    /// Kurzer Hinweis mit "Rückgängig" nach einer Aktion.
    private struct UndoNotice: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    private var currentItem: SidebarItem { sidebarItem ?? .all }

    private static func initialSidebarItem() -> SidebarItem {
        #if DEBUG
        // Entwicklungshilfe: `--args -startSection statistics` öffnet direkt eine Ansicht (agenda, calendar, statistics).
        switch UserDefaults.standard.string(forKey: "startSection") {
        case "agenda": return .agenda
        case "calendar": return .calendar
        case "statistics": return .statistics
        default: break
        }
        #endif
        return .all
    }

    /// Im Archiv gibt es keine Spalten, dort zeigt die App immer die Liste.
    private var effectiveMode: ViewMode {
        currentItem == .archive ? .list : viewMode
    }

    /// Geplante Benachrichtigungen; ändert sich nur, wenn sich Daten oder Einstellungen ändern.
    private var plannedNotifications: [PlannedNotification] {
        ReminderPlanner.plan(applications: applications, preferences: reminders.preferences)
    }

    /// Der Filter hinter der gewählten Ansicht: bei einer gespeicherten Ansicht deren Definition.
    private var viewFilter: ApplicationFilter {
        if case .savedFilter(let id) = currentItem, let saved = savedFilters.filter(withID: id) {
            return saved.filter
        }
        return ApplicationFilter()
    }

    private var filteredApplications: [JobApplication] {
        applications.filter { application in
            currentItem.includes(application)
                && viewFilter.matches(application)
                && activeFilter.matches(application)
                && application.matches(search: searchText)
        }
    }

    private var listApplications: [JobApplication] {
        var rank: [ApplicationStatus: Int] = [:]
        for (index, status) in settings.order.enumerated() {
            rank[status] = index
        }
        return filteredApplications.sorted { lhs, rhs in
            let leftRank = rank[lhs.status] ?? 0
            let rightRank = rank[rhs.status] ?? 0
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var selectedApplication: JobApplication? {
        guard let selection else { return nil }
        return applications.first { $0.persistentModelID == selection }
    }

    private var subtitle: String {
        switch currentItem {
        case .agenda:
            return Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        case .statistics:
            return "Bewerbungsphase im Überblick"
        case .calendar:
            let count = applications.filter { !$0.isArchived }.flatMap(\.events).count { $0.start >= .now }
            return count == 1 ? "1 anstehender Termin" : "\(count) anstehende Termine"
        default:
            break
        }
        let count = filteredApplications.count
        return count == 1 ? "1 Bewerbung" : "\(count) Bewerbungen"
    }

    var body: some View {
        splitView
            .sheet(isPresented: $isPresentingNew) {
                NewApplicationSheet(initialStatus: newApplicationStatus) { created in
                    if currentItem == .archive { sidebarItem = .all }
                    searchText = ""
                    selection = created.persistentModelID
                }
            }
            .sheet(isPresented: $isPresentingColumns) {
                ColumnSettingsView()
            }
            .sheet(item: $editingEvent) { event in
                EventEditorView(event: event, isNew: false)
            }
            .confirmationDialog(
                "Alle Daten löschen?",
                isPresented: $isConfirmingDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Alle Bewerbungen löschen", role: .destructive) {
                    let count = applications.count
                    selection = nil
                    try? modelContext.delete(model: JobApplication.self)
                    announce(count == 1 ? "Eine Bewerbung gelöscht" : "\(count) Bewerbungen gelöscht")
                }
            } message: {
                Text("Direkt danach kannst du das mit „Rückgängig“ zurücknehmen.")
            }
            .focusedSceneValue(\.isPresentingNewApplication, $isPresentingNew)
            .focusedSceneValue(\.loadSampleData, loadSampleAction)
            .focusedSceneValue(\.moveSelectedStatus, moveAction)
            .focusedSceneValue(\.dataAction, dataAction)
            .focusedSceneValue(\.isShowingCommandPalette, $isShowingPalette)
            .overlay { palette }
            .alert("Ansicht speichern", isPresented: $isNamingFilter) {
                TextField("Name", text: $newFilterName)
                Button("Speichern", action: saveCurrentFilter)
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die aktuellen Filter erscheinen dann in der Seitenleiste.")
            }
            .alert(item: $dataMessage) { message in
                Alert(title: Text(message.title), message: Text(message.text), dismissButton: .default(Text("OK")))
            }
            .frame(minWidth: 960, minHeight: 600)
            .toolbar(isShowingSplash ? .hidden : .automatic, for: .windowToolbar)
            .overlay {
                if isShowingSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            isShowingSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
            #if DEBUG
            .task {
                // Entwicklungshilfe: `open CareerPilot.app --args -loadSampleData YES` füllt einen leeren Speicher.
                if (CareerPilotApp.isPreviewBuild || UserDefaults.standard.bool(forKey: "loadSampleData")), applications.isEmpty {
                    SampleData.insert(into: modelContext)
                }
            }
            #endif
    }

    private var splitView: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarItem, applications: applications)
        } detail: {
            detailArea
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Firma, Position, Notiz, Tag")
        .toolbar { toolbarContent }
        .onChange(of: undoManager, initial: true) { _, manager in
            // SwiftData und die Fensterbefehle müssen denselben UndoManager verwenden.
            modelContext.undoManager = manager
        }
        .onChange(of: selection) { _, newValue in
            if newValue != nil { isInspectorPresented = true }
        }
        .task(id: plannedNotifications) {
            await scheduler.apply(plannedNotifications)
        }
        .onPasteCommand(of: [.image, .fileURL]) { _ in
            pasteLogoFromClipboard()
        }
        .focusedSceneValue(\.pasteLogo, pasteLogoAction)
        .overlay(alignment: .bottom) { undoToast }
    }

    // MARK: Rückgängig-Hinweis

    @ViewBuilder
    private var undoToast: some View {
        if let notice = undoNotice {
            UndoToast(
                message: notice.message,
                onUndo: {
                    undoManager?.undo()
                    withAnimation { undoNotice = nil }
                },
                onDismiss: { withAnimation { undoNotice = nil } }
            )
            .padding(.bottom, 22)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(notice.id)
        }
    }

    /// Zeigt den Hinweis für einige Sekunden. Eine neue Aktion ersetzt den alten Hinweis.
    private func announce(_ message: String) {
        let notice = UndoNotice(message: message)
        withAnimation(.easeOut(duration: 0.2)) { undoNotice = notice }
        Task {
            try? await Task.sleep(for: .seconds(7))
            if undoNotice == notice {
                withAnimation(.easeIn(duration: 0.25)) { undoNotice = nil }
            }
        }
    }

    // MARK: Logo

    private var pasteLogoAction: @MainActor () -> Void {
        { pasteLogoFromClipboard() }
    }

    /// Setzt das Bild aus der Zwischenablage als Logo der ausgewählten Bewerbung.
    private func pasteLogoFromClipboard() {
        guard let application = selectedApplication else {
            dataMessage = DataMessage(title: "Kein Logo gesetzt", text: "Wähle zuerst eine Bewerbung aus.")
            return
        }
        guard let data = LogoPasteboard.imageData() else {
            dataMessage = DataMessage(
                title: "Kein Bild in der Zwischenablage",
                text: "Mach einen Screenshot (⌃⇧⌘4) oder kopiere ein Bild, dann füge es mit ⌘V ein."
            )
            return
        }
        if application.setLogo(from: data) {
            announce("Logo für „\(application.displayCompany)“ gesetzt")
        } else {
            dataMessage = DataMessage(title: "Logo nicht gesetzt",
                                      text: "Das Bild konnte nicht gelesen werden oder ist zu groß.")
        }
    }

    private var detailArea: some View {
        mainArea
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if CareerPilotApp.isPreviewBuild {
                    Label("Demo · Fiktive Bewerbungen · Bewerbungsdaten nur im Arbeitsspeicher", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(.bar)
                }
            }
            .navigationTitle(currentItem.title(using: settings))
            .navigationSubtitle(subtitle)
            .inspector(isPresented: $isInspectorPresented) {
                inspectorContent
                    .inspectorColumnWidth(min: 340, ideal: 400, max: 560)
            }
    }

    private var dataAction: @MainActor (DataAction) -> Void {
        { action in perform(action) }
    }

    private var loadSampleAction: @MainActor () -> Void {
        { SampleData.insert(into: modelContext) }
    }

    private var moveAction: (@MainActor (Int) -> Void)? {
        guard selectedApplication != nil else { return nil }
        return { offset in moveSelected(by: offset) }
    }

    // MARK: Hauptbereich

    @ViewBuilder
    private var mainArea: some View {
        if currentItem == .agenda {
            AgendaView(
                applications: applications,
                onSelect: { selection = $0.persistentModelID },
                onOpen: open
            )
        } else if currentItem == .statistics {
            StatisticsView(applications: applications)
        } else if currentItem == .calendar {
            EventsView(
                applications: applications,
                onOpenEvent: open,
                onSelect: { selection = $0.persistentModelID }
            )
        } else if applications.isEmpty {
            ContentUnavailableView {
                Label("Noch keine Bewerbung", systemImage: "tray")
            } description: {
                Text("Leg die erste an.")
            } actions: {
                Button("Neue Bewerbung") { isPresentingNew = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 0) {
                FilterBar(filter: $activeFilter)
                if effectiveMode == .board {
                    if filteredApplications.isEmpty, !searchText.isEmpty || !activeFilter.isEmpty {
                        ContentUnavailableView(
                            "Keine Treffer",
                            systemImage: "line.3.horizontal.decrease",
                            description: Text("Für diese Suche und Filter gibt es keine Bewerbung.")
                        )
                    } else {
                        BoardView(
                            applications: filteredApplications,
                            allApplications: applications,
                            selection: $selection,
                            onDelete: delete,
                            onAction: announce
                        )
                    }
                } else {
                    ApplicationListView(
                        applications: listApplications,
                        allCount: applications.count,
                        selection: $selection,
                        searchText: searchText,
                        onNew: { isPresentingNew = true },
                        onDelete: delete,
                        onAction: announce
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let application = selectedApplication {
            ApplicationDetailView(application: application)
                .id(application.persistentModelID)
        } else {
            ContentUnavailableView(
                "Keine Bewerbung ausgewählt",
                systemImage: "briefcase",
                description: Text("Wähle eine Bewerbung aus.")
            )
        }
    }

    // MARK: Werkzeugleiste

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if currentItem.showsApplications {
                Picker("Ansicht", selection: $viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("Zwischen Board und Liste wechseln (⌘1, ⌘2)")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if currentItem.showsApplications {
                FilterMenu(
                    filter: $activeFilter,
                    canSave: !activeFilter.isEmpty || !searchText.trimmingCharacters(in: .whitespaces).isEmpty,
                    onSave: { newFilterName = ""; isNamingFilter = true }
                )
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if currentItem.showsApplications, effectiveMode == .board {
                Button("Spalten anpassen", systemImage: "slider.horizontal.3") {
                    isPresentingColumns = true
                }
                .help("Spalten umbenennen, sortieren und ausblenden")
            }
            Button("Neue Bewerbung", systemImage: "plus") {
                isPresentingNew = true
            }
            .help("Neue Bewerbung (⌘N)")
            Button("Details", systemImage: "sidebar.trailing") {
                isInspectorPresented.toggle()
            }
            .help("Details ein- oder ausblenden")
        }
        ToolbarItem(placement: .secondaryAction) {
            Menu("Mehr", systemImage: "ellipsis.circle") {
                Button("Beispieldaten laden") {
                    SampleData.insert(into: modelContext)
                }
                Divider()
                Button("Als CSV exportieren …", systemImage: "tablecells") { perform(.exportCSV) }
                    .disabled(applications.isEmpty)
                Button("Backup als JSON …", systemImage: "externaldrive") { perform(.exportBackup) }
                    .disabled(applications.isEmpty)
                Button("Backup importieren …", systemImage: "square.and.arrow.down") { perform(.importBackup) }
                Divider()
                Button("Alle Daten löschen …", role: .destructive) {
                    isConfirmingDeleteAll = true
                }
                .disabled(applications.isEmpty)
            }
        }
    }

    // MARK: Aktionen

    /// Im Board gewählter Statusfilter bestimmt, in welcher Spalte eine neue Karte startet.
    private var newApplicationStatus: ApplicationStatus {
        if case .status(let status) = currentItem { return status }
        return .wishlist
    }

    // MARK: Befehlspalette

    @ViewBuilder
    private var palette: some View {
        if isShowingPalette {
            ZStack(alignment: .top) {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { isShowingPalette = false }
                CommandPaletteView(
                    items: paletteItems,
                    onPerform: perform,
                    onClose: { isShowingPalette = false }
                )
                .padding(.top, 80)
            }
            .transition(.opacity)
        }
    }

    private var paletteItems: [PaletteItem] {
        var names: [String: String] = [:]
        for application in applications {
            for tag in application.tags where names[tag.lowercased()] == nil {
                names[tag.lowercased()] = tag
            }
        }
        return CommandPalette.items(
            applications: applications,
            savedFilters: savedFilters.filters,
            tags: names.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
            statusTitle: { settings.title(for: $0) },
            visibleStatuses: settings.visibleStatuses
        )
    }

    private func perform(_ action: PaletteAction) {
        switch action {
        case .newApplication:
            isPresentingNew = true
        case .show(let item):
            searchText = ""
            sidebarItem = item
        case .setViewMode(let mode):
            viewMode = mode
            if !currentItem.showsApplications { sidebarItem = .all }
        case .openApplication(let id):
            guard let application = applications.first(where: { $0.persistentModelID == id }) else { return }
            searchText = ""
            activeFilter = ApplicationFilter()
            if application.isArchived {
                sidebarItem = .archive
            } else if !currentItem.showsApplications || !currentItem.includes(application) {
                sidebarItem = .all
            }
            selection = id
        case .openEvent(let id):
            if let event = applications.flatMap(\.events).first(where: { $0.persistentModelID == id }) {
                open(event)
            }
        case .editColumns:
            if !currentItem.showsApplications { sidebarItem = .all }
            isPresentingColumns = true
        case .openSettings:
            openSettings()
        case .data(let dataAction):
            perform(dataAction)
        }
    }

    // MARK: Gespeicherte Ansichten

    /// Speichert die aktiven Filter samt Kontext der gewählten Seitenleisten-Ansicht.
    private func saveCurrentFilter() {
        var filter = viewFilter.overlaid(with: activeFilter)
        filter.search = searchText
        switch currentItem {
        case .status(let status) where filter.statuses.isEmpty:
            filter.statuses = [status]
        case .tag(let tag):
            filter.tags.insert(tag)
        default:
            break
        }
        if let saved = savedFilters.add(name: newFilterName, filter: filter) {
            activeFilter = ApplicationFilter()
            searchText = ""
            sidebarItem = .savedFilter(saved.id)
        }
    }

    // MARK: Export und Import

    private func perform(_ action: DataAction) {
        switch action {
        case .exportCSV:
            let csv = CSVExporter.make(applications: applications) { settings.title(for: $0) }
            if FilePanels.save(Data(csv.utf8), suggestedName: "CareerPilot Bewerbungen \(FilePanels.stamp()).csv",
                               type: .commaSeparatedText) {
                dataMessage = DataMessage(title: "Export fertig", text: "\(applications.count) Bewerbungen als CSV gespeichert.")
            }
        case .exportBackup, .exportBackupWithoutDocuments:
            let withDocuments = action == .exportBackup
            let file = BackupCodec.makeBackup(from: applications, includeDocuments: withDocuments)
            do {
                let data = try BackupCodec.encode(file)
                if FilePanels.save(data, suggestedName: "CareerPilot Backup \(FilePanels.stamp()).json", type: .json) {
                    dataMessage = DataMessage(title: "Backup fertig",
                                              text: "\(applications.count) Bewerbungen gesichert\(withDocuments ? " (mit Dokumenten)" : "").")
                }
            } catch {
                dataMessage = DataMessage(title: "Backup fehlgeschlagen", text: error.localizedDescription)
            }
        case .importBackup:
            guard let url = FilePanels.open(types: [.json]) else { return }
            importBackup(from: url)
        }
    }

    private func importBackup(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > BackupCodec.maxFileBytes {
                throw BackupError.unreadable
            }
            let data = try Data(contentsOf: url)
            let file = try BackupCodec.decode(data)
            let summary = BackupCodec.restore(file, into: modelContext, existing: Set(applications.map(\.uuid)))
            dataMessage = DataMessage(title: "Import abgeschlossen", text: summary.message)
        } catch {
            dataMessage = DataMessage(title: "Import nicht möglich", text: error.localizedDescription)
        }
    }

    /// Öffnet einen Termin: wählt die Bewerbung aus und zeigt den Editor.
    private func open(_ event: ApplicationEvent) {
        selection = event.application?.persistentModelID
        editingEvent = event
    }

    private func delete(_ application: JobApplication) {
        let name = application.displayCompany
        if selection == application.persistentModelID {
            selection = nil
        }
        modelContext.delete(application)
        announce("„\(name)“ gelöscht")
    }

    private func moveSelected(by offset: Int) {
        guard let application = selectedApplication,
              let target = BoardOrdering.status(
                offsetBy: offset, from: application.status, within: settings.visibleStatuses)
        else { return }
        BoardOrdering.move(application, to: target, among: applications)
        announce("„\(application.displayCompany)“ nach „\(settings.title(for: target))“ verschoben")
    }
}
