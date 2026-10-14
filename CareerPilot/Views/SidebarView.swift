import SwiftUI

struct SidebarView: View {
    @Environment(ColumnSettings.self) private var settings
    @Environment(ReminderSettings.self) private var reminders
    @Environment(SavedFilterStore.self) private var savedFilters
    @Binding var selection: SidebarItem?
    let applications: [JobApplication]

    /// Alle verwendeten Tags (ohne Archiv), alphabetisch.
    private var tags: [String] {
        var seen: [String: String] = [:]
        for application in applications where !application.isArchived {
            for tag in application.tags {
                seen[tag.lowercased()] = seen[tag.lowercased()] ?? tag
            }
        }
        return seen.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        List(selection: $selection) {
            // Das Logo steht als erste Zeile der Seitenleiste und ist auf jeder Seite zu sehen.
            LogoLockup(markSize: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .selectionDisabled()

            Section {
                row(.agenda)
                row(.calendar)
                row(.statistics)
            }
            Section("Bewerbungen") {
                row(.all)
                row(.open)
                row(.followUp)
            }
            Section("Status") {
                ForEach(settings.visibleStatuses) { status in
                    row(.status(status))
                }
            }
            if !savedFilters.filters.isEmpty {
                Section("Ansichten") {
                    ForEach(savedFilters.filters) { saved in
                        row(.savedFilter(saved.id))
                            .contextMenu {
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    if selection == .savedFilter(saved.id) { selection = .all }
                                    savedFilters.remove(id: saved.id)
                                }
                            }
                    }
                }
            }
            if !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        row(.tag(tag))
                    }
                }
            }
            Section {
                row(.archive)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
    }

    private func count(for item: SidebarItem) -> Int {
        switch item {
        case .agenda:
            AgendaBuilder.build(
                applications: applications, waitingAfterDays: reminders.preferences.followUpDays
            ).attentionCount
        case .calendar:
            applications.filter { !$0.isArchived }.flatMap(\.events).count { $0.start >= .now }
        case .statistics:
            0
        case .savedFilter(let id):
            savedFilters.filter(withID: id).map { saved in
                applications.count { !$0.isArchived && saved.filter.matches($0) }
            } ?? 0
        default:
            applications.count(where: item.includes)
        }
    }

    private func row(_ item: SidebarItem) -> some View {
        Label {
            Text(item.title(using: settings, savedFilters: savedFilters))
        } icon: {
            Image(systemName: item.systemImage)
                .foregroundStyle(item.tint ?? Color.secondary)
        }
        .badge(count(for: item))
            .tag(item)
    }
}
