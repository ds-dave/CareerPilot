import AppKit
import UniformTypeIdentifiers

/// Holt Bilddaten aus Drag & Drop. Das Einfügen aus der Zwischenablage läuft über `LogoPasteboard`.
@MainActor
enum LogoImporter {
    /// Liest das erste Bild aus den abgelegten Objekten: direkte Bilddaten oder eine Bilddatei.
    static func imageData(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor @Sendable (Data?) -> Void
    ) {
        let imageType = UTType.image.identifier
        let fileType = UTType.fileURL.identifier

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(imageType) }) {
            provider.loadDataRepresentation(forTypeIdentifier: imageType) { data, _ in
                Task { @MainActor in completion(data) }
            }
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(fileType) }) {
            provider.loadItem(forTypeIdentifier: fileType, options: nil) { item, _ in
                var url: URL?
                if let direct = item as? URL {
                    url = direct
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                }
                let data = url.flatMap { try? Data(contentsOf: $0) }
                Task { @MainActor in completion(data) }
            }
        } else {
            completion(nil)
        }
    }
}
