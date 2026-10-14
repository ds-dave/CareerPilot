import SwiftUI

/// Datumsfeld, das auch "kein Datum" kann.
struct OptionalDateField: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
        LabeledContent(title) {
            if let current = date {
                HStack(spacing: 8) {
                    DatePicker(
                        title,
                        selection: Binding(get: { current }, set: { date = $0 }),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    Button("Entfernen", systemImage: "xmark.circle.fill") {
                        date = nil
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("\(title) entfernen")
                }
            } else {
                Button("Festlegen") {
                    date = Calendar.current.startOfDay(for: .now)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
