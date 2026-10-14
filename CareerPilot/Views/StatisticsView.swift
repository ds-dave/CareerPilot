import Charts
import SwiftUI

extension Outcome {
    /// Dieselben Farben wie bei den Status, damit Diagramme und Board zusammenpassen.
    var color: Color {
        switch self {
        case .accepted: ApplicationStatus.accepted.color
        case .offer: ApplicationStatus.offer.color
        case .inTalks: ApplicationStatus.interview.color
        case .open: ApplicationStatus.applied.color
        case .rejected: ApplicationStatus.rejected.color
        }
    }
}

/// Kennzahlen und Diagramme zur Bewerbungsphase.
struct StatisticsView: View {
    @Environment(ColumnSettings.self) private var settings

    let applications: [JobApplication]

    @AppStorage("statsRange") private var range: StatsRange = .all

    private var stats: Statistics {
        StatisticsCalculator.compute(applications: applications, range: range)
    }

    var body: some View {
        let stats = stats
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if stats.applied == 0, stats.statusDistribution.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Daten",
                        systemImage: "chart.bar",
                        description: Text(
                            range == .all
                                ? "Sobald du Bewerbungen abgeschickt hast, siehst du hier, wie sie laufen."
                                : "In diesem Zeitraum gibt es keine Bewerbungen. Wähle einen längeren Zeitraum."
                        )
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    metrics(stats)
                    charts(stats)
                }
            }
            .padding(24)
            .frame(maxWidth: 1_100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Kopf

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Zeitraum")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Picker("Zeitraum", selection: $range) {
                ForEach(StatsRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)
            Spacer()
        }
    }

    // MARK: Kennzahlen

    private func metrics(_ stats: Statistics) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
            MetricCard(title: "Bewerbungen", value: "\(stats.applied)", detail: "abgeschickt")
            MetricCard(
                title: "Antwortquote",
                value: percent(stats.responseRate),
                detail: "\(stats.responded) von \(stats.applied) haben geantwortet"
            )
            MetricCard(
                title: "Ø bis zur Antwort",
                value: stats.averageDaysToResponse.map { days in
                    days < 10 ? days.formatted(.number.precision(.fractionLength(1))) : days.formatted(.number.precision(.fractionLength(0)))
                } ?? "–",
                unit: stats.averageDaysToResponse == nil ? nil : "Tage",
                detail: stats.responseTimeSamples == 0
                    ? "noch keine Antwort mit bekanntem Datum"
                    : "aus \(stats.responseTimeSamples) Antworten"
            )
            MetricCard(
                title: "Interviewquote",
                value: percent(stats.interviewRate),
                detail: "\(stats.interviewed) Gespräche"
            )
            MetricCard(title: "Angebote", value: "\(stats.offers)", detail: stats.accepted == 0 ? "bisher keine Zusage" : "davon \(stats.accepted) Zusage\(stats.accepted == 1 ? "" : "n")")
            MetricCard(title: "Absagen", value: "\(stats.rejected)", detail: stats.applied > 0 ? "\(percent(Double(stats.rejected) / Double(stats.applied))) der Bewerbungen" : "")
            MetricCard(title: "Aktuell offen", value: "\(stats.open)", detail: "noch ohne Entscheidung")
            MetricCard(
                title: "Wartet am längsten",
                value: stats.longestWaiting.map { "\($0.days)" } ?? "–",
                unit: stats.longestWaiting == nil ? nil : "Tage",
                detail: stats.longestWaiting.map { "\($0.company)" } ?? "keine offene Bewerbung ohne Antwort"
            )
        }
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    // MARK: Diagramme

    private func charts(_ stats: Statistics) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 440), spacing: 12, alignment: .top)], spacing: 12) {
            ChartCard(title: "Trichter", subtitle: "Wie weit Bewerbungen gekommen sind") {
                funnelChart(stats.funnel)
            }
            ChartCard(title: "Bewerbungen pro Woche", subtitle: "Abgeschickt, nach Kalenderwoche") {
                weeklyChart(stats.weekly)
            }
            ChartCard(title: "Ergebnis nach Onlineportal", subtitle: "Aktueller Stand je Quelle") {
                sourceChart(stats.sourceOutcomes)
            }
            ChartCard(title: "Verteilung nach Status", subtitle: "Alle Bewerbungen im Zeitraum") {
                statusChart(stats.statusDistribution)
            }
        }
    }

    private func funnelChart(_ stages: [FunnelStage]) -> some View {
        Chart(stages) { stage in
            BarMark(
                xStart: .value("Start", -Double(stage.count) / 2),
                xEnd: .value("Ende", Double(stage.count) / 2),
                y: .value("Stufe", stage.title),
                height: .ratio(0.8)
            )
            .foregroundStyle(color(for: stage))
            .cornerRadius(4)
            .annotation(position: .overlay) {
                Text(label(for: stage))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: stages.map(\.title))
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
            }
        }
        .frame(height: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trichter")
        .accessibilityValue(stages.map { "\($0.title): \($0.count)" }.joined(separator: ", "))
    }

    /// Die Stufen haben die Farben der Status, die sie am besten beschreiben.
    private func color(for stage: FunnelStage) -> Color {
        switch stage.title {
        case "Beworben": ApplicationStatus.applied.color
        case "Antwort": ApplicationStatus.acknowledged.color
        case "Interview": ApplicationStatus.interview.color
        default: ApplicationStatus.offer.color
        }
    }

    private func label(for stage: FunnelStage) -> String {
        guard let share = stage.share else { return "\(stage.count)" }
        // Schmale Balken haben keinen Platz für Anzahl und Prozentwert.
        guard share >= 0.2 else { return "\(stage.count)" }
        return "\(stage.count) · \(share.formatted(.percent.precision(.fractionLength(0))))"
    }

    private func weeklyChart(_ weeks: [WeekBucket]) -> some View {
        Chart(weeks) { bucket in
            BarMark(
                x: .value("Woche", bucket.weekStart, unit: .weekOfYear),
                y: .value("Bewerbungen", bucket.count)
            )
            .foregroundStyle(ApplicationStatus.applied.color)
            .cornerRadius(3)
            .annotation(position: .top, spacing: 2) {
                if bucket.count > 0, weeks.count <= 16 {
                    Text("\(bucket.count)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: weeks.count > 20 ? 8 : (weeks.count > 8 ? 2 : 1))) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: false)
            }
        }
        .frame(height: 220)
    }

    private func sourceChart(_ rows: [SourceOutcome]) -> some View {
        Chart(rows) { row in
            BarMark(
                x: .value("Anzahl", row.count),
                y: .value("Portal", row.source)
            )
            .foregroundStyle(by: .value("Ergebnis", row.outcome.title))
            .cornerRadius(3)
        }
        .chartForegroundStyleScale(
            domain: Outcome.allCases.map(\.title),
            range: Outcome.allCases.map(\.color)
        )
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: max(220, CGFloat(Set(rows.map(\.source)).count) * 38 + 70))
    }

    private func statusChart(_ shares: [StatusShare]) -> some View {
        Chart(shares) { share in
            SectorMark(
                angle: .value("Anzahl", share.count),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(by: .value("Status", settings.title(for: share.status)))
        }
        .chartForegroundStyleScale(
            domain: shares.map { settings.title(for: $0.status) },
            range: shares.map(\.status.color)
        )
        .chartLegend(position: .trailing, alignment: .center)
        .frame(height: 220)
    }
}

// MARK: - Bausteine

private struct MetricCard: View {
    let title: String
    let value: String
    var unit: String?
    var detail: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-1)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(minHeight: 28, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        .accessibilityElement(children: .combine)
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy))
                    .tracking(-0.4)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }
}
