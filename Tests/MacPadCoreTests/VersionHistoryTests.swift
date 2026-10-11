import XCTest
@testable import MacPadCore

final class VersionHistoryTests: XCTestCase {
    private var directory: URL!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testDefaultCountAndAgeLimitsKeepLatestTwentyVersions() throws {
        let store = VersionHistoryStore(directory: directory.appendingPathComponent("History"))
        let source = directory.appendingPathComponent("note.txt")
        for index in 0..<22 {
            try store.record(Data("verze \(index)".utf8), source: source, encoding: .utf8, now: now.addingTimeInterval(Double(index)))
        }
        let versions = try store.versions(for: source, now: now.addingTimeInterval(22))
        XCTAssertEqual(versions.count, 20)
        XCTAssertEqual(versions.first?.data, Data("verze 21".utf8))
        XCTAssertEqual(versions.last?.data, Data("verze 2".utf8))
        try store.pruneExpired(now: now.addingTimeInterval(31 * 86_400))
        XCTAssertTrue(try store.versions(for: source, now: now.addingTimeInterval(31 * 86_400)).isEmpty)
    }

    func testGlobalByteBudgetRemovesOldestAcrossFiles() throws {
        let store = VersionHistoryStore(directory: directory, maximumVersions: 20, maximumBytes: 1500, maximumAge: 86_400)
        let first = directory.appendingPathComponent("first.txt")
        let second = directory.appendingPathComponent("second.txt")
        let third = directory.appendingPathComponent("third.txt")
        try store.record(Data([1]), source: first, encoding: nil, now: now)
        try store.record(Data(repeating: 2, count: 600), source: second, encoding: nil, now: now.addingTimeInterval(1))
        try store.record(Data(repeating: 3, count: 600), source: third, encoding: nil, now: now.addingTimeInterval(2))
        XCTAssertTrue(try store.versions(for: first, now: now).isEmpty)
        XCTAssertTrue(try store.versions(for: second, now: now).isEmpty)
        XCTAssertEqual(try store.versions(for: third, now: now).count, 1)
        let bytes = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).reduce(0) {
            $0 + (try Data(contentsOf: $1).count)
        }
        XCTAssertLessThanOrEqual(bytes, 1500)
        XCTAssertThrowsError(try store.record(Data(repeating: 0, count: 1501), source: first, encoding: nil, now: now))
        XCTAssertEqual(try store.versions(for: third, now: now).count, 1)
    }

    func testClearFileAndAllPreserveDocumentsAndRemoveInterruptedArchive() throws {
        let history = directory.appendingPathComponent("History")
        let store = VersionHistoryStore(directory: history)
        let first = directory.appendingPathComponent("first.txt")
        let second = directory.appendingPathComponent("second.txt")
        try Data("current".utf8).write(to: first)
        try store.record(Data("first old".utf8), source: first, encoding: .utf8, now: now)
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: history, includingPropertiesForKeys: nil).first)
        let interrupted = file.deletingPathExtension().appendingPathExtension("tmp")
        try Data("partial archive".utf8).write(to: interrupted)
        try store.clear(source: first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: interrupted.path))
        try store.record(Data("second old".utf8), source: second, encoding: .utf8, now: now)
        XCTAssertTrue(try store.versions(for: first, now: now).isEmpty)
        XCTAssertEqual(try store.versions(for: second, now: now).count, 1)
        try store.clear()
        XCTAssertTrue(try store.versions(for: second, now: now).isEmpty)
        XCTAssertEqual(try String(contentsOf: first), "current")
    }

    func testCorruptArchiveIsReportedAndCanBeExplicitlyDeleted() throws {
        let store = VersionHistoryStore(directory: directory)
        let source = directory.appendingPathComponent("note.txt")
        try store.record(Data("old".utf8), source: source, encoding: .utf8, now: now)
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
        try Data("broken".utf8).write(to: file)
        XCTAssertThrowsError(try store.versions(for: source, now: now))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        try store.clear(source: source)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testStartupMaintenanceRemovesInterruptedArchivesWithoutAnotherSave() throws {
        let store = VersionHistoryStore(directory: directory)
        let source = directory.appendingPathComponent("note.txt")
        try store.record(Data("complete".utf8), source: source, encoding: .utf8, now: now)
        let complete = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
        let interrupted = complete.deletingPathExtension().appendingPathExtension("tmp")
        try Data("partial private text".utf8).write(to: interrupted)
        try VersionHistoryStore(directory: directory).pruneExpired(now: now.addingTimeInterval(1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: interrupted.path))
        XCTAssertEqual(try store.versions(for: source, now: now).count, 1)
    }

    func testWriterProvidesOnlyReplacedBytesAfterSuccessfulChange() throws {
        let url = directory.appendingPathComponent("note.txt")
        let format = TextFormat(encoding: .utf8, lineEnding: .crlf)
        var captured: [Data] = []
        let capture: (Result<Data, Error>) -> Void = { result in
            switch result {
            case .success(let data): captured.append(data)
            case .failure(let error): XCTFail("\(error)")
            }
        }
        let first = try TextFileStore.write("původní\n", format: format, to: url, expected: .missing, preservePrevious: capture)
        XCTAssertTrue(captured.isEmpty)
        let same = try TextFileStore.write("původní\n", format: format, to: url, expected: first, preservePrevious: capture)
        XCTAssertTrue(captured.isEmpty)
        _ = try TextFileStore.write("nový\n", format: format, to: url, expected: same, preservePrevious: capture)
        XCTAssertEqual(captured, [Data("původní\r\n".utf8)])
        XCTAssertThrowsError(try TextFileStore.write("not saved", format: format, to: url, expected: first, preservePrevious: capture))
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(try Data(contentsOf: url), Data("nový\r\n".utf8))
    }
}
