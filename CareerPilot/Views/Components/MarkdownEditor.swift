import SwiftUI

/// Texteingabe für Markdown mit umschaltbarer Vorschau.
struct MarkdownEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 140
    @State private var isPreviewing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Ansicht", selection: $isPreviewing) {
                Text("Bearbeiten").tag(false)
                Text("Vorschau").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if isPreviewing {
                MarkdownView(source: text)
                    .frame(maxWidth: .infinity, minHeight: minHeight * 0.6, alignment: .topLeading)
            } else {
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
            }
        }
    }
}
