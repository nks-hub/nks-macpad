import Foundation

public enum TextOperations {
    public static func sortedLines(_ text: String, locale: Locale) -> String {
        transformLines(text) { lines in
            lines.enumerated().sorted { left, right in
                let comparison = left.element.compare(right.element, locale: locale)
                return comparison == .orderedSame ? left.offset < right.offset : comparison == .orderedAscending
            }.map(\.element)
        }
    }

    public static func uniqueLines(_ text: String) -> String {
        transformLines(text) { lines in
            // String equality merges canonically equivalent but byte-distinct text.
            var seen = Set<Data>()
            return lines.filter { seen.insert(Data($0.utf8)).inserted }
        }
    }

    private static func transformLines(_ text: String, transform: ([String]) -> [String]) -> String {
        guard !text.isEmpty else { return text }
        let trailingNewline = text.hasSuffix("\n")
        var lines = text.components(separatedBy: "\n")
        if trailingNewline { lines.removeLast() }
        return transform(lines).joined(separator: "\n") + (trailingNewline ? "\n" : "")
    }
}
