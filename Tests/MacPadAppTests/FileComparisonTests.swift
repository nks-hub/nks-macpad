import AppKit
import XCTest
import MacPadCore

final class FileComparisonTests: XCTestCase {
    private var app: AppDelegate?
    private var directory: URL?

    @MainActor
    private func makeComparison(encoding: TextEncoding = .utf8) async throws -> FileComparisonWindow {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("note.txt")
        try TextFileCodec.encode("původní\n", format: TextFormat(encoding: encoding, lineEnding: .crlf)).write(to: url)
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        self.app = app
        let editor = app.makeWindow()
        let note = TextDocument()
        try note.load(url, encoding: encoding)
        editor.addNote(note)
        note.changed(to: "moje 😀\n")
        editor.reload(note)
        try TextFileCodec.encode("externí\n", format: TextFormat(encoding: encoding, lineEnding: .lf)).write(to: url)
        editor.showComparison(note)
        let comparison = try XCTUnwrap(editor.comparisonWindow)
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in comparison.comparison != nil }, object: nil)
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertFalse(comparison.stale)
        return comparison
    }

    @MainActor
    private func finish() {
        app?.editors.forEach { $0.comparisonWindow?.close(); $0.window?.orderOut(nil) }
        app = nil
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    @MainActor
    func testReadOnlyComparisonPreservesBothVersionsAndFormats() async throws {
        defer { finish() }
        let window = try await makeComparison()
        let value = try XCTUnwrap(window.comparison)
        XCTAssertFalse(window.localText.isEditable)
        XCTAssertFalse(window.diskText.isEditable)
        XCTAssertTrue(window.localText.string.contains("− 1  moje 😀"))
        XCTAssertTrue(window.diskText.string.contains("+ 1  externí"))
        XCTAssertEqual(value.format.lineEnding, .crlf)
        XCTAssertEqual(value.disk.format.lineEnding, .lf)
        XCTAssertEqual(window.note.text, "moje 😀\n")
        XCTAssertEqual(try Data(contentsOf: value.url), Data("externí\n".utf8))
        window.window?.contentView?.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(window.localText.enclosingScrollView?.frame.height ?? 0, 200)
    }

    @MainActor
    func testChangingSaveEncodingDoesNotChangeDiskDecoding() async throws {
        for encoding in [TextEncoding.utf8, .windows1250] {
            defer { finish() }
            let window = try await makeComparison(encoding: encoding)
            window.note.format.encoding = encoding == .utf8 ? .windows1250 : .utf8
            window.refresh(nil)
            let fresh = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !window.stale }, object: nil)
            await fulfillment(of: [fresh], timeout: 3)
            XCTAssertEqual(window.comparison?.disk.text, "externí\n")
            XCTAssertEqual(window.comparison?.disk.format.encoding, encoding)
        }
    }

    @MainActor
    func testDiskChangeInvalidatesOverwriteAndKeepsNewerFile() async throws {
        defer { finish() }
        let window = try await makeComparison()
        let url = try XCTUnwrap(window.note.fileURL)
        try Data("novější disk\n".utf8).write(to: url)
        let finished = expectation(description: "Stale overwrite rejected")
        window.apply(overwriting: true) { ok in XCTAssertFalse(ok); finished.fulfill() }
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertTrue(window.stale)
        XCTAssertEqual(try String(contentsOf: url), "novější disk\n")
        XCTAssertEqual(window.note.text, "moje 😀\n")
    }

    @MainActor
    func testLocalEditAndFormatChangeInvalidateReload() async throws {
        defer { finish() }
        let window = try await makeComparison()
        window.note.format.lineEnding = .lf
        window.apply(overwriting: false) { ok in XCTAssertFalse(ok) }
        XCTAssertTrue(window.stale)
        window.note.format.lineEnding = .crlf
        window.refresh(nil)
        let fresh = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !window.stale }, object: nil)
        await fulfillment(of: [fresh], timeout: 3)
        window.note.changed(to: "novější koncept")
        window.apply(overwriting: false) { ok in XCTAssertFalse(ok) }
        XCTAssertTrue(window.stale)
        XCTAssertEqual(window.note.text, "novější koncept")
    }

    @MainActor
    func testConfirmedOverwriteUsesReviewedStampAndPreservesCRLF() async throws {
        defer { finish() }
        let window = try await makeComparison()
        let finished = expectation(description: "Reviewed version overwritten")
        window.apply(overwriting: true) { ok in XCTAssertTrue(ok); finished.fulfill() }
        await fulfillment(of: [finished], timeout: 3)
        let url = try XCTUnwrap(window.note.fileURL)
        XCTAssertEqual(try Data(contentsOf: url), Data("moje 😀\r\n".utf8))
        XCTAssertFalse(window.note.isDocumentEdited)
        XCTAssertEqual(window.note.stamp, try TextFileStore.stamp(url))
    }

    @MainActor
    func testConfirmedReloadUsesDisplayedTextAndDiskFormat() async throws {
        defer { finish() }
        let window = try await makeComparison()
        let finished = expectation(description: "Reviewed version reloaded")
        window.apply(overwriting: false) { ok in XCTAssertTrue(ok); finished.fulfill() }
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(window.note.text, "externí\n")
        XCTAssertEqual(window.note.format.lineEnding, .lf)
        XCTAssertFalse(window.note.isDocumentEdited)
        XCTAssertEqual(app?.editors.first?.textView?.string, "externí\n")
    }
}
