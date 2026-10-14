import SwiftData
import SwiftUI

struct ContactEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var contact: ContactPerson
    let isNew: Bool

    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isNew ? "Neue Kontaktperson" : "Kontaktperson")
                .font(.system(size: 22, weight: .heavy))
                .tracking(-0.6)

            Form {
                TextField("Name", text: $contact.name)
                    .focused($nameFocused)
                TextField("Rolle", text: $contact.role, prompt: Text("z. B. Recruiterin, Teamleiter"))
                TextField("E-Mail", text: $contact.email)
                TextField("Telefon", text: $contact.phone)
            }
            .formStyle(.columns)

            HStack {
                if !isNew {
                    Button("Löschen", role: .destructive) {
                        modelContext.delete(contact)
                        dismiss()
                    }
                }
                Spacer()
                if isNew {
                    Button("Abbrechen", role: .cancel) {
                        modelContext.delete(contact)
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                Button("Fertig") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear { nameFocused = true }
    }
}
