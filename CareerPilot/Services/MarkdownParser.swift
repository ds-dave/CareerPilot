import Foundation

/// Ein Block eines Markdown-Textes. Bewusst klein gehalten: genug für Notizen,
/// ohne eine ganze Markdown-Bibliothek einzubinden.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(text: String, checked: Bool?)
    case numbered(number: Int, text: String)
    case quote(String)
    case rule
}

enum MarkdownParser {
    static func blocks(from source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph = []
        }

        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
            } else if let heading = parseHeading(line) {
                flushParagraph()
                blocks.append(heading)
            } else if line == "---" || line == "***" || line == "___" {
                flushParagraph()
                blocks.append(.rule)
            } else if let bullet = parseBullet(line) {
                flushParagraph()
                blocks.append(bullet)
            } else if let numbered = parseNumbered(line) {
                flushParagraph()
                blocks.append(numbered)
            } else if line.hasPrefix(">") {
                flushParagraph()
                blocks.append(.quote(String(line.dropFirst()).trimmingCharacters(in: .whitespaces)))
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        return blocks
    }

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...3).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : .heading(level: hashes.count, text: text)
    }

    private static func parseBullet(_ line: String) -> MarkdownBlock? {
        guard let marker = line.first, "-*+".contains(marker), line.dropFirst().first == " " else { return nil }
        var text = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        var checked: Bool?
        if text.hasPrefix("[ ] ") || text == "[ ]" {
            checked = false
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if text.lowercased().hasPrefix("[x] ") || text.lowercased() == "[x]" {
            checked = true
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        return .bullet(text: text, checked: checked)
    }

    private static func parseNumbered(_ line: String) -> MarkdownBlock? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return .numbered(number: number, text: rest.dropFirst(2).trimmingCharacters(in: .whitespaces))
    }
}
