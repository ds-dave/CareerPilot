import AppKit
import Foundation
import SwiftData
import Testing

@testable import CareerPilot

/// Der Rückgängig-Hinweis verlässt sich darauf, dass SwiftData Löschen, Verschieben und Logo-Änderungen
/// über den UndoManager zurücknimmt. Das prüfen diese Tests.
@MainActor
@Suite("Rückgängig")
struct UndoTests {
    private func makeContext() throws -> (ModelContainer, ModelContext, UndoManager) {
        let container = try AppSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        let undo = UndoManager()
        undo.groupsByEvent = false
        context.undoManager = undo
        return (container, context, undo)
    }

    private func perform(_ undo: UndoManager, _ change: () -> Void) {
        undo.beginUndoGrouping()
        change()
        undo.endUndoGrouping()
    }

    @Test("Eine gelöschte Bewerbung kommt mit Terminen und Verlauf zurück")
    func deleteIsUndoable() throws {
        let (container, context, undo) = try makeContext()
        _ = container
        let item = JobApplication(company: "Firma", position: "Dev", status: .interview)
        item.events.append(ApplicationEvent(kind: .interview, start: .now))
        item.timeline.append(TimelineEntry(kind: .note, text: "Hallo"))
        context.insert(item)
        try context.save()
        undo.removeAllActions()

        perform(undo) { context.delete(item) }
        #expect(try context.fetchCount(FetchDescriptor<JobApplication>()) == 0)

        undo.undo()
        let restored = try context.fetch(FetchDescriptor<JobApplication>())
        #expect(restored.count == 1)
        #expect(restored.first?.company == "Firma")
        #expect(restored.first?.events.count == 1)
        #expect(restored.first?.timeline.count == 1)
    }

    @Test("Ein Verschieben im Board lässt sich zurücknehmen")
    func moveIsUndoable() throws {
        let (container, context, undo) = try makeContext()
        _ = container
        let item = JobApplication(company: "Firma", position: "Dev", status: .wishlist)
        context.insert(item)
        try context.save()
        undo.removeAllActions()

        perform(undo) { BoardOrdering.move(item, to: .interview, among: [item]) }
        #expect(item.status == .interview)

        undo.undo()
        #expect(item.status == .wishlist)
    }

    @Test("Ein gesetztes Logo lässt sich zurücknehmen")
    func logoIsUndoable() throws {
        let (container, context, undo) = try makeContext()
        _ = container
        let item = JobApplication(company: "Firma", position: "Dev")
        context.insert(item)
        try context.save()
        undo.removeAllActions()

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let png = rep.representation(using: .png, properties: [:])!

        perform(undo) { item.setLogo(from: png) }
        #expect(item.logoData != nil)

        undo.undo()
        #expect(item.logoData == nil)
    }
}
