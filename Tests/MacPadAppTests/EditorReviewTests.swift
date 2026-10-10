import AppKit
import XCTest

final class EditorReviewTests: XCTestCase {
    private var application: AppDelegate?

    @MainActor
    private func makeEditor(text: String = "") -> EditorWindowController {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        application = app
        let editor = app.makeWindow()
        let note = TextDocument()
        note.text = text
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
    func testInWindowMenuPreservesSearchResponderAcrossLanguageChange() throws {
        let editor = makeEditor(text: "keep this document")
        let oldMenu = NSApp.mainMenu
        let oldLanguage = UserDefaults.standard.object(forKey: "language")
        defer {
            UserDefaults.standard.set(oldLanguage, forKey: "language")
            NSApp.mainMenu = oldMenu
            finish()
        }
        editor.app.installMenus()
        editor.showWindow(nil)
        editor.textView?.selectAll(nil)
        editor.showSearchAll(nil)
        editor.findAll.stringValue = "query"
        editor.window?.makeFirstResponder(editor.findAll)
        let fieldEditor = try XCTUnwrap(editor.findAll.currentEditor())
        let row = try XCTUnwrap(editor.menuRow.subviews.compactMap { $0 as? NSStackView }.first)
        let edit = try XCTUnwrap(row.arrangedSubviews.compactMap { $0 as? ChromeMenuButton }.first { $0.title == L("Úpravy", "Edit") })

        XCTAssertNotNil(edit.menuProvider?())
        XCTAssertTrue(editor.window?.firstResponder === fieldEditor)
        XCTAssertEqual(editor.active?.text, "keep this document")
        UserDefaults.standard.set(Preferences.interfaceLanguage == "cs" ? "en" : "cs", forKey: "language")
        editor.app.installMenus()
        XCTAssertNotNil(edit.menuProvider?())
        XCTAssertTrue(editor.window?.firstResponder === fieldEditor)
    }

    @MainActor
    func testSelectedFinalSingleCharacterLineIsSorted() {
        let editor = makeEditor(text: "b\na")
        defer { finish() }
        let selection = NSRange(location: 0, length: 3)
        XCTAssertEqual(("b\na" as NSString).lineRange(for: selection), selection)
        editor.textView?.setSelectedRange(selection)
        editor.sortLines(nil)
        XCTAssertEqual(editor.active?.text, "a\nb")
    }

    @MainActor
    func testMoveIncludesFinalSelectedLineButExcludesNextLineStart() {
        let editor = makeEditor(text: "x\na\nb\ny")
        defer { finish() }
        let selection = NSRange(location: 2, length: 3)
        XCTAssertEqual(("x\na\nb\ny" as NSString).lineRange(for: selection), NSRange(location: 2, length: 4))
        XCTAssertEqual(("x\na\nb\ny" as NSString).lineRange(for: NSRange(location: 2, length: 4)), NSRange(location: 2, length: 4))
        editor.textView?.setSelectedRange(selection)
        editor.moveLineDown(nil)
        XCTAssertEqual(editor.active?.text, "x\ny\na\nb")
        editor.moveLineUp(nil)
        XCTAssertEqual(editor.active?.text, "x\na\nb\ny")
    }

    @MainActor
    func testRestoredSelectionDoesNotOverwriteSavedScroll() throws {
        let editor = makeEditor()
        defer { finish() }
        let note = TextDocument()
        note.text = (0..<200).map { "line \($0)" }.joined(separator: "\n")
        note.selection = NSRange(location: 400, length: 0)
        note.scrollY = 400
        editor.addNote(note)
        let scroll = try XCTUnwrap(editor.textView?.enclosingScrollView)
        XCTAssertEqual(editor.textView?.selectedRange(), NSRange(location: 400, length: 0))
        XCTAssertEqual(note.scrollY, 400, accuracy: 1)
        XCTAssertEqual(scroll.contentView.bounds.minY, 400, accuracy: 1)
    }

    @MainActor
    func testControlShortcutIgnoresCapsLock() throws {
        let editor = makeEditor(text: "select me")
        defer { finish() }
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.control, .capsLock], timestamp: 0, windowNumber: editor.window!.windowNumber,
            context: nil, characters: "\u{1}", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0))
        XCTAssertTrue(editor.textView?.performKeyEquivalent(with: event) == true)
        XCTAssertEqual(editor.textView?.selectedRange(), NSRange(location: 0, length: 9))
    }

    @MainActor
    private func controlKey(_ characters: String, shift: Bool = false, keyCode: UInt16, in editor: EditorWindowController) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: shift ? [.control, .shift] : [.control], timestamp: 0, windowNumber: editor.window!.windowNumber,
            context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode))
    }

    @MainActor
    func testControlShortcutIsIgnoredWhileSearchFieldHasFocus() throws {
        let editor = makeEditor(text: "keep")
        defer { finish() }
        editor.showSearchAll(nil)
        XCTAssertFalse(editor.window?.firstResponder === editor.textView)
        XCTAssertFalse(editor.textView?.performKeyEquivalent(with: try controlKey("a", keyCode: 0, in: editor)) == true)
        XCTAssertEqual(editor.textView?.selectedRange().length, 0)
    }

    @MainActor
    func testControlShiftTabSelectsPreviousTab() throws {
        let editor = makeEditor(text: "first")
        defer { finish() }
        let second = TextDocument()
        editor.addNote(second)
        editor.addNote(TextDocument())
        XCTAssertTrue(editor.textView?.performKeyEquivalent(with: try controlKey("\u{19}", shift: true, keyCode: 48, in: editor)) == true)
        XCTAssertTrue(editor.active === second)
    }

    @MainActor
    func testInsertedDateIsSeparateUndoStepFromTyping() throws {
        let editor = makeEditor()
        defer { finish() }
        let view = try XCTUnwrap(editor.textView)
        let undo = try XCTUnwrap(view.undoManager)
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        view.insertText("abc", replacementRange: view.selectedRange())
        undo.endUndoGrouping()
        undo.beginUndoGrouping()
        editor.insertTimestamp(nil)
        undo.endUndoGrouping()
        XCTAssertNotEqual(editor.active?.text, "abc")
        undo.undo()
        XCTAssertEqual(editor.active?.text, "abc")
    }

    @MainActor
    func testMovingOnlyTabClosesEmptySourceWindow() {
        let source = makeEditor(text: "moving")
        defer { finish() }
        let target = source.app.makeWindow()
        target.addNote(TextDocument())
        let note = source.notes[0]
        source.move(note, to: target)
        XCTAssertFalse(source.app.editors.contains { $0 === source })
        XCTAssertTrue(target.notes.contains { $0 === note })
        XCTAssertTrue(target.active === note)
    }

    @MainActor
    func testClickingInactiveTabSelectsIt() throws {
        let editor = makeEditor(text: "first")
        defer { finish() }
        let first = try XCTUnwrap(editor.active)
        editor.addNote(TextDocument())
        editor.showWindow(nil)
        editor.window?.contentView?.layoutSubtreeIfNeeded()
        let window = try XCTUnwrap(editor.window)
        let tab = try XCTUnwrap(editor.tabs.arrangedSubviews.compactMap { $0 as? TabButton }.first { $0.noteID == first.id })
        let point = tab.convert(NSPoint(x: tab.bounds.midX - 30, y: tab.bounds.midY), to: nil)
        XCTAssertTrue(window.contentView?.hitTest(window.contentView!.convert(point, from: nil)) === tab)
        func mouse(_ type: NSEvent.EventType) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                             windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        NSApp.postEvent(try mouse(.leftMouseUp), atStart: false)
        window.sendEvent(try mouse(.leftMouseDown))
        XCTAssertTrue(editor.active === first)
    }

    @MainActor
    func testClosingBackgroundTabKeepsActiveDocument() {
        let oldRestore = UserDefaults.standard.object(forKey: "restore")
        Preferences.restore = false
        defer { UserDefaults.standard.set(oldRestore, forKey: "restore"); finish() }
        let editor = makeEditor()
        let background = TextDocument()
        editor.addNote(background)
        let active = TextDocument()
        editor.addNote(active)
        let item = NSMenuItem()
        item.representedObject = background.id
        editor.closeNote(item)
        XCTAssertTrue(editor.active === active)
        XCTAssertFalse(editor.notes.contains { $0 === background })
    }

    @MainActor
    func testSearchUpdatesWhenPopulatedWindowOpensAndCloses() async throws {
        let oldRestore = UserDefaults.standard.object(forKey: "restore")
        Preferences.restore = false
        defer { UserDefaults.standard.set(oldRestore, forKey: "restore"); finish() }
        let editor = makeEditor(text: "unrelated")
        editor.findAll.stringValue = "needle"
        editor.showSearchAll(nil)
        let other = editor.app.makeWindow()
        let note = TextDocument()
        note.text = "needle"
        note.savedText = note.text
        note.savedFormat = note.format
        other.addNote(note)
        await waitForResults(editor, count: 1)
        _ = other.windowShouldClose(try XCTUnwrap(other.window))
        await waitForResults(editor, count: 0)
    }

    @MainActor
    func testSortUsesSelectedInterfaceLanguage() {
        let previous = UserDefaults.standard.object(forKey: "language")
        UserDefaults.standard.set("cs", forKey: "language")
        defer { UserDefaults.standard.set(previous, forKey: "language"); finish() }
        let editor = makeEditor(text: "chata\nhad\n")
        editor.textView?.selectAll(nil)
        editor.sortLines(nil)
        XCTAssertEqual(editor.active?.text, "had\nchata\n")
    }

    @MainActor
    func testRulerIncludesEmptyDocumentAndFinalEmptyLine() throws {
        let editor = makeEditor()
        defer { finish() }
        let scroll = try XCTUnwrap(editor.textView?.enclosingScrollView)
        scroll.rulersVisible = true
        editor.window?.contentView?.layoutSubtreeIfNeeded()
        let ruler = try XCTUnwrap(scroll.verticalRulerView as? LineNumbers)
        XCTAssertEqual(ruler.visibleLineLabels().map(\.number), [1])
        editor.textView?.insertText("a\n", replacementRange: NSRange(location: 0, length: 0))
        XCTAssertEqual(ruler.visibleLineLabels().map(\.number), [1, 2])
    }

    @MainActor
    func testUnchangedTabMetadataKeepsExistingControls() throws {
        let editor = makeEditor(text: "Title\na")
        defer { finish() }
        let original = try XCTUnwrap(editor.tabs.arrangedSubviews.first)
        editor.textView?.insertText("b", replacementRange: NSRange(location: 7, length: 0))
        XCTAssertTrue(editor.tabs.arrangedSubviews.first === original)
        editor.textView?.setSelectedRange(NSRange(location: 8, length: 0))
        XCTAssertEqual(editor.statusBar.count.stringValue, "8" + L(" znaků", " characters"))
        XCTAssertEqual(editor.status.stringValue, "\(L("Ř.", "Ln")) 2, \(L("sl.", "Col")) 3")
    }

    @MainActor
    private func waitForResults(_ editor: EditorWindowController, count: Int) async {
        for _ in 0..<40 {
            let buttons = editor.results.arrangedSubviews.compactMap { $0 as? ResultButton }
            let completed = editor.results.arrangedSubviews.contains { $0 is NSTextField }
            if completed && buttons.count == count { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Search did not update to \(count) results")
    }
}
