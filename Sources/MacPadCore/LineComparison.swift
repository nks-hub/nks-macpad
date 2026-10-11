import Foundation

public struct LineComparison: Sendable {
    public let localLines: [String]
    public let diskLines: [String]
    public let localChanges: Set<Int>
    public let diskChanges: Set<Int>

    public init(local: String, disk: String) {
        localLines = local.components(separatedBy: "\n")
        diskLines = disk.components(separatedBy: "\n")
        let changes = diskLines.difference(from: localLines) { $0.utf8.elementsEqual($1.utf8) }
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in changes {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        localChanges = removed
        diskChanges = inserted
    }

    public func annotatedLocal() -> String { annotated(localLines, changes: localChanges, marker: "−") }
    public func annotatedDisk() -> String { annotated(diskLines, changes: diskChanges, marker: "+") }

    private func annotated(_ lines: [String], changes: Set<Int>, marker: String) -> String {
        lines.enumerated().map { index, line in
            "\(changes.contains(index) ? marker : " ") \(index + 1)  \(line)"
        }.joined(separator: "\n")
    }
}
