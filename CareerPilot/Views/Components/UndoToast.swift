import SwiftUI

/// Kurzer Hinweis am unteren Rand mit "Rückgängig", wie nach dem Löschen in Mail oder Notion.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(message)
                .lineLimit(1)
                .truncationMode(.middle)
            Button("Rückgängig", action: onUndo)
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
            Button("Schließen", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 10, weight: .bold))
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }
}
