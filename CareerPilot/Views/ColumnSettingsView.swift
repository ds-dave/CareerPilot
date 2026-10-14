import SwiftUI

/// Spalten umbenennen, umsortieren und ausblenden.
struct ColumnSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColumnSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spalten anpassen")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.6)
                Text("Ziehen zum Umsortieren, Namen direkt ändern, Haken zum Ein- und Ausblenden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(settings.order) { status in
                    ColumnSettingsRow(status: status)
                }
                .onMove { source, destination in
                    settings.move(fromOffsets: source, toOffset: destination)
                }
            }
            .frame(minHeight: 320)

            HStack {
                Button("Zurücksetzen", role: .destructive) {
                    settings.reset()
                }
                Spacer()
                Button("Fertig") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

private struct ColumnSettingsRow: View {
    @Environment(ColumnSettings.self) private var settings
    let status: ApplicationStatus
    @State private var title = ""

    var body: some View {
        HStack(spacing: 10) {
            Toggle(
                "Sichtbar",
                isOn: Binding(
                    get: { !settings.isHidden(status) },
                    set: { settings.setHidden(!$0, for: status) }
                )
            )
            .labelsHidden()

            TextField(status.title, text: $title)
                .textFieldStyle(.plain)
                .onSubmit { settings.rename(status, to: title) }
                .onChange(of: title) { _, newValue in
                    settings.rename(status, to: newValue)
                }
                .foregroundStyle(settings.isHidden(status) ? .secondary : .primary)
        }
        .padding(.vertical, 2)
        .onAppear { title = settings.labels[status] ?? status.title }
    }
}
