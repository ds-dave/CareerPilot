import AppKit
import SwiftUI

/// Hält die dekodierten Logos vor, damit Listen beim Scrollen nicht ständig PNGs entpacken.
@MainActor
private enum LogoImageCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for data: Data, id: UUID) -> NSImage? {
        let key = "\(id.uuidString)-\(data.count)-\(data.hashValue)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Das Logo einer Firma als kleines abgerundetes Quadrat. Ohne Logo steht dort der Anfangsbuchstabe.
struct CompanyLogoView: View {
    let application: JobApplication
    var size: CGFloat = 32

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        Group {
            if let data = application.logoData,
               let image = LogoImageCache.image(for: data, id: application.uuid) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.1)
                    .frame(width: size, height: size)
                    .background(Color.white)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(.quaternary)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    private var initial: String {
        let trimmed = application.company.trimmingCharacters(in: .whitespaces)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }
}
