import SwiftData
import SwiftUI

@main
struct CareerPilotApp: App {
    /// Unter Tests läuft die App mit einem Speicher im Arbeitsspeicher und ohne Systembenachrichtigungen,
    /// damit keine echten Daten berührt und keine Abfragen ausgelöst werden.
    private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// Entwicklungshilfe: `--args -inMemoryStore YES` startet mit einem leeren Speicher im Arbeitsspeicher,
    /// damit sich die App ausprobieren lässt, ohne echte Daten zu berühren.
    static var usesTemporaryStore: Bool {
        #if DEBUG
        isRunningTests || isPreviewBuild || UserDefaults.standard.bool(forKey: "inMemoryStore")
        #else
        isRunningTests
        #endif
    }

    /// Separater Debug-Build für Präsentationen, ohne Zugriff auf den echten Datenspeicher.
    static var isPreviewBuild: Bool {
        #if DEBUG
        Bundle.main.bundleIdentifier == "app.careerpilot.preview"
        #else
        false
        #endif
    }

    @State private var columnSettings = ColumnSettings()
    @State private var reminderSettings = ReminderSettings()
    @State private var savedFilters = SavedFilterStore()
    @State private var scheduler = NotificationScheduler(isActive: !CareerPilotApp.usesTemporaryStore)

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(columnSettings)
                .environment(reminderSettings)
                .environment(savedFilters)
                .environment(scheduler)
        }
        .modelContainer(
            for: AppSchema.models,
            inMemory: Self.usesTemporaryStore,
            isUndoEnabled: true
        )
        .defaultSize(width: 1280, height: 780)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
                .environment(reminderSettings)
                .environment(scheduler)
        }
    }
}
