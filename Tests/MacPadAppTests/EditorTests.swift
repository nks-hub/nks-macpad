import AppKit
import XCTest
import MacPadCore

final class EditorTests: XCTestCase {
    @MainActor
    func testUnicodeEditWithEquivalentGraphemeIsStillDirty() throws {
        let note = TextDocument()
        note.text = "é"
        note.savedText = note.text
        note.savedFormat = note.format
        XCTAssertFalse(note.isDocumentEdited)
        note.changed(to: "e\u{301}")
        XCTAssertTrue(note.isDocumentEdited)
    }

    @MainActor
    func testTabsKeepTextSelectionAndIndependentUndo() throws {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: temporaryDirectory())
        let editor = app.makeWindow()
        let first = TextDocument()
        let second = TextDocument()
        editor.addNote(first)
        editor.textView?.insertText("Příliš žluťoučký 🐈", replacementRange: NSRange(location: 0, length: 0))
        XCTAssertEqual(first.text, "Příliš žluťoučký 🐈")
        editor.textView?.setSelectedRange(NSRange(location: 2, length: 4))
        editor.addNote(second)
        editor.textView?.insertText("Second", replacementRange: NSRange(location: 0, length: 0))
        editor.textView?.breakUndoCoalescing()
        XCTAssertTrue(editor.textView?.undoManager === second.undoManager)
        XCTAssertTrue(second.undoManager?.canUndo == true)
        second.undoManager?.undo()
        XCTAssertEqual(editor.textView?.string, "", "Visible text after undo")
        XCTAssertEqual(second.text, "")
        XCTAssertEqual(first.text, "Příliš žluťoučký 🐈")
        editor.select(first.id)
        XCTAssertEqual(editor.textView?.selectedRange(), NSRange(location: 2, length: 4))
        editor.window?.orderOut(nil)
    }

    @MainActor
    func testLineCommandsUndoAsOneEdit() throws {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: temporaryDirectory())
        let editor = app.makeWindow()
        let note = TextDocument()
        note.text = "z\na\na\n"
        editor.addNote(note)
        editor.textView?.setSelectedRange(NSRange(location: 0, length: 6))
        editor.uniqueLines(nil)
        XCTAssertEqual(note.text, "z\na\n")
        editor.textView?.breakUndoCoalescing()
        XCTAssertTrue(note.undoManager?.canUndo == true)
        note.undoManager?.undo()
        XCTAssertEqual(editor.textView?.string, "z\na\na\n", "Visible lines after undo")
        XCTAssertEqual(note.text, "z\na\na\n")
    }

    @MainActor
    func testRecoveredDraftDoesNotTouchOriginalFile() throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("note.txt")
        try Data("original".utf8).write(to: file)
        let note = TextDocument()
        try note.load(file)
        note.changed(to: "neuložená poznámka")
        let restored = TextDocument(snapshot: note.snapshot())
        XCTAssertTrue(restored.isDocumentEdited)
        XCTAssertEqual(restored.text, "neuložená poznámka")
        XCTAssertEqual(try String(contentsOf: file), "original")
    }

    @MainActor
    func testMoveTabKeepsVisibleUndoHistory() {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: temporaryDirectory())
        let source = app.makeWindow()
        let target = app.makeWindow()
        let note = TextDocument()
        source.addNote(note)
        source.textView?.insertText("move me", replacementRange: NSRange(location: 0, length: 0))
        source.textView?.breakUndoCoalescing()
        let originalView = source.textView
        source.move(note, to: target)
        XCTAssertTrue(target.textView === originalView)
        note.undoManager?.undo()
        XCTAssertEqual(target.textView?.string, "")
        XCTAssertEqual(note.text, "")
        note.undoManager?.redo()
        XCTAssertEqual(target.textView?.string, "move me")
        XCTAssertEqual(note.text, "move me")
    }

    @MainActor
    func testRepeatedLineMovesKeepOnlyMovedLinesSelected() {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: temporaryDirectory())
        let editor = app.makeWindow()
        let note = TextDocument()
        note.text = "a\nb\nc\n"
        editor.addNote(note)
        editor.textView?.setSelectedRange(NSRange(location: 2, length: 0))
        editor.moveLineUp(nil)
        XCTAssertEqual(note.text, "b\na\nc\n")
        editor.moveLineDown(nil)
        XCTAssertEqual(note.text, "a\nb\nc\n")
    }

    @MainActor
    func testFlushWaitsForLatestRevision() async throws {
        _ = NSApplication.shared
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppDelegate(sessionDirectory: directory)
        let editor = app.makeWindow()
        let note = TextDocument()
        editor.addNote(note)
        note.changed(to: "before")
        app.changed()
        let gate = DispatchSemaphore(value: 0)
        app.diskQueue.async { gate.wait() }
        let finished = expectation(description: "Latest revision persisted")
        app.flushSession { ok in XCTAssertTrue(ok); finished.fulfill() }
        note.changed(to: "after")
        app.changed()
        gate.signal()
        await fulfillment(of: [finished], timeout: 5)
        let recovered = try app.sessionStore.load()
        XCTAssertEqual(recovered?.windows.first?.notes.first?.text, "after")
    }

    @MainActor
    func testEditsDuringSaveStayDirty() async throws {
        _ = NSApplication.shared
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("note.txt")
        try Data("old".utf8).write(to: url)
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        let note = TextDocument()
        try note.load(url)
        note.changed(to: "first edit")
        let gate = DispatchSemaphore(value: 0)
        app.diskQueue.async { gate.wait() }
        let finished = expectation(description: "Earlier revision saved")
        app.save(note) { ok in XCTAssertTrue(ok); finished.fulfill() }
        note.changed(to: "second edit")
        gate.signal()
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertEqual(try String(contentsOf: url), "first edit")
        XCTAssertEqual(note.text, "second edit")
        XCTAssertTrue(note.isDocumentEdited)
    }

    @MainActor
    func testSearchAcrossUnsavedTabsFindsCurrentDocument() async {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: temporaryDirectory())
        let first = app.makeWindow()
        let second = app.makeWindow()
        let note = TextDocument()
        note.text = "alpha inside an unsaved draft"
        first.addNote(note)
        second.addNote(TextDocument())
        second.showSearchAll(nil)
        second.findAll.stringValue = "alpha"
        second.searchAllChanged(nil)
        let appeared = expectation(description: "Search results appeared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { appeared.fulfill() }
        await fulfillment(of: [appeared], timeout: 3)
        let buttons = second.results.arrangedSubviews.compactMap { $0 as? ResultButton }
        XCTAssertEqual(buttons.count, 1)
        buttons.first?.invoke(nil)
        XCTAssertEqual(first.textView?.selectedRange(), NSRange(location: 0, length: 5))
        first.window?.orderOut(nil)
    }

    @MainActor
    func testEditingLockDisablesTextWhileSessionCloses() {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: temporaryDirectory())
        let editor = app.makeWindow()
        editor.addNote(TextDocument())
        let count = editor.notes.count
        app.lockEditing(true)
        XCTAssertFalse(editor.textView?.isEditable ?? true)
        app.newNote(nil)
        XCTAssertEqual(editor.notes.count, count)
        app.lockEditing(false)
        XCTAssertTrue(editor.textView?.isEditable ?? false)
    }

    @MainActor
    func testWindowLayoutKeepsTabsMenuAndEditorVisible() {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: temporaryDirectory())
        let editor = app.makeWindow()
        let note = TextDocument()
        note.text = "Visible editor"
        editor.addNote(note)
        editor.showWindow(nil)
        editor.window?.contentView?.layoutSubtreeIfNeeded()
        for view in [editor.titlebar, editor.tabScroller, editor.menuRow, editor.body, editor.statusBar] {
            XCTAssertFalse(view.isHiddenOrHasHiddenAncestor)
        }
        XCTAssertGreaterThan(editor.tabScroller.visibleRect.height, 20)
        XCTAssertGreaterThan(editor.menuRow.visibleRect.height, 20)
        XCTAssertGreaterThan(editor.textView?.visibleRect.height ?? 0, 100)
        editor.window?.orderOut(nil)
    }

    @MainActor
    func testInsertedWindowsTextUsesLogicalLinesAndPlainText() {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: temporaryDirectory())
        let editor = app.makeWindow()
        let note = TextDocument()
        editor.addNote(note)
        let formatted = NSAttributedString(string: "a\r\nb\rc", attributes: [.foregroundColor: NSColor.red])
        editor.textView?.insertText(formatted, replacementRange: NSRange(location: 0, length: 0))
        XCTAssertEqual(note.text, "a\nb\nc")
        XCTAssertFalse(editor.textView?.isRichText ?? true)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MacPadTests-" + UUID().uuidString)
    }
}
