import SwiftData
import SwiftUI

struct NewApplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ColumnSettings.self) private var settings
    @Query private var allApplications: [JobApplication]

    /// Status, in dem die Karte starten soll (z. B. wenn im Board eine Spalte gewählt war).
    var initialStatus: ApplicationStatus = .wishlist
    /// Wird mit der angelegten Bewerbung aufgerufen, damit sie danach ausgewählt werden kann.
    let onCreate: (JobApplication) -> Void

    @State private var company = ""
    @State private var position = ""
    @State private var status = ApplicationStatus.wishlist
    @FocusState private var focusedField: Field?

    private enum Field {
        case company, position
    }

    private var canCreate: Bool {
        !company.trimmingCharacters(in: .whitespaces).isEmpty
            && !position.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Neue Bewerbung")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.8)
                Text("Alles Weitere trägst du danach in Ruhe nach.")
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField("Firma", text: $company)
                    .focused($focusedField, equals: .company)
                    .onSubmit { focusedField = .position }
                TextField("Position", text: $position)
                    .focused($focusedField, equals: .position)
                    .onSubmit(create)
                Picker("Status", selection: $status) {
                    ForEach(settings.order) { status in
                        Text(settings.title(for: status)).tag(status)
                    }
                }
            }
            .formStyle(.columns)

            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Anlegen", action: create)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreate)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            status = initialStatus
            focusedField = .company
        }
    }

    private func create() {
        guard canCreate else { return }
        let application = JobApplication(
            company: company.trimmingCharacters(in: .whitespaces),
            position: position.trimmingCharacters(in: .whitespaces),
            status: status
        )
        if status.isSubmitted {
            application.appliedOn = Calendar.current.startOfDay(for: .now)
        }
        // Neue Karten landen am Ende ihrer Spalte.
        let last = BoardOrdering.column(status, in: allApplications).last?.sortIndex ?? -1
        application.sortIndex = last + 1
        modelContext.insert(application)
        onCreate(application)
        dismiss()
    }
}
