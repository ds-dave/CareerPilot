import SwiftUI

/// Monatsansicht mit Terminen und Nachfass-Terminen.
struct MonthCalendarView: View {
    let events: [ApplicationEvent]
    let followUps: [JobApplication]
    @Binding var month: Date
    let onOpenEvent: (ApplicationEvent) -> Void
    let onSelect: (JobApplication) -> Void

    private let calendar = Calendar.current
    private let maxVisiblePerDay = 3

    var body: some View {
        VStack(spacing: 0) {
            header
            weekdayRow
            Divider()
            grid
        }
    }

    // MARK: Kopf

    private var header: some View {
        HStack(spacing: 12) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 22, weight: .heavy))
                .tracking(-0.6)
            Spacer()
            Button("Voriger Monat", systemImage: "chevron.left") { shift(-1) }
                .labelStyle(.iconOnly)
            Button("Heute") { month = .now }
            Button("Nächster Monat", systemImage: "chevron.right") { shift(1) }
                .labelStyle(.iconOnly)
        }
        .padding([.horizontal, .top], 16)
        .padding(.bottom, 10)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(MonthGrid.weekdaySymbols(calendar: calendar), id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: Raster

    private var grid: some View {
        let weeks = MonthGrid.weeks(containing: month, calendar: calendar)
        return VStack(spacing: 0) {
            ForEach(weeks.indices, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(weeks[week], id: \.self) { day in
                        dayCell(day)
                    }
                }
                if week < weeks.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isInMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let dayEvents = events
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
        let dayFollowUps = followUps.filter {
            $0.followUpOn.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        }
        let total = dayEvents.count + dayFollowUps.count

        return VStack(alignment: .leading, spacing: 3) {
            Text("\(calendar.component(.day, from: day))")
                .font(.caption.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(dayNumberStyle(isToday: isToday, isInMonth: isInMonth))
                .frame(width: 22, height: 22)
                .background {
                    if isToday { Circle().fill(.primary) }
                }

            ForEach(dayEvents.prefix(maxVisiblePerDay)) { event in
                Button {
                    onOpenEvent(event)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: event.kind.systemImage)
                            .font(.system(size: 9))
                        Text(event.start.formatted(date: .omitted, time: .shortened))
                            .monospacedDigit()
                        Text(event.application?.displayCompany ?? event.displayTitle)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("\(event.displayTitle) bei \(event.application?.displayCompany ?? "")")
            }

            let remaining = max(0, maxVisiblePerDay - dayEvents.count)
            ForEach(dayFollowUps.prefix(remaining)) { application in
                Button {
                    onSelect(application)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bell")
                            .font(.system(size: 9))
                        Text(application.displayCompany)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .help("Nachfassen bei \(application.displayCompany)")
            }

            if total > maxVisiblePerDay {
                Text("+\(total - maxVisiblePerDay) weitere")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: .infinity, alignment: .topLeading)
        .background(isInMonth ? Color.clear : Color.primary.opacity(0.03))
        .overlay(alignment: .leading) {
            Rectangle().fill(.separator).frame(width: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
    }

    private func dayNumberStyle(isToday: Bool, isInMonth: Bool) -> AnyShapeStyle {
        if isToday { return AnyShapeStyle(Color(nsColor: .textBackgroundColor)) }
        return isInMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
    }

    private func shift(_ months: Int) {
        month = calendar.date(byAdding: .month, value: months, to: month) ?? month
    }
}
