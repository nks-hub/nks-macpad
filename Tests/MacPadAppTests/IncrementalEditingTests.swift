import AppKit
import XCTest
import MacPadCore

final class IncrementalEditingTests: XCTestCase {
    private var application: AppDelegate?

    @MainActor
    private func makeEditor(_ text: String) -> EditorWindowController {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        application = app
        let editor = app.makeWindow()
        let note = TextDocument()
        note.text = text
        note.savedText = text
        note.savedFormat = note.format
        editor.addNote(note)
        return editor
    }

    @MainActor
    private func finish() {
        application?.editors.forEach {
            $0.searchWork?.cancel()
            $0.window?.orderOut(nil)
        }
        application = nil
    }

    @MainActor
    func testAppendInteriorReplacementAndDeletionUpdateTextAndStatus() throws {
        let editor = makeEditor("one\ntwo")
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)

        view.insertText("!", replacementRange: NSRange(location: 7, length: 0))
        assertState(editor, text: "one\ntwo!", characters: 8, line: 2, column: 5)

        editor.replaceRange(NSRange(location: 0, length: 3), with: "ONE\nMORE", name: "Replace")
        assertState(editor, text: "ONE\nMORE\ntwo!", characters: 13, line: 3, column: 5)

        editor.replaceRange(NSRange(location: 4, length: 5), with: "", name: "Delete")
        assertState(editor, text: "ONE\ntwo!", characters: 8, line: 2, column: 5)
    }

    @MainActor
    func testCombiningMarkInsertionAndRemovalPreserveExactText() throws {
        let editor = makeEditor("Cafe")
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)

        view.insertText("\u{301}", replacementRange: NSRange(location: 4, length: 0))
        assertState(editor, text: "Cafe\u{301}", characters: 4, line: 1, column: 5)

        editor.replaceRange(NSRange(location: 4, length: 1), with: "", name: "Delete accent")
        assertState(editor, text: "Cafe", characters: 4, line: 1, column: 5, dirty: false)
    }

    @MainActor
    func testEmojiReplacementAndNativeBackwardDeletionKeepSurrogatePairs() throws {
        let editor = makeEditor("A🐈B")
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)

        editor.replaceRange(NSRange(location: 1, length: 2), with: "🦋", name: "Replace emoji")
        assertState(editor, text: "A🦋B", characters: 3, line: 1, column: 4)

        view.insertText("!", replacementRange: NSRange(location: 3, length: 0))
        assertState(editor, text: "A🦋!B", characters: 4, line: 1, column: 5)

        view.setSelectedRange(NSRange(location: 3, length: 0))
        view.deleteBackward(nil)
        assertState(editor, text: "A!B", characters: 3, line: 1, column: 4)
    }

    @MainActor
    func testJoinerMergesAndSplitsExistingEmoji() throws {
        let editor = makeEditor("👩👧")
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)

        view.insertText("\u{200D}", replacementRange: NSRange(location: 2, length: 0))
        assertState(editor, text: "👩‍👧", characters: 1, line: 1, column: 2)

        view.insertText("\u{200D}👦", replacementRange: NSRange(location: 5, length: 0))
        assertState(editor, text: "👩‍👧‍👦", characters: 1, line: 1, column: 2)

        editor.replaceRange(NSRange(location: 5, length: 3), with: "", name: "Remove joined emoji")
        editor.replaceRange(NSRange(location: 2, length: 1), with: "", name: "Split emoji")
        assertState(editor, text: "👩👧", characters: 2, line: 1, column: 3, dirty: false)
    }

    @MainActor
    func testNewlineJoiningAndEmptyLinesUpdateLineAndColumn() {
        let editor = makeEditor("a\nb\nc")
        defer { finish() }

        editor.replaceRange(NSRange(location: 1, length: 1), with: "", name: "Join lines")
        assertState(editor, text: "ab\nc", characters: 4, line: 2, column: 2)

        editor.replaceRange(NSRange(location: 1, length: 2), with: "\n\n", name: "Replace lines")
        assertState(editor, text: "a\n\nc", characters: 4, line: 3, column: 2)

        editor.replaceRange(NSRange(location: 2, length: 1), with: "", name: "Remove empty line")
        assertState(editor, text: "a\nc", characters: 3, line: 2, column: 2)
    }

    @MainActor
    func testDeletingEntireDocumentAndTypingIntoEmptyText() throws {
        let editor = makeEditor("🐈\n")
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)

        editor.replaceRange(NSRange(location: 0, length: 3), with: "", name: "Delete all")
        assertState(editor, text: "", characters: 0, line: 1, column: 1)

        view.insertText("new\n", replacementRange: NSRange(location: 0, length: 0))
        assertState(editor, text: "new\n", characters: 4, line: 2, column: 1)

        editor.replaceRange(NSRange(location: 3, length: 1), with: "", name: "Remove final newline")
        assertState(editor, text: "new", characters: 3, line: 1, column: 4)
    }

    @MainActor
    func testUnicodeUndoRedoAndSnapshotKeepBytesAndSavedBaseline() throws {
        let original = "é\n🐈"
        let edited = "e\u{301}\n👩‍👧"
        let editor = makeEditor(original)
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)
        let note = try XCTUnwrap(editor.active)

        view.breakUndoCoalescing()
        view.insertText(edited, replacementRange: NSRange(location: 0, length: 4))
        view.breakUndoCoalescing()
        assertState(editor, text: edited, characters: 3, line: 2, column: 2)

        note.undoManager?.undo()
        assertState(editor, text: original, characters: 3, line: 2, column: 2, dirty: false)
        note.undoManager?.redo()
        assertState(editor, text: edited, characters: 3, line: 2, column: 2)

        editor.captureSelection()
        let data = try JSONEncoder().encode(note.snapshot())
        let restored = TextDocument(snapshot: try JSONDecoder().decode(NoteSnapshot.self, from: data))
        XCTAssertEqual(Array(restored.text.utf8), Array(edited.utf8))
        XCTAssertEqual(restored.savedText.map { Array($0.utf8) }, Array(original.utf8))
        XCTAssertEqual(restored.selection, view.selectedRange())
        XCTAssertTrue(restored.isDocumentEdited)
    }

    @MainActor
    func testCanonicallyEquivalentReplacementStillMarksDocumentDirty() throws {
        let editor = makeEditor("é")
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)

        view.insertText("e\u{301}", replacementRange: NSRange(location: 0, length: 1))
        assertState(editor, text: "e\u{301}", characters: 1, line: 1, column: 2)
        editor.replaceRange(NSRange(location: 0, length: 2), with: "é", name: "Restore original bytes")
        assertState(editor, text: "é", characters: 1, line: 1, column: 2, dirty: false)
    }

    @MainActor
    func testBatchedTextStorageEditsPublishCompleteFinalText() throws {
        let editor = makeEditor("alpha\nbeta\ngamma")
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)
        let storage = try XCTUnwrap(view.textStorage)

        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 5), with: "A")
        storage.replaceCharacters(in: NSRange(location: 7, length: 5), with: "🦋!")
        storage.replaceCharacters(in: NSRange(location: 2, length: 0), with: "\n")
        storage.endEditing()

        assertState(editor, text: "A\n\nbeta\n🦋!", characters: 10, line: 4, column: 3)
    }

    @MainActor
    private func assertState(_ editor: EditorWindowController, text: String, characters: Int,
                             line: Int, column: Int, dirty: Bool = true,
                             file: StaticString = #filePath, sourceLine: UInt = #line) {
        guard let note = editor.active, let view = editor.textView else {
            return XCTFail("Expected an active editor", file: file, line: sourceLine)
        }
        XCTAssertEqual(Array(view.string.utf8), Array(text.utf8), file: file, line: sourceLine)
        XCTAssertEqual(Array(note.text.utf8), Array(text.utf8), file: file, line: sourceLine)
        XCTAssertEqual(note.isDocumentEdited, dirty, file: file, line: sourceLine)
        view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        editor.updateStatus()
        XCTAssertEqual(editor.statusBar.count.stringValue, "\(characters)" + L(" znaků", " characters"), file: file, line: sourceLine)
        XCTAssertEqual(editor.status.stringValue, "\(L("Ř.", "Ln")) \(line), \(L("sl.", "Col")) \(column)", file: file, line: sourceLine)
    }
}
