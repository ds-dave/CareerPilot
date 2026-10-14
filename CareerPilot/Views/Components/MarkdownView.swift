import SwiftUI

/// Zeigt Markdown-Notizen gerendert an (Überschriften, Listen, Checklisten, Zitate, Fett/Kursiv/Links).
struct MarkdownView: View {
    let source: String

    var body: some View {
        let blocks = MarkdownParser.blocks(from: source)
        if blocks.isEmpty {
            Text("Keine Notizen.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(level == 1 ? .title2 : level == 2 ? .title3 : .headline)
                .fontWeight(.bold)
                .padding(.top, level == 1 ? 6 : 2)
        case .paragraph(let text):
            inline(text)
        case .bullet(let text, let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                switch checked {
                case .some(true): Image(systemName: "checkmark.square").foregroundStyle(.secondary)
                case .some(false): Image(systemName: "square").foregroundStyle(.secondary)
                case .none: Text("•").foregroundStyle(.secondary)
                }
                inline(text)
                    .strikethrough(checked == true)
                    .foregroundStyle(checked == true ? .secondary : .primary)
            }
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                inline(text)
            }
        case .quote(let text):
            HStack(spacing: 10) {
                Rectangle().fill(.secondary.opacity(0.5)).frame(width: 3)
                inline(text).foregroundStyle(.secondary)
            }
        case .rule:
            Divider()
        }
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: text, options: options) {
            return Text(attributed)
        }
        return Text(text)
    }
}
