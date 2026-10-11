import AppKit
import XCTest
import MacPadCore

final class LifecycleReviewTests: XCTestCase {
    @MainActor
    func testClosedFileLimitAndReopeningPreserveIdentityAndCursor() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        let editor = app.makeWindow()
        defer { editor.window?.orderOut(nil) }
        var files: [URL] = []
        for index in 0..<22 {
            let url = directory.appendingPathComponent("note-\(index).txt")
            try Data("A😀BCD".utf8).write(to: url)
            files.append(url)
            let note = TextDocument()
            try note.load(url)
            editor.addNote(note, replacingEmpty: true)
            editor.textView?.setSelectedRange(NSRange(location: 1, length: 2))
            editor.closeNote(nil)
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !editor.busyClosing }, object: nil)
            await fulfillment(of: [closed], timeout: 3)
        }
        XCTAssertEqual(app.closedFiles.map(\.0), Array(files.suffix(20)))
        app.reopenClosed(nil)
        let reopened = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.pendingOpenCount == 0 }, object: nil)
        await fulfillment(of: [reopened], timeout: 3)
        let note = try XCTUnwrap(editor.active)
        XCTAssertEqual(note.fileURL?.lastPathComponent, files.last?.lastPathComponent)
        XCTAssertEqual(editor.textView?.selectedRange(), NSRange(location: 1, length: 2))
        editor.textView?.insertText("edited", replacementRange: NSRange(location: 0, length: 0))
        let editedText = note.text
        app.closedFiles.append((try XCTUnwrap(files.last), NSRange(location: 0, length: 0)))
        app.reopenClosed(nil)
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.pendingOpenCount == 0 }, object: nil)
        await fulfillment(of: [selected], timeout: 3)
        XCTAssertTrue(editor.active === note)
        XCTAssertEqual(editor.notes.count, 1)
        XCTAssertEqual(note.text, editedText)
        XCTAssertEqual(try String(contentsOf: XCTUnwrap(files.last), encoding: .utf8), "A😀BCD")
        app.clearRecent(nil)
        XCTAssertTrue(app.closedFiles.isEmpty)
        XCTAssertTrue(NSDocumentController.shared.recentDocumentURLs.isEmpty)
    }

    @MainActor
    func testClosingInactiveTabPersistsRemovalBehindOlderSnapshot() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("closed.txt")
        try Data("closed content".utf8).write(to: file)
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        let editor = app.makeWindow()
        let closed = TextDocument()
        try closed.load(file)
        editor.addNote(closed)
        let active = TextDocument()
        editor.addNote(active)
        let gate = DispatchSemaphore(value: 0)
        app.diskQueue.async { gate.wait() }
        app.flushSession()
        let sender = NSMenuItem()
        sender.representedObject = closed.id
        editor.closeNote(sender)
        XCTAssertTrue(editor.busyClosing)
        gate.signal()
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !editor.busyClosing }, object: nil)
        await fulfillment(of: [finished], timeout: 5)
        let recovered = try app.sessionStore.load()
        XCTAssertFalse(recovered?.windows.flatMap(\.notes).contains { $0.id == closed.id } ?? true)
        XCTAssertEqual(editor.activeID, active.id)
    }

    @MainActor
    func testRepeatedFlushRequestsUseLatestSnapshot() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppDelegate(sessionDirectory: directory)
        let editor = app.makeWindow()
        let note = TextDocument()
        editor.addNote(note)
        let gate = DispatchSemaphore(value: 0)
        app.diskQueue.async { gate.wait() }
        let completed = expectation(description: "Every waiter sees the latest snapshot")
        completed.expectedFulfillmentCount = 20
        for index in 0..<20 {
            note.changed(to: "Revision \(index)")
            app.changed()
            app.flushSession { ok in XCTAssertTrue(ok); completed.fulfill() }
            XCTAssertTrue(app.sessionWriteInFlight)
        }
        gate.signal()
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertFalse(app.sessionWriteInFlight)
        XCTAssertEqual(try app.sessionStore.load()?.windows.first?.notes.first?.text, "Revision 19")
    }

    @MainActor
    func testCancelledOpenSkipsQueuedReadsAndAllowsNextFile() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("small.txt")
        try Data("new request".utf8).write(to: url)
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        app.readQueue.isSuspended = true
        app.open([directory.appendingPathComponent("missing-1.txt"), directory.appendingPathComponent("missing-2.txt")])
        app.cancelOpening(nil)
        app.open([url])
        let finished = expectation(description: "New open completed after cancellation")
        app.readQueue.addBarrierBlock { DispatchQueue.main.async { finished.fulfill() } }
        app.readQueue.isSuspended = false
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertEqual(app.pendingOpenCount, 0)
        XCTAssertEqual(app.editors.flatMap(\.notes).filter { $0.fileURL != nil }.map(\.text), ["new request"])
        app.editors.forEach { $0.window?.orderOut(nil) }
    }

    @MainActor
    func testSaveAllPreventsDiscardingQueuedDocument() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        let editor = app.makeWindow()
        let first = TextDocument()
        let second = TextDocument()
        for (index, note) in [first, second].enumerated() {
            let url = directory.appendingPathComponent("file-\(index).txt")
            try Data("old".utf8).write(to: url)
            try note.load(url)
            note.changed(to: "new \(index)")
            editor.addNote(note)
        }
        let gate = DispatchSemaphore(value: 0)
        app.diskQueue.async { gate.wait() }
        app.saveAll(nil)
        XCTAssertTrue(app.editingLocked)
        editor.closeNote(nil)
        XCTAssertTrue(editor.notes.contains { $0 === second })
        gate.signal()
        let unlocked = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !app.editingLocked }, object: nil)
        await fulfillment(of: [unlocked], timeout: 5)
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("file-1.txt")), "new 1")
        XCTAssertFalse(second.isDocumentEdited)
    }

    @MainActor
    func testReloadingShorterFileInBackgroundTabKeepsSessionSaving() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("long.txt")
        try Data(String(repeating: "a", count: 1000).utf8).write(to: file)
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        let editor = app.makeWindow()
        let background = TextDocument()
        try background.load(file)
        background.selection = NSRange(location: 900, length: 5)
        editor.addNote(background)
        editor.addNote(TextDocument())
        XCTAssertNotEqual(editor.activeID, background.id)
        try Data("short".utf8).write(to: file)
        try background.load(file, encoding: background.format.encoding)
        editor.reload(background)
        let saved = expectation(description: "Session saved")
        app.changed()
        app.flushSession { ok in XCTAssertTrue(ok); saved.fulfill() }
        await fulfillment(of: [saved], timeout: 5)
        XCTAssertEqual(background.selection, NSRange(location: 5, length: 0))
        XCTAssertEqual(try app.sessionStore.load()?.windows.flatMap(\.notes).first { $0.id == background.id }?.selectionLocation, 5)
    }

    @MainActor
    func testWindows1250NoteIsNotSilentlyReloadedAsUTF8() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("legacy.txt")
        try TextFileCodec.encode("Příliš", format: TextFormat(encoding: .windows1250, lineEnding: .lf)).write(to: file)
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        let editor = app.makeWindow()
        let note = TextDocument()
        try note.load(file, encoding: .windows1250)
        editor.addNote(note)
        // These UTF-8 bytes also decode as Windows-1250 ("PĹ™Ă­liĹˇ").
        try Data("Příliš".utf8).write(to: file)
        editor.checkExternalChanges()
        let flagged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in note.externalChange }, object: nil)
        await fulfillment(of: [flagged], timeout: 5)
        XCTAssertEqual(note.text, "Příliš")
        XCTAssertEqual(note.format.encoding, .windows1250)
    }

    @MainActor
    func testUnmodifiedFileIsRestoredFromDiskNotFromSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("clean.txt")
        try Data("first line\nsecond line".utf8).write(to: file)
        let note = TextDocument()
        try note.load(file)
        note.selection = NSRange(location: 11, length: 6)
        let snapshot = note.snapshot()
        XCTAssertTrue(snapshot.textOnDisk)
        XCTAssertEqual(snapshot.text, "")
        XCTAssertNil(snapshot.savedText)

        let restored = TextDocument(snapshot: snapshot)
        XCTAssertEqual(restored.text, "first line\nsecond line")
        XCTAssertFalse(restored.isDocumentEdited)
        XCTAssertEqual(restored.selection, NSRange(location: 11, length: 6))

        note.changed(to: "edited")
        XCTAssertFalse(note.snapshot().textOnDisk)
        try FileManager.default.removeItem(at: file)
        let missing = TextDocument(snapshot: snapshot)
        XCTAssertTrue(missing.externalChange)
    }

    @MainActor
    func testDirtyCacheInvalidatesForContentFormatAndSavedBaseline() {
        let note = TextDocument()
        note.text = "é"
        note.savedText = note.text
        note.savedFormat = note.format
        XCTAssertFalse(note.isDocumentEdited)
        note.text = "e\u{301}"
        XCTAssertTrue(note.isDocumentEdited)
        note.savedText = note.text
        XCTAssertFalse(note.isDocumentEdited)
        note.format.lineEnding = .lf
        XCTAssertTrue(note.isDocumentEdited)
        note.savedFormat = note.format
        XCTAssertFalse(note.isDocumentEdited)
    }
}
