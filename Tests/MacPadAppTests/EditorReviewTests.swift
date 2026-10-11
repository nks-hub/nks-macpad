import AppKit
import PDFKit
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
    func testEscapeFromCommandResultsDismissesWithoutRunningAction() throws {
        let editor = makeEditor(text: "keep this document")
        defer { finish() }
        editor.presentPanel(title: "Commands", choices: [CommandChoice(title: "Run") { XCTFail("Cancelled command ran") }])
        let panel = try XCTUnwrap(editor.panel)
        let window = try XCTUnwrap(panel.window)
        defer {
            if window.sheetParent != nil { editor.window?.endSheet(window) }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(window.makeFirstResponder(panel.table))
        XCTAssertTrue(window.firstResponder === panel.table)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false, keyCode: 53))
        window.sendEvent(event)
        let deadline = Date().addingTimeInterval(1)
        while editor.panel != nil && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        XCTAssertNil(editor.panel)
        XCTAssertNil(editor.window?.attachedSheet)
        XCTAssertTrue(editor.window?.firstResponder === editor.textView)
        XCTAssertEqual(editor.active?.text, "keep this document")
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

    /// Real key events with run loop turns, so the undo manager closes a group per event like in the app.
    @MainActor
    private func type(_ text: String, in editor: EditorWindowController) throws {
        let window = try XCTUnwrap(editor.window)
        for character in text {
            let key = String(character)
            window.sendEvent(try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0)))
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    @MainActor
    func testInsertedDateIsSeparateUndoStepFromTyping() throws {
        let editor = makeEditor()
        defer { finish() }
        editor.showWindow(nil)
        try type("abc", in: editor)
        editor.insertTimestamp(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        try type("x", in: editor)
        XCTAssertNotEqual(editor.active?.text, "abc")
        editor.active?.undoManager?.undo()
        editor.active?.undoManager?.undo()
        XCTAssertEqual(editor.active?.text, "abc")
    }

    @MainActor
    func testTypingAfterReturningToTabIsSeparateUndoStep() throws {
        let editor = makeEditor()
        defer { finish() }
        let first = try XCTUnwrap(editor.active)
        editor.showWindow(nil)
        try type("abc", in: editor)
        editor.addNote(TextDocument())
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        editor.select(first.id)
        try type("def", in: editor)
        XCTAssertEqual(first.text, "abcdef")
        first.undoManager?.undo()
        XCTAssertEqual(first.text, "abc")
    }

    @MainActor
    func testSwitchingTabMarksSessionForSaving() throws {
        let editor = makeEditor(text: "first")
        defer { finish() }
        let first = try XCTUnwrap(editor.active)
        editor.addNote(TextDocument())
        editor.app.sessionPending = false
        editor.select(first.id)
        XCTAssertTrue(editor.app.sessionPending)
    }

    @MainActor
    func testAlwaysOnTopIsVisibleInStatus() {
        let editor = makeEditor(text: "x")
        defer { finish() }
        editor.toggleOnTop(nil)
        XCTAssertTrue(editor.status.stringValue.hasPrefix(L("Okno navrchu", "Always on top")))
        editor.toggleOnTop(nil)
        XCTAssertFalse(editor.status.stringValue.hasPrefix(L("Okno navrchu", "Always on top")))
    }

    @MainActor
    func testNewWindowDoesNotCoverPreviousOne() throws {
        let first = makeEditor()
        defer { finish() }
        first.showWindow(nil)
        let second = first.app.makeWindow()
        let a = try XCTUnwrap(first.window?.frame)
        let b = try XCTUnwrap(second.window?.frame)
        XCTAssertNotEqual(a.origin, b.origin)
    }

    @MainActor
    func testPrintViewFollowsTextHeight() throws {
        let editor = makeEditor()
        defer { finish() }
        let info = NSPrintInfo.shared
        let page = info.paperSize.height - info.topMargin - info.bottomMargin
        let short = TextDocument()
        short.text = "one\ntwo\nthree"
        XCTAssertLessThan(editor.printableView(for: short).frame.height, page)
        let long = TextDocument()
        long.text = (1...300).map { "line \($0)" }.joined(separator: "\n")
        XCTAssertGreaterThan(editor.printableView(for: long).frame.height, page)
    }

    @MainActor
    func testShortNotePrintsNearTopOfSinglePDFPage() throws {
        let editor = makeEditor(text: "First printed line")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url); finish() }
        let operation = editor.printOperation(for: try XCTUnwrap(editor.active))
        operation.printInfo.orientation = .portrait
        operation.printInfo.scalingFactor = 1
        operation.printInfo.paperSize = NSSize(width: 612, height: 792)
        operation.printInfo.topMargin = 36
        operation.printInfo.bottomMargin = 36
        operation.printInfo.jobDisposition = .save
        operation.printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        XCTAssertTrue(operation.run())
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertEqual(pdf.pageCount, 1)
        let page = try XCTUnwrap(pdf.page(at: 0))
        XCTAssertEqual(page.string?.trimmingCharacters(in: .whitespacesAndNewlines), "First printed line")
        let selection = try XCTUnwrap(page.selection(for: NSRange(location: 0, length: 5)))
        XCTAssertGreaterThan(selection.bounds(for: page).midY, 600, "Short notes must start near the top margin")
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
    func testLineNumbersDoNotCoverTextOfNewTab() throws {
        let old = UserDefaults.standard.object(forKey: "lineNumbers")
        UserDefaults.standard.set(true, forKey: "lineNumbers")
        defer { UserDefaults.standard.set(old, forKey: "lineNumbers"); finish() }
        let editor = makeEditor(text: "short")
        editor.addNote(TextDocument())
        editor.showWindow(nil)
        editor.window?.contentView?.layoutSubtreeIfNeeded()
        let scroll = try XCTUnwrap(editor.textView?.enclosingScrollView)
        let ruler = try XCTUnwrap(scroll.verticalRulerView)
        let textX = try XCTUnwrap(editor.textView).convert(NSPoint.zero, to: nil).x
        XCTAssertGreaterThanOrEqual(textX, ruler.convert(NSPoint(x: ruler.bounds.maxX, y: 0), to: nil).x)
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
    func testSearchResultsJoinKeyboardNavigationAfterLoading() async throws {
        let editor = makeEditor(text: "find this result")
        defer { finish() }
        editor.showWindow(nil)
        editor.showSearchAll(nil)
        let fieldEditor = try XCTUnwrap(editor.findAll.currentEditor())
        var previous: ResultButton?
        for query in ["result", "find", ""] {
            editor.findAll.stringValue = query
            editor.searchAllChanged(nil)
            if !query.isEmpty { await waitForResults(editor, count: 1) }
            let result = editor.results.arrangedSubviews.first as? ResultButton
            var visited = Set<ObjectIdentifier>()
            var next: NSView? = editor.findAll
            while let view = next, visited.insert(ObjectIdentifier(view)).inserted {
                next = view.nextKeyView
            }
            if query.isEmpty {
                XCTAssertNil(result)
            } else {
                XCTAssertTrue(visited.contains(ObjectIdentifier(try XCTUnwrap(result))), "Tab navigation must reach the loaded result")
            }
            if let previous { XCTAssertFalse(visited.contains(ObjectIdentifier(previous)), "Old results must leave the key loop") }
            XCTAssertTrue(editor.window?.firstResponder === fieldEditor)
            previous = result
        }
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
    func testSearchResultRejectsChangedUnicodeRange() async throws {
        let editor = makeEditor(text: "😀 PŘÍLIŠ žluťoučký")
        defer { finish() }
        editor.findAll.stringValue = "příliš"
        editor.showSearchAll(nil)
        await waitForResults(editor, count: 1)
        let result = try XCTUnwrap(editor.results.arrangedSubviews.compactMap { $0 as? ResultButton }.first)
        result.invoke(nil)
        XCTAssertEqual(editor.textView?.selectedRange(), NSRange(location: 3, length: 6))
        editor.textView?.insertText("x", replacementRange: NSRange(location: 0, length: 0))
        editor.textView?.setSelectedRange(NSRange(location: 0, length: 0))
        result.invoke(nil)
        XCTAssertEqual(editor.textView?.selectedRange(), NSRange(location: 0, length: 0))
        await waitForResults(editor, count: 1)
        let current = try XCTUnwrap(editor.results.arrangedSubviews.compactMap { $0 as? ResultButton }.first)
        current.invoke(nil)
        XCTAssertEqual(editor.textView?.selectedRange(), NSRange(location: 4, length: 6))
    }

    @MainActor
    func testEscapeCancelsPendingSearchWithoutPublishingResults() async throws {
        let editor = makeEditor(text: "needle")
        defer { finish() }
        editor.findAll.stringValue = "needle"
        editor.showSearchAll(nil)
        let work = try XCTUnwrap(editor.searchWork)
        editor.escape()
        let finished = expectation(description: "Cancelled search drained")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            work.waitUntilFinished()
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertTrue(work.isCancelled)
        XCTAssertTrue(editor.results.arrangedSubviews.isEmpty)
        XCTAssertTrue(editor.findAll.isHidden)
        XCTAssertTrue(editor.window?.firstResponder === editor.textView)
    }

    @MainActor
    func testEscapeStopsRunningSearchBeforeScanningRemainingTabs() async throws {
        let editor = makeEditor()
        defer { finish() }
        let text = String(repeating: "Příliš žluťoučký kůň\n", count: 200_000)
        editor.notes = (0..<20).map { _ in
            let note = TextDocument()
            note.text = text
            return note
        }
        editor.findAll.stringValue = "absent"
        editor.showSearchAll(nil)
        let work = try XCTUnwrap(editor.searchWork)
        let deadline = Date().addingTimeInterval(3)
        while !work.isExecuting && !work.isFinished && Date() < deadline {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(work.isExecuting)
        let stopped = expectation(description: "Running search stopped")
        editor.escape()
        DispatchQueue.global().async { work.waitUntilFinished(); stopped.fulfill() }
        await fulfillment(of: [stopped], timeout: 0.5)
        XCTAssertTrue(work.isCancelled)
        XCTAssertTrue(editor.results.arrangedSubviews.isEmpty)
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
    func testWrapChangeRepositionsLineNumbersWithoutEditing() throws {
        let defaults = UserDefaults.standard
        let oldWrap = defaults.object(forKey: "wrap")
        let oldLines = defaults.object(forKey: "lineNumbers")
        defaults.set(true, forKey: "wrap")
        defaults.set(true, forKey: "lineNumbers")
        defer {
            defaults.set(oldWrap, forKey: "wrap")
            defaults.set(oldLines, forKey: "lineNumbers")
            finish()
        }
        let text = String(repeating: "long line ", count: 30) + "\nlast\n"
        let editor = makeEditor(text: text)
        editor.window?.setContentSize(NSSize(width: 440, height: 500))
        editor.showWindow(nil)
        editor.window?.contentView?.layoutSubtreeIfNeeded()
        editor.window?.displayIfNeeded()
        let ruler = try XCTUnwrap(editor.textView?.enclosingScrollView?.verticalRulerView as? LineNumbers)
        let wrappedY = try XCTUnwrap(ruler.visibleLineLabels().first { $0.number == 2 }?.origin.y)
        editor.toggleWrap(nil)
        let unwrappedY = try XCTUnwrap(ruler.visibleLineLabels().first { $0.number == 2 }?.origin.y)
        XCTAssertLessThan(unwrappedY, wrappedY)
        XCTAssertEqual(editor.active?.text, text)
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
