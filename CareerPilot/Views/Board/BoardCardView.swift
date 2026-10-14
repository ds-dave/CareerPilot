import SwiftUI

struct BoardCardView: View {
    let application: JobApplication
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                CompanyLogoView(application: application, size: 30)
                Text(application.displayCompany)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)
                if application.priority == .high {
                    Image(systemName: "exclamationmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Hohe Priorität")
                }
                Spacer(minLength: 0)
            }
            Text(application.position)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if placeLine != nil || application.jobURL != nil || !application.documents.isEmpty {
                HStack(spacing: 6) {
                    if let place = placeLine {
                        Text(place)
                            .lineLimit(1)
                    }
                    if application.jobURL != nil {
                        Image(systemName: "link")
                            .accessibilityLabel("Link zur Anzeige vorhanden")
                    }
                    if !application.documents.isEmpty {
                        Image(systemName: "paperclip")
                            .accessibilityLabel("\(application.documents.count) Dokumente angehängt")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !application.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(application.tags, id: \.self) { tag in
                        TagChip(text: tag)
                    }
                }
                .padding(.top, 2)
            }

            footer
                .font(.caption)
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.separator),
                              lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeLine: String? {
        let parts = [application.location, application.workModel?.title].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var footer: some View {
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
