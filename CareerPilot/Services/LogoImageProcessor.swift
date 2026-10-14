import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Macht aus beliebigen Bildern (Screenshot, Foto, Datei) ein kleines, einheitliches Logo.
/// Das Ergebnis ist ein PNG mit höchstens 256 Pixeln an der längsten Seite; Transparenz bleibt erhalten.
enum LogoImageProcessor {
    static let maxInputBytes = 25 * 1_048_576
    /// Grenze pro Seite, damit ein präpariertes Riesenbild nicht den Speicher füllt.
    static let maxInputPixels = 8_000
    static let outputSide = 256

    /// Gibt `nil` zurück, wenn die Daten kein lesbares Bild sind oder zu groß ausfallen.
    static func normalized(_ data: Data) -> Data? {
        guard !data.isEmpty, data.count <= maxInputBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= maxInputPixels, height <= maxInputPixels
        else { return nil }

        // Kleine Bilder werden nicht hochskaliert.
        let target = min(outputSide, max(width, height))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: target,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Pixelmaße eines normalisierten Logos, für Tests und Anzeige.
    static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }
}

/// Liest ein Bild aus der Zwischenablage: Screenshots (PNG/TIFF), JPEGs oder im Finder kopierte Bilddateien.
@MainActor
enum LogoPasteboard {
    static func imageData(from pasteboard: NSPasteboard = .general) -> Data? {
        for type in [NSPasteboard.PasteboardType.png, .tiff, NSPasteboard.PasteboardType("public.jpeg")] {
            if let data = pasteboard.data(forType: type), !data.isEmpty {
                return data
            }
        }
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier],
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           let url = urls.first {
            return data(from: url)
        }
        return nil
    }

    /// Liest eine Bilddatei, die der Nutzer ausgewählt oder hineingezogen hat.
    static func data(from url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > LogoImageProcessor.maxInputBytes {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static var hasImage: Bool {
        imageData() != nil
    }
}
