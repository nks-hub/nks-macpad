import AppKit
import XCTest

final class SplitEditorTests: XCTestCase {
    private var application: AppDelegate?
    private var directory: URL?

    @MainActor
    private func makeEditor() throws -> EditorWindowController {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        application = app
        let editor = app.makeWindow()
        let note = TextDocument()
        note.text = "Příliš 😀\n"
        editor.addNote(note)
        editor.showWindow(nil)
        return editor
    }

    @MainActor
    private func finish() {
        application?.editors.forEach { $0.markdownPreview?.cancel(); $0.window?.orderOut(nil) }
        application = nil
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    @MainActor
    func testBothPanesShareStorageRevisionAndUndo() throws {
        let editor = try makeEditor()
        defer { finish() }
        let note = try XCTUnwrap(editor.active)
        let original = note.text
        editor.toggleSplitEditor(nil)
        let left = try XCTUnwrap(editor.textViews[note.id])
        let right = try XCTUnwrap(editor.secondaryViews[note.id])
        XCTAssertTrue(left.textStorage === right.textStorage)
        XCTAssertTrue(left.undoManager === right.undoManager)
        XCTAssertEqual(editor.notes.count, 1)
        let revision = note.revision
        left.insertText("L", replacementRange: NSRange(location: 0, length: 0))
        XCTAssertEqual(note.revision, revision + 1)
        XCTAssertEqual(right.string, "L" + original)
        // NSTextView groups undo by event; real focus changes happen after the previous key event finishes.
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        editor.window?.makeFirstResponder(right)
        XCTAssertEqual(editor.focusedPane, .secondary)
        right.insertText("R", replacementRange: NSRange(location: (right.string as NSString).length, length: 0))
        XCTAssertEqual(left.string, "L" + original + "R")
        note.undoManager?.undo()
        XCTAssertEqual(note.text, "L" + original)
        XCTAssertEqual(left.string, right.string)
        note.undoManager?.undo()
        XCTAssertEqual(note.text, original)
        note.undoManager?.redo()
        XCTAssertEqual(left.string, "L" + original)
        XCTAssertEqual(right.string, left.string)
    }

    @MainActor
    func testClosingSplitKeepsSecondaryUndoAndIndependentSelections() throws {
        let editor = try makeEditor()
        defer { finish() }
        let note = try XCTUnwrap(editor.active)
        let original = note.text + String(repeating: "další řádek\n", count: 200)
        note.changed(to: original)
        editor.reload(note)
        editor.toggleSplitEditor(nil)
        let left = try XCTUnwrap(editor.textViews[note.id])
        let right = try XCTUnwrap(editor.secondaryViews[note.id])
        left.setSelectedRange(NSRange(location: 0, length: 2))
        right.setSelectedRange(NSRange(location: 3, length: 1))
        editor.focusPane(.secondary)
        let rightScroll = try XCTUnwrap(right.enclosingScrollView)
        rightScroll.contentView.scroll(to: NSPoint(x: 0, y: 500))
        rightScroll.reflectScrolledClipView(rightScroll.contentView)
        editor.refresh()
        XCTAssertEqual(left.selectedRange(), NSRange(location: 0, length: 2))
        XCTAssertEqual(right.selectedRange(), NSRange(location: 3, length: 1))
        XCTAssertEqual(left.enclosingScrollView?.contentView.bounds.minY ?? -1, 0, accuracy: 1)
        XCTAssertEqual(right.enclosingScrollView?.contentView.bounds.minY ?? -1, 500, accuracy: 1)
        right.insertText("x", replacementRange: NSRange(location: 0, length: 0))
        editor.toggleSplitEditor(nil)
        XCTAssertFalse(editor.splitEnabled)
        XCTAssertEqual(editor.textView?.string, "x" + original)
        note.undoManager?.undo()
        XCTAssertEqual(editor.textView?.string, original)
        XCTAssertEqual(note.text, original)
    }

    @MainActor
    func testDifferentDocumentsSaveOnlyFocusedPaneAndRemainUniqueInSnapshot() async throws {
        let editor = try makeEditor()
        defer { finish() }
        let first = try XCTUnwrap(editor.active)
        let root = try XCTUnwrap(directory)
        let firstURL = root.appendingPathComponent("first.txt")
        let secondURL = root.appendingPathComponent("second.txt")
        try Data("first".utf8).write(to: firstURL)
        try Data("second".utf8).write(to: secondURL)
        try first.load(firstURL)
        editor.reload(first)
        let second = TextDocument()
        try second.load(secondURL)
        editor.addNote(second)
        editor.select(first.id)
        editor.toggleSplitEditor(nil)
        editor.textView?.insertText(" A", replacementRange: NSRange(location: 5, length: 0))
        editor.focusPane(.secondary)
        editor.select(second.id)
        editor.textView?.insertText(" B", replacementRange: NSRange(location: 6, length: 0))
        editor.saveNote(nil)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !second.saving }, object: nil)
        await fulfillment(of: [saved], timeout: 3)
        XCTAssertEqual(try String(contentsOf: firstURL), "first")
        XCTAssertEqual(try String(contentsOf: secondURL), "second B")
        XCTAssertTrue(first.isDocumentEdited)
        XCTAssertFalse(second.isDocumentEdited)
        let snapshot = editor.snapshot()
        XCTAssertEqual(snapshot.notes.count, 2)
        XCTAssertEqual(snapshot.activeNoteID, second.id)
        XCTAssertEqual(editor.primaryID, first.id)
        XCTAssertEqual(editor.secondaryID, second.id)
        editor.app.lockEditing(true)
        XCTAssertTrue(editor.allTextViews.allSatisfy { !$0.isEditable })
        XCTAssertTrue(editor.paneHeaders.allSatisfy { !$0.documents.isEnabled })
        editor.app.lockEditing(false)
        XCTAssertTrue(editor.allTextViews.allSatisfy(\.isEditable))
    }

    @MainActor
    func testMovingSharedDocumentTransfersBothViewsAndUndo() throws {
        let editor = try makeEditor()
        defer { finish() }
        let note = try XCTUnwrap(editor.active)
        let original = note.text
        editor.toggleSplitEditor(nil)
        editor.focusPane(.secondary)
        editor.textView?.insertText("x", replacementRange: NSRange(location: 0, length: 0))
        let target = editor.app.makeWindow()
        editor.move(note, to: target)
        XCTAssertTrue(target.textViews[note.id]?.owner === target)
        XCTAssertTrue(target.secondaryViews[note.id]?.owner === target)
        XCTAssertNil(editor.secondaryViews[note.id])
        note.undoManager?.undo()
        XCTAssertEqual(note.text, original)
        XCTAssertEqual(target.textView?.string, original)
        XCTAssertEqual(target.notes.count, 1)
    }

    @MainActor
    func testMarkdownPreviewFollowsFocusedDocumentInSplit() async throws {
        let editor = try makeEditor()
        defer { finish() }
        let first = try XCTUnwrap(editor.active)
        first.changed(to: "# Left")
        editor.reload(first)
        let second = TextDocument()
        second.text = "# Right"
        editor.addNote(second)
        editor.select(first.id)
        editor.toggleSplitEditor(nil)
        editor.toggleMarkdownPreview(nil)
        let preview = try XCTUnwrap(editor.markdownPreview)
        editor.focusPane(.secondary)
        editor.select(second.id)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in preview.renderedNoteID == second.id }, object: nil)
        await fulfillment(of: [ready], timeout: 3)
        XCTAssertEqual(preview.textView.string, "Right")
        XCTAssertEqual(editor.textViews[first.id]?.string, "# Left")
        editor.escape()
        XCTAssertNil(editor.markdownPreview)
        XCTAssertTrue(editor.splitEnabled)
        editor.escape()
        XCTAssertFalse(editor.splitEnabled)
        XCTAssertTrue(editor.active === second)
    }

    @MainActor
    func testSameTitlesStaySelectableAndReloadReachesBothViews() throws {
        let editor = try makeEditor()
        defer { finish() }
        let first = try XCTUnwrap(editor.active)
        let second = TextDocument()
        first.customTitle = "Same title"
        second.customTitle = "Same title"
        editor.addNote(second)
        editor.select(first.id)
        editor.toggleSplitEditor(nil)
        XCTAssertEqual(editor.paneHeaders.first?.documents.numberOfItems, 2)
        first.changed(to: "reloaded")
        editor.reload(first)
        XCTAssertEqual(editor.textViews[first.id]?.string, "reloaded")
        XCTAssertEqual(editor.secondaryViews[first.id]?.string, "reloaded")
    }
}
