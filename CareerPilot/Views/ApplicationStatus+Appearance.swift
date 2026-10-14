import SwiftUI

extension ApplicationStatus {
    /// Farbe des Statuspunkts. Systemfarben, damit sie sich an Hell- und Dunkelmodus anpassen.
    var color: Color {
        switch self {
        case .wishlist: .gray
        case .applied: .blue
        case .acknowledged: .teal
        case .phoneScreen: .indigo
        case .interview: .purple
        case .offer: .orange
        case .accepted: .green
        case .rejected: .red
        }
    }

    /// SF-Symbol für Seitenleiste und Menüs.
    var systemImage: String {
        switch self {
        case .wishlist: "circle"
        case .accepted: "checkmark.circle.fill"
        case .rejected: "xmark.circle.fill"
        default: "circle.fill"
        }
    }
}
