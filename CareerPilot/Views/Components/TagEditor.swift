import SwiftUI

struct TagEditor: View {
    @Binding var tags: [String]
    /// Alle bekannten Tags der anderen Bewerbungen, als Vorschlag.
    let suggestions: [String]

    @State private var draft = ""

    private var unusedSuggestions: [String] {
        suggestions.filter { !TagList.contains(tags, $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            HStack {
                TextField("Tag hinzufügen", text: $draft)
                    .onSubmit(commit)
                if !unusedSuggestions.isEmpty {
                    Menu("Vorschläge", systemImage: "tag") {
                        ForEach(unusedSuggestions, id: \.self) { tag in
                            Button(tag) {
                                tags = TagList.adding(tag, to: tags)
                            }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
    }

    private func commit() {
        tags = TagList.adding(draft, to: tags)
        draft = ""
    }
}
