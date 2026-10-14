import Foundation

/// Das Raster einer Monatsansicht: immer sechs volle Wochen, beginnend am Wochenanfang des Kalenders.
enum MonthGrid {
    static func weeks(containing date: Date, calendar: Calendar = .current) -> [[Date]] {
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: monthStart) else { return [] }

        return (0..<6).map { week in
            (0..<7).compactMap { day in
                calendar.date(byAdding: .day, value: week * 7 + day, to: gridStart)
            }
        }
    }

    /// Kürzel der Wochentage, beginnend mit dem ersten Wochentag des Kalenders.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
