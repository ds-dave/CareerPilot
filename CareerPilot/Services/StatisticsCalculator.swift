import Foundation

/// Zeitraum der Statistik, bezogen auf das Bewerbungsdatum.
enum StatsRange: String, CaseIterable, Identifiable, Sendable {
    case fourWeeks
    case threeMonths
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fourWeeks: "4 Wochen"
        case .threeMonths: "3 Monate"
        case .all: "Gesamt"
        }
    }

    /// Frühester Zeitpunkt, der noch zählt; `nil` heißt unbegrenzt.
    func cutoff(now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .fourWeeks: return calendar.date(byAdding: .day, value: -28, to: today)
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: today)
        case .all: return nil
        }
    }
}

/// Wie eine Bewerbung aktuell dasteht.
enum Outcome: CaseIterable, Identifiable, Sendable {
    case accepted, offer, inTalks, open, rejected

    var id: Self { self }

    var title: String {
        switch self {
        case .accepted: "Zusage"
        case .offer: "Angebot"
        case .inTalks: "Im Gespräch"
        case .open: "Offen"
        case .rejected: "Absage"
        }
    }

    init(status: ApplicationStatus) {
        switch status {
        case .accepted: self = .accepted
        case .offer: self = .offer
        case .rejected: self = .rejected
        case .phoneScreen, .interview: self = .inTalks
        case .wishlist, .applied, .acknowledged: self = .open
        }
    }
}

struct FunnelStage: Identifiable, Equatable, Sendable {
    let title: String
    let count: Int
    /// Anteil an allen Bewerbungen, `nil` ohne Bewerbungen.
    let share: Double?

    var id: String { title }
}

struct WeekBucket: Identifiable, Equatable, Sendable {
    let weekStart: Date
    let count: Int

    var id: Date { weekStart }
}

struct SourceOutcome: Identifiable, Equatable, Sendable {
    let source: String
    let outcome: Outcome
    let count: Int

    var id: String { "\(source)-\(outcome.title)" }
}

struct StatusShare: Identifiable, Equatable, Sendable {
    let status: ApplicationStatus
    let count: Int

    var id: ApplicationStatus { status }
}

struct WaitingEntry: Equatable, Sendable {
    let company: String
    let position: String
    let days: Int
}

struct Statistics: Equatable, Sendable {
    var applied = 0
    var responded = 0
    var interviewed = 0
    var offers = 0
    var accepted = 0
    var rejected = 0
    var open = 0
    var averageDaysToResponse: Double?
    var responseTimeSamples = 0
    var longestWaiting: WaitingEntry?
    var funnel: [FunnelStage] = []
    var weekly: [WeekBucket] = []
    var sourceOutcomes: [SourceOutcome] = []
    var statusDistribution: [StatusShare] = []

    var responseRate: Double? { applied > 0 ? Double(responded) / Double(applied) : nil }
    var interviewRate: Double? { applied > 0 ? Double(interviewed) / Double(applied) : nil }
}

enum StatisticsCalculator {
    /// Die Kennzahlen zählen nur abgeschickte Bewerbungen. Archivierte gehören dazu, denn
    /// Archivieren ist Aufräumen und kein Löschen der Geschichte.
    static func compute(
        applications: [JobApplication],
        range: StatsRange,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Statistics {
        let cutoff = range.cutoff(now: now, calendar: calendar)
        let inRange = applications.filter { application in
            guard let cutoff else { return true }
            return referenceDate(of: application) >= cutoff
        }
        let submitted = inRange.filter { $0.status.isSubmitted }

        var stats = Statistics()
        stats.applied = submitted.count

        let responded = submitted.filter {
            !$0.reachedStatuses.isDisjoint(with: ApplicationStatus.responseStatuses)
        }
        let interviewStatuses: Set<ApplicationStatus> = [.interview, .offer, .accepted]
        let interviewKinds: Set<EventKind> = [.interview, .technical, .trial]
        let interviewed = submitted.filter { application in
            !application.reachedStatuses.isDisjoint(with: interviewStatuses)
                || application.events.contains { interviewKinds.contains($0.kind) }
        }
        let offers = submitted.filter { !$0.reachedStatuses.isDisjoint(with: [.offer, .accepted]) }

        stats.responded = responded.count
        stats.interviewed = interviewed.count
        stats.offers = offers.count
        stats.accepted = submitted.count { $0.status == .accepted }
        stats.rejected = submitted.count { $0.status == .rejected }
        stats.open = submitted.count { !$0.isArchived && !$0.status.isFinished }

        // Wartezeit bis zur ersten Antwort: nur, wo der Verlauf das Datum kennt.
        let durations: [Int] = responded.compactMap { application in
            guard let appliedOn = application.appliedOn, let answered = application.firstResponseDate else { return nil }
            let from = calendar.startOfDay(for: appliedOn)
            let to = calendar.startOfDay(for: answered)
            return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
        }
        stats.responseTimeSamples = durations.count
        if !durations.isEmpty {
            stats.averageDaysToResponse = Double(durations.reduce(0, +)) / Double(durations.count)
        }

        // Am längsten wartend: abgeschickt, noch keine Antwort.
        stats.longestWaiting = submitted
            .filter { $0.status == .applied && !$0.isArchived }
            .compactMap { application -> WaitingEntry? in
                guard let days = application.daysSinceApplied(now: now, calendar: calendar) else { return nil }
                return WaitingEntry(company: application.displayCompany, position: application.position, days: days)
            }
            .max { $0.days < $1.days }

        stats.funnel = funnel(stats)
        stats.weekly = weeklyBuckets(submitted, cutoff: cutoff, now: now, calendar: calendar)
        stats.sourceOutcomes = sourceOutcomes(submitted)
        stats.statusDistribution = ApplicationStatus.allCases.compactMap { status in
            let count = inRange.count { $0.status == status }
            return count > 0 ? StatusShare(status: status, count: count) : nil
        }
        return stats
    }

    // MARK: Bausteine

    static func referenceDate(of application: JobApplication) -> Date {
        application.appliedOn ?? application.createdAt
    }

    private static func funnel(_ stats: Statistics) -> [FunnelStage] {
        func stage(_ title: String, _ count: Int) -> FunnelStage {
            FunnelStage(
                title: title, count: count,
                share: stats.applied > 0 ? Double(count) / Double(stats.applied) : nil
            )
        }
        return [
            stage("Beworben", stats.applied),
            stage("Antwort", stats.responded),
            stage("Interview", stats.interviewed),
            stage("Angebot", stats.offers),
        ]
    }

    private static func weeklyBuckets(
        _ submitted: [JobApplication], cutoff: Date?, now: Date, calendar: Calendar
    ) -> [WeekBucket] {
        func weekStart(_ date: Date) -> Date {
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        }
        let currentWeek = weekStart(now)
        let dates = submitted.map(referenceDate(of:))
        let earliest = cutoff ?? dates.min() ?? now
        var first = weekStart(earliest)
        // Höchstens ein Jahr zurück, sonst wird das Diagramm unlesbar.
        if let limit = calendar.date(byAdding: .weekOfYear, value: -51, to: currentWeek), first < limit {
            first = limit
        }

        var counts: [Date: Int] = [:]
        for date in dates {
            counts[weekStart(date), default: 0] += 1
        }

        var buckets: [WeekBucket] = []
        var week = first
        while week <= currentWeek {
            buckets.append(WeekBucket(weekStart: week, count: counts[week] ?? 0))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            week = next
        }
        return buckets
    }

    private static func sourceOutcomes(_ submitted: [JobApplication]) -> [SourceOutcome] {
        var grouped: [String: [Outcome: Int]] = [:]
        for application in submitted {
            let source = application.portalTitle ?? "Ohne Angabe"
            grouped[source, default: [:]][Outcome(status: application.status), default: 0] += 1
        }
        let order = grouped.keys.sorted { lhs, rhs in
            let l = grouped[lhs]?.values.reduce(0, +) ?? 0
            let r = grouped[rhs]?.values.reduce(0, +) ?? 0
            return l != r ? l > r : lhs < rhs
        }
        return order.flatMap { source in
            Outcome.allCases.compactMap { outcome -> SourceOutcome? in
                guard let count = grouped[source]?[outcome], count > 0 else { return nil }
                return SourceOutcome(source: source, outcome: outcome, count: count)
            }
        }
    }
}
