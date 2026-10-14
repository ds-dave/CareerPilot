import SwiftUI

struct ApplicationRow: View {
    let application: JobApplication

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CompanyLogoView(application: application, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(application.displayCompany)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    if application.priority == .high {
                        Image(systemName: "exclamationmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .help("Hohe Priorität")
                            .accessibilityLabel("Hohe Priorität")
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                StatusBadge(status: application.status)
                detail
                    .font(.caption)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        [application.position, application.location, application.workModel?.title]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var detail: some View {
        switch application.followUpState() {
        case .overdue(let days):
            Text("Nachfassen überfällig seit \(days) \(days == 1 ? "Tag" : "Tagen")")
                .foregroundStyle(.red)
        case .dueToday:
            Text("Nachfassen heute")
                .foregroundStyle(.red)
        case .upcoming, .none:
            if let days = application.daysSinceApplied() {
                Text("\(days) \(days == 1 ? "Tag" : "Tage") seit Bewerbung")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
