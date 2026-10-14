import Foundation
import SwiftData
import Testing

@testable import CareerPilot

@MainActor
@Suite("Öffentliche Demo")
struct SampleDataTests {
    @Test("Beispieldaten bleiben vollständig im temporären Speicher und sind exportierbar")
    func demoRoundTrip() throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        SampleData.insert(into: context, now: now)
        try context.save()
        let applications = try context.fetch(FetchDescriptor<JobApplication>())
        #expect(applications.count == 12)
        #expect(applications.flatMap(\.contacts).allSatisfy { $0.phone.isEmpty && $0.email.hasSuffix(".example") })
        #expect(applications.allSatisfy { $0.appliedOn == nil || $0.createdAt <= $0.appliedOn! })
        let backup = BackupCodec.makeBackup(from: applications, now: now)
        let decoded = try BackupCodec.decode(BackupCodec.encode(backup))
        let destination = try AppSchema.makeContainer(inMemory: true)
        #expect(BackupCodec.restore(decoded, into: destination.mainContext, existing: []).added == 12)
        #expect(try destination.mainContext.fetchCount(FetchDescriptor<ApplicationEvent>()) == 4)
    }

    @Test("Deaktivierte Systemerinnerungen bleiben auch bei Berechtigungsanfrage inaktiv")
    func inactiveNotifications() async {
        let scheduler = NotificationScheduler(isActive: false)
        let authorized = await scheduler.requestAuthorization()
        #expect(!authorized)
        await scheduler.apply([])
        #expect(scheduler.authorization == .unknown)
    }
}
