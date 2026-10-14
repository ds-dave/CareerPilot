import SwiftUI

extension FocusedValues {
    /// Schalter des Fensters, das gerade vorne ist: öffnet das Blatt "Neue Bewerbung".
    @Entry var isPresentingNewApplication: Binding<Bool>?

    /// Lädt erfundene Beispieldaten in das vordere Fenster.
    @Entry var loadSampleData: (@MainActor () -> Void)?

    /// Setzt das Bild aus der Zwischenablage als Logo der ausgewählten Bewerbung.
    @Entry var pasteLogo: (@MainActor () -> Void)?

    /// Schalter der Befehlspalette im vorderen Fenster.
    @Entry var isShowingCommandPalette: Binding<Bool>?

    /// Export- und Importaktionen des vorderen Fensters.
    @Entry var dataAction: (@MainActor (DataAction) -> Void)?

    /// Verschiebt die ausgewählte Bewerbung um n Spalten (negativ = nach links).
    @Entry var moveSelectedStatus: (@MainActor (Int) -> Void)?
}

/// Aktionen für Export und Import.
enum DataAction {
    case exportCSV
    case exportBackup
    case exportBackupWithoutDocuments
    case importBackup
}

struct AppCommands: Commands {
    @AppStorage("viewMode") private var viewMode: ViewMode = .board
    @FocusedBinding(\.isPresentingNewApplication) private var isPresentingNewApplication
    @FocusedValue(\.loadSampleData) private var loadSampleData
    @FocusedValue(\.dataAction) private var dataAction
    @FocusedValue(\.pasteLogo) private var pasteLogo
    @FocusedBinding(\.isShowingCommandPalette) private var isShowingCommandPalette
    @FocusedValue(\.moveSelectedStatus) private var moveSelectedStatus

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Neue Bewerbung") {
                isPresentingNewApplication = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(isPresentingNewApplication == nil)

            Divider()

            Menu("Exportieren") {
                Button("Bewerbungen als CSV …") { dataAction?(.exportCSV) }
                Button("Backup als JSON …") { dataAction?(.exportBackup) }
                Button("Backup ohne Dokumente …") { dataAction?(.exportBackupWithoutDocuments) }
            }
            .disabled(dataAction == nil)

            Button("Backup importieren …") { dataAction?(.importBackup) }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(dataAction == nil)
        }

        CommandMenu("Bewerbung") {
            Button("Logo aus Zwischenablage einfügen") {
                pasteLogo?()
            }
            .keyboardShortcut("v", modifiers: [.command, .option])
            .disabled(pasteLogo == nil)

            Divider()

            Button("Status weiter") {
                moveSelectedStatus?(1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            .disabled(moveSelectedStatus == nil)

            Button("Status zurück") {
                moveSelectedStatus?(-1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            .disabled(moveSelectedStatus == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Befehlspalette …") {
                isShowingCommandPalette = true
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(isShowingCommandPalette == nil)

            Divider()

            Button("Als Board anzeigen") { viewMode = .board }
                .keyboardShortcut("1", modifiers: .command)
            Button("Als Liste anzeigen") { viewMode = .list }
                .keyboardShortcut("2", modifiers: .command)
        }

        CommandMenu("Daten") {
            Button("Beispieldaten laden") {
                loadSampleData?()
            }
            .disabled(loadSampleData == nil)
        }
    }
}
