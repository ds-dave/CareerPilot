import SwiftData
import SwiftUI

struct ApplicationListView: View {
    @Environment(\.modelContext) private var modelContext

    let applications: [JobApplication]
    let allCount: Int
    @Binding var selection: PersistentIdentifier?
    let searchText: String
    let onNew: () -> Void
    let onDelete: (JobApplication) -> Void
    var onAction: (String) -> Void = { _ in }

    var body: some View {
        if applications.isEmpty {
            emptyState
        } else {
            List(selection: $selection) {
                ForEach(applications) { application in
                    ApplicationRow(application: application)
                        .tag(application.persistentModelID)
                        .contextMenu { contextMenu(for: application) }
                }
            }
            .onDeleteCommand {
                guard let selection,
                      let application = applications.first(where: { $0.persistentModelID == selection })
                else { return }
                onDelete(application)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if allCount == 0 {
            ContentUnavailableView {
                Label("Noch keine Bewerbung", systemImage: "tray")
            } description: {
                Text("Leg die erste an.")
            } actions: {
                Button("Neue Bewerbung", action: onNew)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView(
                "Nichts hier",
                systemImage: "line.3.horizontal.decrease",
                description: Text("In dieser Ansicht gibt es gerade keine Bewerbung.")
            )
        }
    }

    @ViewBuilder
    private func contextMenu(for application: JobApplication) -> some View {
        Button("Duplizieren", systemImage: "plus.square.on.square") {
            let copy = application.duplicated()
            modelContext.insert(copy)
            selection = copy.persistentModelID
            onAction("„\(application.displayCompany)“ dupliziert")
        }
        Button(
            application.isArchived ? "Aus Archiv holen" : "Archivieren",
            systemImage: application.isArchived ? "tray.and.arrow.up" : "archivebox"
        ) {
            application.isArchived.toggle()
            onAction("„\(application.displayCompany)“ \(application.isArchived ? "archiviert" : "aus dem Archiv geholt")")
        }
        Divider()
        Button("Löschen", systemImage: "trash", role: .destructive) {
            onDelete(application)
        }
    }
}
