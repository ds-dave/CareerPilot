import SwiftUI

/// Zeigt die aktiven Filter als Pillen mit Entfernen-Knopf.
struct FilterBar: View {
    @Environment(ColumnSettings.self) private var settings
    @Binding var filter: ApplicationFilter

    var body: some View {
        if !filter.isEmpty {
            HStack(spacing: 8) {
                FlowLayout(spacing: 6) {
                    ForEach(Priority.allCases.filter(filter.priorities.contains)) { priority in
                        pill("Priorität: \(priority.title)") { filter.priorities.remove(priority) }
                    }
                    ForEach(WorkModel.allCases.filter(filter.workModels.contains)) { model in
                        pill(model.title) { filter.workModels.remove(model) }
                    }
                    ForEach(ApplicationSource.allCases.filter(filter.sources.contains)) { source in
                        pill(source.title) { filter.sources.remove(source) }
                    }
                    ForEach(ApplicationStatus.allCases.filter(filter.statuses.contains)) { status in
                        pill(settings.title(for: status)) { filter.statuses.remove(status) }
                    }
                    ForEach(filter.tags.sorted(), id: \.self) { tag in
                        pill("#\(tag)") { filter.tags.remove(tag) }
                    }
                }
                Spacer(minLength: 0)
                Button("Zurücksetzen") { filter = ApplicationFilter() }
                    .buttonStyle(.link)
                    .font(.callout)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func pill(_ title: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Button("Entfernen", systemImage: "xmark", action: remove)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.system(size: 9, weight: .bold))
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.primary.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Filter \(title)")
    }
}

/// Auswahlmenü für die Filter: Haken setzen, Haken entfernen.
struct FilterMenu: View {
    @Binding var filter: ApplicationFilter
    let canSave: Bool
    let onSave: () -> Void

    var body: some View {
        Menu {
            Menu("Priorität") {
                ForEach(Priority.allCases) { priority in
                    Toggle(priority.title, isOn: binding(for: priority, in: \.priorities))
                }
            }
            Menu("Arbeitsmodell") {
                ForEach(WorkModel.allCases) { model in
                    Toggle(model.title, isOn: binding(for: model, in: \.workModels))
                }
            }
            Menu("Onlineportal") {
                ForEach(ApplicationSource.allCases) { source in
                    Toggle(source.title, isOn: binding(for: source, in: \.sources))
                }
            }
            Divider()
            Button("Filter zurücksetzen") { filter = ApplicationFilter() }
                .disabled(filter.isEmpty)
            Button("Als Ansicht speichern …", systemImage: "plus.circle", action: onSave)
                .disabled(!canSave)
        } label: {
            Label(
                "Filter",
                systemImage: filter.isEmpty
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .help("Nach Priorität, Arbeitsmodell oder Onlineportal filtern")
    }

    private func binding<Value: Hashable>(
        for value: Value, in keyPath: WritableKeyPath<ApplicationFilter, Set<Value>>
    ) -> Binding<Bool> {
        Binding(
            get: { filter[keyPath: keyPath].contains(value) },
            set: { isOn in
                if isOn {
                    filter[keyPath: keyPath].insert(value)
                } else {
                    filter[keyPath: keyPath].remove(value)
                }
            }
        )
    }
}
