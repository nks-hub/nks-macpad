import AppKit
import XCTest
import MacPadCore

final class VersionHistoryAppTests: XCTestCase {
    private var app: AppDelegate?
    private var directory: URL?
    private var oldPreference: Any?

    @MainActor
    private func fixture(enabled: Bool) throws -> TextDocument {
        _ = NSApplication.shared
        oldPreference = UserDefaults.standard.object(forKey: "versionHistory")
        Preferences.history = enabled
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("note.txt")
        try Data("Původní 😀\r\n".utf8).write(to: url)
        let app = AppDelegate(sessionDirectory: directory)
        self.app = app
        let editor = app.makeWindow()
        let note = TextDocument()
        try note.load(url)
        editor.addNote(note)
        return note
    }

    @MainActor
    private func finish() {
        app?.editors.forEach { $0.window?.orderOut(nil) }
        app = nil
        UserDefaults.standard.set(oldPreference, forKey: "versionHistory")
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    @MainActor
    func testDisabledHistoryDoesNotCreateArchive() async throws {
        defer { finish() }
        let note = try fixture(enabled: false)
        let app = try XCTUnwrap(app)
        note.changed(to: "Saved without history")
        let saved = expectation(description: "Saved")
        app.save(note) { ok in XCTAssertTrue(ok); saved.fulfill() }
        await fulfillment(of: [saved], timeout: 3)
        XCTAssertTrue(try app.historyStore.versions(for: XCTUnwrap(note.fileURL)).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(directory).appendingPathComponent("History").path))
    }

    @MainActor
    func testRestorationCreatesDraftWithoutChangingSavedOrUnsavedText() async throws {
        defer { finish() }
        let note = try fixture(enabled: true)
        let app = try XCTUnwrap(app)
        let url = try XCTUnwrap(note.fileURL)
        let gate = DispatchSemaphore(value: 0)
        app.diskQueue.async { gate.wait() }
        note.changed(to: "Saved revision\n")
        let saved = expectation(description: "Revision saved")
        app.save(note) { ok in XCTAssertTrue(ok); saved.fulfill() }
        note.changed(to: "Still unsaved\n")
        gate.signal()
        await fulfillment(of: [saved], timeout: 3)
        let versions = try app.historyStore.versions(for: url)
        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions.first?.data, Data("Původní 😀\r\n".utf8))
        let restored = expectation(description: "Historical draft opened")
        app.restoreHistoricalVersion(id: try XCTUnwrap(versions.first?.id), source: url) { draft in
            XCTAssertNotNil(draft)
            XCTAssertNil(draft?.fileURL)
            XCTAssertNotEqual(draft?.id, note.id)
            XCTAssertEqual(draft?.text, "Původní 😀\n")
            XCTAssertEqual(draft?.format.lineEnding, .crlf)
            XCTAssertTrue(draft?.isDocumentEdited == true)
            restored.fulfill()
        }
        await fulfillment(of: [restored], timeout: 3)
        XCTAssertEqual(note.text, "Still unsaved\n")
        XCTAssertEqual(try Data(contentsOf: url), Data("Saved revision\r\n".utf8))
        let cleared = expectation(description: "History cleared")
        app.clearHistory(source: url) { ok in XCTAssertTrue(ok); cleared.fulfill() }
        await fulfillment(of: [cleared], timeout: 3)
        XCTAssertTrue(try app.historyStore.versions(for: url).isEmpty)
        XCTAssertEqual(note.text, "Still unsaved\n")
        XCTAssertEqual(app.editors.first?.notes.count, 2)
    }

    @MainActor
    func testClearingHistoryCancelsPendingRestore() async throws {
        defer { finish() }
        let note = try fixture(enabled: true)
        let app = try XCTUnwrap(app)
        let url = try XCTUnwrap(note.fileURL)
        try app.historyStore.record(Data("old text".utf8), source: url, encoding: .utf8)
        let id = try XCTUnwrap(app.historyStore.versions(for: url).first?.id)
        let gate = DispatchSemaphore(value: 0)
        app.diskQueue.async { gate.wait() }
        let restored = expectation(description: "Restore cancelled")
        app.restoreHistoricalVersion(id: id, source: url) { draft in XCTAssertNil(draft); restored.fulfill() }
        let cleared = expectation(description: "History cleared")
        app.clearHistory(source: url) { ok in XCTAssertTrue(ok); cleared.fulfill() }
        gate.signal()
        await fulfillment(of: [restored, cleared], timeout: 3)
        XCTAssertEqual(app.editors.first?.notes.count, 1)
        XCTAssertTrue(try app.historyStore.versions(for: url).isEmpty)
    }

    @MainActor
    func testArchiveFailureReportsWarningButKeepsSuccessfulFileSave() async throws {
        defer { finish() }
        let note = try fixture(enabled: true)
        let app = try XCTUnwrap(app)
        let directory = try XCTUnwrap(directory)
        try Data("unavailable history directory".utf8).write(to: directory.appendingPathComponent("History"))
        var warningShown = false
        let timer = Timer(timeInterval: 0.01, repeats: true) { _ in
            if let modal = NSApp.modalWindow {
                warningShown = true
                NSApp.stopModal(withCode: .alertFirstButtonReturn)
                modal.orderOut(nil)
            }
        }
        RunLoop.main.add(timer, forMode: .modalPanel)
        defer { timer.invalidate() }
        note.changed(to: "Must be saved")
        let saved = expectation(description: "File saved despite archive failure")
        app.save(note) { ok in XCTAssertTrue(ok); saved.fulfill() }
        await fulfillment(of: [saved], timeout: 5)
        XCTAssertTrue(warningShown)
        XCTAssertNotNil(note.historyFailure)
        XCTAssertFalse(note.isDocumentEdited)
        XCTAssertEqual(try String(contentsOf: XCTUnwrap(note.fileURL)), "Must be saved")
        XCTAssertTrue(app.editors.first?.statusBar.hasWarning == true)
    }
}
