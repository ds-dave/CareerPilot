import SwiftUI

/// Die Befehlspalette (⌘K): tippen, mit Pfeiltasten wählen, mit Eingabe ausführen, mit Esc schließen.
struct CommandPaletteView: View {
    let items: [PaletteItem]
    let onPerform: (PaletteAction) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    private var results: [PaletteItem] {
        CommandPalette.search(items, query: query)
    }

    var body: some View {
        let results = results
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Befehl, Bewerbung oder Ansicht suchen …", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit { perform(results) }
                    .onKeyPress(.downArrow) { move(1, count: results.count); return .handled }
                    .onKeyPress(.upArrow) { move(-1, count: results.count); return .handled }
                    .onKeyPress(.escape) { onClose(); return .handled }
                    .accessibilityLabel("Befehlspalette")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if results.isEmpty {
                Text("Nichts gefunden.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                row(item, isSelected: index == min(selectedIndex, results.count - 1))
                                    .id(item.id)
                                    .onHover { inside in
                                        if inside { selectedIndex = index }
                                    }
                                    .onTapGesture {
                                        onPerform(item.action)
                                        onClose()
                                    }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 420)
                    .onChange(of: selectedIndex) { _, newValue in
                        if results.indices.contains(newValue) {
                            proxy.scrollTo(results[newValue].id)
                        }
                    }
                }
            }
        }
        .frame(width: 580)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
        .onAppear { isFocused = true }
        .onChange(of: query) { selectedIndex = 0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Befehlspalette")
    }

    private func row(_ item: PaletteItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .frame(width: 22)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func move(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        selectedIndex = (min(selectedIndex, count - 1) + delta + count) % count
    }

    private func perform(_ results: [PaletteItem]) {
        guard !results.isEmpty else { return }
        let item = results[min(selectedIndex, results.count - 1)]
        onPerform(item.action)
        onClose()
    }
}
