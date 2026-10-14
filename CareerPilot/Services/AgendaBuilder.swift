import Foundation

/// Der "Heute"-Überblick: was ist überfällig, was steht heute und bald an, wo kam keine Antwort.
struct Agenda {
    var overdue: [JobApplication] = []
    var followUpsToday: [JobApplication] = []
    var eventsToday: [ApplicationEvent] = []
    var upcomingEvents: [ApplicationEvent] = []
    var upcomingFollowUps: [JobApplication] = []
    var waiting: [JobApplication] = []

    var isEmpty: Bool {
        overdue.isEmpty && followUpsToday.isEmpty && eventsToday.isEmpty
            && upcomingEvents.isEmpty && upcomingFollowUps.isEmpty && waiting.isEmpty
    }

    /// Anzahl der Dinge, die jetzt Aufmerksamkeit brauchen (für das Zählzeichen in der Seitenleiste).
    var attentionCount: Int {
        overdue.count + followUpsToday.count + eventsToday.count
    }
}

enum AgendaBuilder {
    /// - Parameters:
    ///   - lookaheadDays: Zeitraum für "demnächst".
    ///   - waitingAfterDays: Nach so vielen Tagen ohne Antwort taucht eine Bewerbung unter "Wartet" auf.
    static func build(
        applications: [JobApplication],
        now: Date = .now,
        lookaheadDays: Int = 7,
        waitingAfterDays: Int = 7,
        calendar: Calendar = .current
    ) -> Agenda {
        var agenda = Agenda()
        let active = applications.filter { !$0.isArchived }
        let today = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .day, value: lookaheadDays + 1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        for application in active {
            switch application.followUpState(now: now, calendar: calendar) {
            case .overdue: agenda.overdue.append(application)
            case .dueToday: agenda.followUpsToday.append(application)
            case .upcoming(let days) where days <= lookaheadDays: agenda.upcomingFollowUps.append(application)
            case .upcoming, .none: break
            }

            for event in application.events {
                if event.start >= today, event.start < tomorrow {
                    agenda.eventsToday.append(event)
                } else if event.start >= tomorrow, event.start < horizon {
                    agenda.upcomingEvents.append(event)
                }
            }

            if application.status == .applied,
               let days = application.daysSinceApplied(now: now, calendar: calendar),
               days >= waitingAfterDays {
                let state = application.followUpState(now: now, calendar: calendar)
                if !state.needsAttention {
                    agenda.waiting.append(application)
                }
            }
        }

        let byFollowUp: (JobApplication, JobApplication) -> Bool = {
            ($0.followUpOn ?? .distantFuture) < ($1.followUpOn ?? .distantFuture)
        }
        agenda.overdue.sort(by: byFollowUp)
        agenda.followUpsToday.sort { $0.displayCompany < $1.displayCompany }
        agenda.upcomingFollowUps.sort(by: byFollowUp)
        agenda.eventsToday.sort { $0.start < $1.start }
        agenda.upcomingEvents.sort { $0.start < $1.start }
        agenda.waiting.sort {
            ($0.daysSinceApplied(now: now, calendar: calendar) ?? 0) > ($1.daysSinceApplied(now: now, calendar: calendar) ?? 0)
        }
        return agenda
    }
}
