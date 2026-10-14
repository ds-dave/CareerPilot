import AppKit
import Foundation
import SwiftData
import Testing

@testable import CareerPilot

/// Erzeugt ein einfarbiges PNG in der gewünschten Größe.
private func png(width: Int, height: Int, transparent: Bool = false) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    (transparent ? NSColor.clear : NSColor.systemBlue).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

@Suite("Logo")
struct LogoTests {
    @Test("Große Bilder werden auf 256 Pixel verkleinert, das Seitenverhältnis bleibt")
    func downscales() throws {
        let result = try #require(LogoImageProcessor.normalized(png(width: 1_200, height: 600)))
        let size = try #require(LogoImageProcessor.pixelSize(of: result))
        #expect(size.width == 256)
        #expect(size.height == 128)
    }

    @Test("Kleine Bilder werden nicht hochskaliert")
    func keepsSmall() throws {
        let result = try #require(LogoImageProcessor.normalized(png(width: 40, height: 40)))
        let size = try #require(LogoImageProcessor.pixelSize(of: result))
        #expect(size.width == 40)
        #expect(size.height == 40)
    }

    @Test("Das Ergebnis ist ein PNG")
    func outputIsPNG() throws {
        let result = try #require(LogoImageProcessor.normalized(png(width: 300, height: 300)))
        #expect(result.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    @Test("Kein Bild, leer oder zu groß wird abgelehnt")
    func rejects() {
        #expect(LogoImageProcessor.normalized(Data("kein Bild".utf8)) == nil)
        #expect(LogoImageProcessor.normalized(Data()) == nil)
        #expect(LogoImageProcessor.normalized(Data(count: LogoImageProcessor.maxInputBytes + 1)) == nil)
    }

    @Test("Zu viele Pixel werden abgelehnt")
    func rejectsHugeDimensions() {
        let huge = png(width: LogoImageProcessor.maxInputPixels + 1, height: 1)
        #expect(LogoImageProcessor.normalized(huge) == nil)
    }

    @Test("Ein Logo setzen ersetzt das alte, ein ungültiges lässt es unverändert")
    func setLogo() throws {
        let item = JobApplication(company: "Firma", position: "Dev")
        #expect(item.logoData == nil)
        #expect(item.setLogo(from: png(width: 64, height: 64)))
        let first = try #require(item.logoData)

        #expect(!item.setLogo(from: Data("nein".utf8)))
        #expect(item.logoData == first)

        #expect(item.setLogo(from: png(width: 80, height: 40)))
        #expect(item.logoData != first)
    }

    @Test("Eine Kopie übernimmt das Logo")
    func duplicateKeepsLogo() {
        let item = JobApplication(company: "Firma", position: "Dev")
        item.setLogo(from: png(width: 64, height: 64))
        #expect(item.duplicated().logoData == item.logoData)
    }

    @Test("Das Logo übersteht Speichern und Backup")
    @MainActor
    func persistenceAndBackup() throws {
        let sourceContainer = try AppSchema.makeContainer(inMemory: true)
        let item = JobApplication(company: "Firma", position: "Dev")
        item.setLogo(from: png(width: 128, height: 64, transparent: true))
        sourceContainer.mainContext.insert(item)
        try sourceContainer.mainContext.save()

        let fetched = try #require(try sourceContainer.mainContext.fetch(FetchDescriptor<JobApplication>()).first)
        #expect(fetched.logoData == item.logoData)

        let file = try BackupCodec.decode(BackupCodec.encode(BackupCodec.makeBackup(from: [item])))
        let targetContainer = try AppSchema.makeContainer(inMemory: true)
        BackupCodec.restore(file, into: targetContainer.mainContext, existing: [])
        let restored = try #require(try targetContainer.mainContext.fetch(FetchDescriptor<JobApplication>()).first)
        #expect(restored.logoData == item.logoData)

        let withoutLogos = BackupCodec.makeBackup(from: [item], includeDocuments: false)
        #expect(withoutLogos.applications.first?.logo == nil)
    }

    @Test("Ungültige Logodaten im Backup werden ignoriert")
    @MainActor
    func backupWithBrokenLogo() throws {
        var record = ApplicationRecord(uuid: UUID(), company: "Firma", position: "Dev", status: .applied, createdAt: .now)
        record.logo = Data("kein bild".utf8)
        let container = try AppSchema.makeContainer(inMemory: true)
        let summary = BackupCodec.restore(BackupFile(exportedAt: .now, applications: [record]),
                                          into: container.mainContext, existing: [])
        #expect(summary.added == 1)
        let restored = try #require(try container.mainContext.fetch(FetchDescriptor<JobApplication>()).first)
        #expect(restored.logoData == nil)
    }
}

@MainActor
@Suite("Logo aus der Zwischenablage")
struct LogoPasteboardTests {
    private func pasteboard() -> NSPasteboard {
        let board = NSPasteboard(name: NSPasteboard.Name("careerpilot.tests.\(UUID().uuidString)"))
        board.clearContents()
        return board
    }

    @Test("Ein Screenshot (PNG) wird gelesen")
    func readsPNG() throws {
        let board = pasteboard()
        defer { board.releaseGlobally() }
        board.setData(png(width: 50, height: 50), forType: .png)
        let data = try #require(LogoPasteboard.imageData(from: board))
        #expect(LogoImageProcessor.normalized(data) != nil)
    }

    @Test("Ein TIFF aus der Bildschirmaufnahme wird gelesen")
    func readsTIFF() throws {
        let board = pasteboard()
        defer { board.releaseGlobally() }
        let image = try #require(NSImage(data: png(width: 30, height: 20)))
        board.setData(try #require(image.tiffRepresentation), forType: .tiff)
        let data = try #require(LogoPasteboard.imageData(from: board))
        #expect(LogoImageProcessor.normalized(data) != nil)
    }

    @Test("Eine kopierte Bilddatei wird gelesen")
    func readsFileURL() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cp-logo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("logo.png")
        try png(width: 64, height: 64).write(to: file)

        let board = pasteboard()
        defer { board.releaseGlobally() }
        board.writeObjects([file as NSURL])
        let data = try #require(LogoPasteboard.imageData(from: board))
        #expect(LogoImageProcessor.normalized(data) != nil)
    }

    @Test("Text in der Zwischenablage ist kein Logo")
    func ignoresText() {
        let board = pasteboard()
        defer { board.releaseGlobally() }
        board.setString("Hallo", forType: .string)
        #expect(LogoPasteboard.imageData(from: board) == nil)
    }
}
