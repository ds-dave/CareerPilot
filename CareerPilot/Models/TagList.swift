import Foundation

/// Regeln für Tags: getrimmt, ohne Doppelte (Groß-/Kleinschreibung egal), begrenzte Länge.
enum TagList {
    static let maxLength = 30

    /// Bereinigt einen einzelnen Tag. Leere Eingaben ergeben `nil`.
    static func clean(_ raw: String) -> String? {
        let collapsed = raw
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "#,;"))
            .trimmingCharacters(in: .whitespaces)
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maxLength))
    }

    /// Fügt Tags hinzu. Eingaben dürfen durch Komma oder Semikolon getrennt sein.
    static func adding(_ input: String, to tags: [String]) -> [String] {
        var result = tags
        for part in input.split(whereSeparator: { $0 == "," || $0 == ";" }) {
            guard let tag = clean(String(part)) else { continue }
            if !result.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
                result.append(tag)
            }
        }
        return result
    }

    static func contains(_ tags: [String], _ tag: String) -> Bool {
        tags.contains { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }
    }
}
