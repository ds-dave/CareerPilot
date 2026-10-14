import SwiftUI

/// Status als kleiner Punkt plus Beschriftung. Keine Farben: der Zustand steckt in Füllung und Schriftgewicht.
struct StatusBadge: View {
    @Environment(ColumnSettings.self) private var settings
    let status: ApplicationStatus

    var body: some View {
        HStack(spacing: 6) {
            dot
            Text(settings.title(for: status))
                .font(.subheadline)
                .fontWeight(status.tone == .strong ? .semibold : .regular)
                .foregroundStyle(status.tone == .closed ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var dot: some View {
        switch status.tone {
        case .idle:
            Circle().strokeBorder(status.color, lineWidth: 1.5).frame(width: 8, height: 8)
        case .active:
            Circle().fill(status.color).frame(width: 8, height: 8)
        case .strong:
            Circle().fill(status.color).frame(width: 10, height: 10)
        case .closed:
            Circle().fill(status.color).frame(width: 8, height: 8)
        }
    }
}
