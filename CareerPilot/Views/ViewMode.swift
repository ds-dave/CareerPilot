import Foundation

enum ViewMode: String, CaseIterable, Identifiable {
    case board
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .board: "Board"
        case .list: "Liste"
        }
    }

    var systemImage: String {
        switch self {
        case .board: "rectangle.split.3x1"
        case .list: "list.bullet"
        }
    }
}
