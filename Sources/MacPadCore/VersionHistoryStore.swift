import Foundation
import CryptoKit

public struct HistoricalVersion: Codable, Sendable {
    public let id: UUID
    public let archivedAt: Date
    public let encoding: TextEncoding?
    public let data: Data
}

public enum VersionHistoryError: Error {
    case invalidEntry
    case unsupportedVersion
    case tooLarge
}

/// Accessed on the same serial queue as document saves and history deletion.
public final class VersionHistoryStore {
    private let directory: URL
    private let maximumVersions: Int
    private let maximumBytes: Int
    private let maximumAge: TimeInterval
    private let manager = FileManager.default

    private struct Record: Codable {
        let schema: Int
        let version: HistoricalVersion
    }

    private struct Stored {
        let url: URL
        let key: String
        let version: HistoricalVersion
        let bytes: Int
    }

    public convenience init(directory: URL) {
        self.init(directory: directory, maximumVersions: 20, maximumBytes: 100 * 1_048_576, maximumAge: 30 * 86_400)
    }

    init(directory: URL, maximumVersions: Int, maximumBytes: Int, maximumAge: TimeInterval) {
        self.directory = directory
        self.maximumVersions = maximumVersions
        self.maximumBytes = maximumBytes
        self.maximumAge = maximumAge
    }

    public func record(_ data: Data, source: URL, encoding: TextEncoding?, now: Date = Date()) throws {
        guard data.count <= maximumBytes else { throw VersionHistoryError.tooLarge }
        let version = HistoricalVersion(id: UUID(), archivedAt: now, encoding: encoding, data: data)
        let encoded = try JSONEncoder().encode(Record(schema: 1, version: version))
        guard encoded.count <= maximumBytes else { throw VersionHistoryError.tooLarge }
        var stored = try load()
        try prepareDirectory()
        let destination = directory.appendingPathComponent("\(key(source))-\(version.id.uuidString).json")
        let temporary = destination.deletingPathExtension().appendingPathExtension("tmp")
        defer { try? manager.removeItem(at: temporary) }
        try TextFileStore.writeTemporary(encoded, to: temporary, mode: 0o600)
        try manager.moveItem(at: temporary, to: destination)
        stored.append(Stored(url: destination, key: key(source), version: version, bytes: encoded.count))
        _ = try prune(stored, now: now)
    }

    public func versions(for source: URL, now: Date = Date()) throws -> [HistoricalVersion] {
        try prune(load(), now: now).filter { $0.key == key(source) }.map(\.version)
    }

    public func pruneExpired(now: Date = Date()) throws { _ = try prune(load(), now: now) }

    public func clear(source: URL? = nil) throws {
        let selectedKey = source.map(key)
        for url in try files() {
            guard let recordKey = recordKey(url), selectedKey == nil || selectedKey == recordKey else { continue }
            let type = try manager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
            guard type == .typeRegular || type == .typeSymbolicLink else { throw VersionHistoryError.invalidEntry }
            try manager.removeItem(at: url)
        }
    }

    private func key(_ source: URL) -> String {
        let path = source.resolvingSymlinksInPath().standardizedFileURL.path
        return SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func files() throws -> [URL] {
        do {
            let attributes = try manager.attributesOfItem(atPath: directory.path)
            guard attributes[.type] as? FileAttributeType == .typeDirectory else { throw VersionHistoryError.invalidEntry }
            return try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain &&
            (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError) {
            return []
        }
    }

    private func recordKey(_ url: URL) -> String? {
        let name = url.deletingPathExtension().lastPathComponent
        guard ["json", "tmp"].contains(url.pathExtension), name.count == 101 else { return nil }
        let prefix = String(name.prefix(64))
        guard prefix.allSatisfy({ "0123456789abcdef".contains($0) }),
              name.dropFirst(64).first == "-", UUID(uuidString: String(name.suffix(36))) != nil else { return nil }
        return prefix
    }

    private func load() throws -> [Stored] {
        try removeInterruptedArchives()
        var stored: [Stored] = []
        for url in try files() {
            guard url.pathExtension == "json", let key = recordKey(url) else { continue }
            let attributes = try manager.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber, size.intValue <= maximumBytes else {
                throw VersionHistoryError.invalidEntry
            }
            let data = try Data(contentsOf: url)
            let record = try JSONDecoder().decode(Record.self, from: data)
            guard record.schema == 1 else { throw VersionHistoryError.unsupportedVersion }
            guard url.lastPathComponent == "\(key)-\(record.version.id.uuidString).json",
                  record.version.archivedAt.timeIntervalSince1970.isFinite else { throw VersionHistoryError.invalidEntry }
            stored.append(Stored(url: url, key: key, version: record.version, bytes: data.count))
        }
        return stored
    }

    private func prepareDirectory() throws {
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    private func removeInterruptedArchives() throws {
        for url in try files() where url.pathExtension == "tmp" && recordKey(url) != nil {
            let type = try manager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
            if type == .typeRegular || type == .typeSymbolicLink { try manager.removeItem(at: url) }
        }
    }

    private func prune(_ records: [Stored], now: Date) throws -> [Stored] {
        let ordered = records.sorted {
            if $0.version.archivedAt != $1.version.archivedAt { return $0.version.archivedAt > $1.version.archivedAt }
            return $0.version.id.uuidString > $1.version.id.uuidString
        }
        var counts: [String: Int] = [:]
        var bytes = 0
        var budgetReached = false
        var kept: [Stored] = []
        for record in ordered {
            if now.timeIntervalSince(record.version.archivedAt) > maximumAge || counts[record.key, default: 0] >= maximumVersions {
                try manager.removeItem(at: record.url)
            } else if budgetReached || bytes + record.bytes > maximumBytes {
                budgetReached = true
                try manager.removeItem(at: record.url)
            } else {
                counts[record.key, default: 0] += 1
                bytes += record.bytes
                kept.append(record)
            }
        }
        return kept
    }
}
