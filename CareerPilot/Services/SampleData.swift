import AppKit
import Foundation
import SwiftData

/// Erfundene Beispieldaten zum Ausprobieren und für Screenshots.
/// Alle Firmen und Stellen sind frei erfunden.
enum SampleData {
    static func insert(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        func day(_ offset: Int, hour: Int = 10) -> Date {
            let start = calendar.startOfDay(for: now)
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return calendar.date(byAdding: .hour, value: hour, to: date) ?? date
        }

        let entries: [JobApplication] = [
            make("Fabel Studio", "Product Engineer", .wishlist,
                 location: "Berlin", model: .remote, source: .companySite,
                 tags: ["SwiftUI", "Design"], day: { day($0, hour: $1) }),
            make("Demo Cloud", "Backend Engineer", .applied,
                 location: "Hamburg", model: .hybrid, source: .companySite,
                 applied: day(-3), followUp: day(4), tags: ["Cloud", "Java"],
                 history: [(-3, .applied)], day: { day($0, hour: $1) }),
            make("Muster Digital", "Frontend Engineer", .applied,
                 location: "Köln", model: .remote, source: .linkedIn,
                 applied: day(-1), tags: ["TypeScript"],
                 history: [(-1, .applied)], day: { day($0, hour: $1) }),
            make("Fiktiv Mobility", "Software Developer", .acknowledged,
                 location: "München", model: .hybrid, source: .stepStone,
                 applied: day(-7), tags: ["Python"],
                 history: [(-7, .applied), (-6, .acknowledged)], day: { day($0, hour: $1) }),
            make("Beispiel Atelier", "UX Engineer", .interview,
                 location: "Wien", model: .remote, source: .companySite,
                 applied: day(-18), tags: ["Design", "Remote"],
                 history: [(-18, .applied), (-14, .acknowledged), (-4, .interview)],
                 day: { day($0, hour: $1) }),
            make("Nordlicht Software", "Backend-Entwickler (Java)", .interview,
                 location: "Hamburg", model: .hybrid, source: .linkedIn, priority: .high,
                 applied: day(-14), followUp: day(2), salary: (62_000, 74_000),
                 tags: ["Java", "Hybrid"],
                 notes: """
                 ## Vorbereitung
                 - [x] Unternehmen recherchiert
                 - [ ] Fragen zum **Tech-Stack** sammeln
                 - [ ] Gehaltsvorstellung klären

                 > Interview mit dem Team-Lead, 45 Minuten.
                 """,
                 history: [(-14, .applied), (-12, .acknowledged), (-8, .phoneScreen), (-3, .interview)],
                 note: (-8, "Telefonat mit Frau Beispiel, nette Atmosphäre."),
                 day: { day($0, hour: $1) }),
            make("Beispiel AG", "Fullstack Engineer", .applied,
                 location: "Berlin", model: .remote, source: .stepStone,
                 applied: day(-9), followUp: day(-2), tags: ["Remote"],
                 history: [(-9, .applied)], day: { day($0, hour: $1) }),
            make("Muster Labs", "Software Engineer", .wishlist,
                 location: "München", model: .onsite, source: .companySite,
                 tags: ["Startup"], day: { day($0, hour: $1) }),
            make("Fiktiv Systems", "Platform Engineer", .acknowledged,
                 location: "Wien", model: .hybrid, source: .referral, priority: .high,
                 applied: day(-5), followUp: day(0), tags: ["Empfehlung", "Hybrid"],
                 history: [(-5, .applied), (-4, .acknowledged)], day: { day($0, hour: $1) }),
            make("Demo Industries", "iOS-Entwickler", .rejected,
                 location: "Köln", model: .onsite, source: .indeed, applied: day(-30),
                 history: [(-30, .applied), (-20, .rejected)], day: { day($0, hour: $1) }),
            make("Probe Robotics", "Swift Developer", .phoneScreen,
                 location: "Leipzig", model: .remote, source: .speculative,
                 applied: day(-11), followUp: day(4), tags: ["Swift", "Remote"],
                 history: [(-11, .applied), (-6, .phoneScreen)], day: { day($0, hour: $1) }),
            make("Testwerk GmbH", "Mobile Engineer", .offer,
                 location: "Stuttgart", model: .hybrid, source: .linkedIn, priority: .high,
                 applied: day(-27), salary: (68_000, 72_000), tags: ["Swift", "Hybrid"],
                 history: [(-27, .applied), (-20, .phoneScreen), (-12, .interview), (-2, .offer)],
                 note: (-2, "Angebot per E-Mail erhalten, Antwort bis Freitag."),
                 day: { day($0, hour: $1) }),
        ]

        addEventsAndContacts(to: entries, day: { day($0, hour: $1) })

        // Drei Beispiel-Logos (erfunden), die übrigen Firmen zeigen den Anfangsbuchstaben.
        let logos: [(String, String, NSColor)] = [
            ("Nordlicht Software", "N", NSColor(red: 0.20, green: 0.40, blue: 0.95, alpha: 1)),
            ("Fiktiv Systems", "F", NSColor(red: 0.12, green: 0.62, blue: 0.40, alpha: 1)),
            ("Testwerk GmbH", "T", NSColor(red: 0.95, green: 0.55, blue: 0.12, alpha: 1)),
        ]
        for (company, letter, color) in logos {
            if let entry = entries.first(where: { $0.company == company }),
               let data = sampleLogo(letter: letter, color: color) {
                entry.setLogo(from: data)
            }
        }

        // Reihenfolge innerhalb jeder Spalte festlegen.
        var counters: [ApplicationStatus: Int] = [:]
        for entry in entries {
            entry.sortIndex = counters[entry.status, default: 0]
            counters[entry.status, default: 0] += 1
        }
        entries.forEach(context.insert)
    }

    /// Zeichnet ein einfaches Beispiel-Logo: heller Buchstabe auf farbigem Kreis.
    private static func sampleLogo(letter: String, color: NSColor) -> Data? {
        let side = 160
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: side - 16, height: side - 16)).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 88, weight: .heavy),
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: letter, attributes: attributes)
        let size = text.size()
        text.draw(at: NSPoint(x: (CGFloat(side) - size.width) / 2, y: (CGFloat(side) - size.height) / 2))
        return rep.representation(using: .png, properties: [:])
    }

    private static func addEventsAndContacts(
        to entries: [JobApplication], day: (Int, Int) -> Date
    ) {
        if let nordlicht = entries.first(where: { $0.company == "Nordlicht Software" }) {
            let contact = ContactPerson(name: "Mara Beispiel", role: "Team-Lead Backend")
            contact.email = "mara.beispiel@nordlicht.example"
            // Keine potenziell echte Rufnummer in öffentlichen Demos.
            contact.phone = ""
            nordlicht.contacts.append(contact)

            let interview = ApplicationEvent(kind: .interview, start: day(3, 14), durationMinutes: 60)
            interview.location = "Hamburg, Hafenstraße 12"
            interview.meetingURLString = "https://meet.example.com/nordlicht-interview"
            interview.checklist = [
                ChecklistItem(text: "Unternehmen und Produkt recherchiert", isDone: true),
                ChecklistItem(text: "Beispiele für Architekturentscheidungen vorbereiten"),
                ChecklistItem(text: "Gehaltsvorstellung klären"),
            ]
            interview.questions = [
                "Wie sieht ein typischer Release-Zyklus aus?",
                "Wie ist das Team aufgebaut?",
            ]
            interview.contact = contact
            nordlicht.events.append(interview)
        }
        if let probe = entries.first(where: { $0.company == "Probe Robotics" }) {
            let call = ApplicationEvent(kind: .phone, start: day(1, 10), durationMinutes: 30)
            call.checklist = [ChecklistItem(text: "Lebenslauf bereithalten")]
            probe.events.append(call)
        }
        if let testwerk = entries.first(where: { $0.company == "Testwerk GmbH" }) {
            let past = ApplicationEvent(kind: .technical, start: day(-12, 11), durationMinutes: 90)
            past.debrief = "## Eindruck\n- Fachlich fundiert, gute Fragen\n- Teamgröße etwa 8 Personen"
            testwerk.events.append(past)
            let trial = ApplicationEvent(kind: .trial, start: day(9, 9), durationMinutes: 240)
            trial.location = "Stuttgart, Büro"
            testwerk.events.append(trial)
        }
    }

    private static func make(
        _ company: String, _ position: String, _ status: ApplicationStatus,
        location: String, model: WorkModel, source: ApplicationSource,
        priority: Priority = .medium, applied: Date? = nil, followUp: Date? = nil,
        salary: (Int, Int)? = nil, tags: [String] = [], notes: String = "",
        history: [(Int, ApplicationStatus)] = [], note: (Int, String)? = nil,
        day: (Int, Int) -> Date
    ) -> JobApplication {
        let application = JobApplication(company: company, position: position, status: status)
        application.createdAt = applied ?? day(0, 9)
        application.location = location
        application.workModel = model
        application.source = source
        application.priority = priority
        application.appliedOn = applied
        application.followUpOn = followUp
        application.salaryMin = salary?.0
        application.salaryMax = salary?.1
        application.tags = tags
        application.notes = notes

        var previous = ApplicationStatus.wishlist
        for (offset, next) in history {
            application.timeline.append(
                TimelineEntry(kind: .statusChanged, date: day(offset, 9), from: previous, to: next)
            )
            previous = next
        }
        if let note {
            application.timeline.append(TimelineEntry(kind: .note, date: day(note.0, 15), text: note.1))
        }
        return application
    }
}
