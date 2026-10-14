import SwiftData
import SwiftUI

struct BoardColumnView: View {
    @Environment(ColumnSettings.self) private var settings

    let status: ApplicationStatus
    let cards: [JobApplication]
    let selection: PersistentIdentifier?
    let onSelect: (JobApplication) -> Void
    let onDrop: (_ uuid: UUID, _ status: ApplicationStatus, _ target: JobApplication?) -> Bool
    let onMove: (JobApplication, ApplicationStatus) -> Void
    let onToggleArchive: (JobApplication) -> Void
    let onDelete: (JobApplication) -> Void

    @State private var isColumnTargeted = false
    @State private var targetedCard: UUID?

    static let width: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(cards) { card in
                        cardButton(card)
                    }
                    if cards.isEmpty {
                        Text("Hierher ziehen")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    Color.clear.frame(height: 40)
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(10)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isColumnTargeted ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.quinary))
        )
        .overlay {
            if isColumnTargeted {
                RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.35), lineWidth: 1.5)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isColumnTargeted)
        .dropDestination(for: CardDragItem.self) { items, _ in
            guard let item = items.first else { return false }
            return onDrop(item.uuid, status, nil)
        } isTargeted: { isColumnTargeted = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(settings.title(for: status))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.tone == .idle ? Color.clear : status.color)
                .overlay { Circle().strokeBorder(status.color, lineWidth: status.tone == .idle ? 1.5 : 0) }
                .frame(width: 8, height: 8)
            Text(settings.title(for: status))
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text("\(cards.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func cardButton(_ card: JobApplication) -> some View {
        Button {
            onSelect(card)
        } label: {
            BoardCardView(application: card, isSelected: selection == card.persistentModelID)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if targetedCard == card.uuid {
                Capsule().fill(.primary).frame(height: 3).offset(y: -6)
            }
        }
        .draggable(CardDragItem(uuid: card.uuid))
        .dropDestination(for: CardDragItem.self) { items, _ in
            guard let item = items.first else { return false }
            return onDrop(item.uuid, status, card)
        } isTargeted: { targeted in
            targetedCard = targeted ? card.uuid : (targetedCard == card.uuid ? nil : targetedCard)
        }
        .contextMenu {
            Menu("Verschieben nach", systemImage: "arrow.right") {
                ForEach(settings.visibleStatuses.filter { $0 != card.status }) { target in
                    Button(settings.title(for: target)) {
                        onMove(card, target)
                    }
                }
            }
            Button("Archivieren", systemImage: "archivebox") {
                onToggleArchive(card)
            }
            Divider()
            Button("Löschen", systemImage: "trash", role: .destructive) {
                onDelete(card)
            }
        }
    }
}
