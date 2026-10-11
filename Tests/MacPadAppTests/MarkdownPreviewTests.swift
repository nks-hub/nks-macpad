import AppKit
import XCTest

final class MarkdownPreviewTests: XCTestCase {
    @MainActor
    func testNativeParserRendersHeadingsListsTasksAndInlineStyles() throws {
        let rendered = try MarkdownRenderer.render("# Nadpis\n\n**Tučně** a *kurzíva*.\n\n- [x] Hotovo\n- [ ] Zbývá\n\n1. První\n2. Druhý\n", fontSize: 14)
        XCTAssertTrue(rendered.string.contains("Nadpis\n\nTučně a kurzíva."))
        XCTAssertTrue(rendered.string.contains("☑ Hotovo\n☐ Zbývá"))
        XCTAssertTrue(rendered.string.contains("1. První\n2. Druhý"))
        let title = try XCTUnwrap(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertGreaterThan(title.pointSize, 14)
        let bold = (rendered.string as NSString).range(of: "Tučně")
        let italic = (rendered.string as NSString).range(of: "kurzíva")
        XCTAssertTrue((rendered.attribute(.font, at: bold.location, effectiveRange: nil) as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        XCTAssertTrue((rendered.attribute(.font, at: italic.location, effectiveRange: nil) as? NSFont)?.fontDescriptor.symbolicTraits.contains(.italic) == true)
    }

    @MainActor
    func testHTMLImagesAndDangerousLinksDoNotBecomeActiveContent() throws {
        let source = "<script>fetch('https://example.invalid/secret')</script>\n\n<img src='https://example.invalid/pixel'>\n\n![obrázek](https://example.invalid/image.png)\n\n[script](javascript:alert(1)) [file](file:///etc/passwd) [data](data:text/html,hello) [safe](https://example.invalid/page)"
        let rendered = try MarkdownRenderer.render(source, fontSize: 14)
        XCTAssertTrue(rendered.string.contains("<script>"))
        XCTAssertTrue(rendered.string.contains("obrázek"))
        var links: [URL] = []
        rendered.enumerateAttributes(in: NSRange(location: 0, length: rendered.length)) { attributes, _, _ in
            XCTAssertNil(attributes[.attachment])
            XCTAssertNil(attributes[NSAttributedString.Key("NSImageURL")])
            if let link = attributes[.link] as? URL { links.append(link) }
        }
        XCTAssertEqual(links, [URL(string: "https://example.invalid/page")!])
        for link in ["javascript:alert(1)", "data:text/html,x", "file:///etc/passwd", "smb://example.invalid/share", "relative.md", "https:no-host"] {
            XCTAssertNil(MarkdownRenderer.allowedLink(link), link)
        }
    }

    @MainActor
    func testPreviewUpdatesAndSwitchesTabsWithoutChangingSourceOrUndo() async throws {
        _ = NSApplication.shared
        let app = AppDelegate(sessionDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let editor = app.makeWindow()
        let first = TextDocument()
        first.text = "# První 😀\n\n- [ ] Úkol\n"
        editor.addNote(first)
        editor.textView?.setSelectedRange(NSRange(location: 3, length: 2))
        let original = first.text
        let originalRevision = first.revision
        editor.toggleMarkdownPreview(nil)
        defer { editor.markdownPreview?.cancel(); editor.window?.orderOut(nil) }
        let preview = try XCTUnwrap(editor.markdownPreview)
        await waitForPreview(preview, note: first)
        XCTAssertFalse(preview.textView.isEditable)
        XCTAssertEqual(first.text, original)
        XCTAssertEqual(first.revision, originalRevision)
        XCTAssertFalse(first.undoManager?.canUndo ?? true)
        XCTAssertEqual(editor.textView?.selectedRange(), NSRange(location: 3, length: 2))
        editor.textView?.insertText("Nový ", replacementRange: NSRange(location: 2, length: 0))
        await waitForPreview(preview, note: first)
        XCTAssertTrue(preview.textView.string.contains("Nový První"))
        first.undoManager?.undo()
        await waitForPreview(preview, note: first)
        XCTAssertEqual(first.text, original)
        let second = TextDocument()
        second.text = "# Druhá karta"
        editor.addNote(second)
        await waitForPreview(preview, note: second)
        XCTAssertEqual(preview.textView.string, "Druhá karta")
        editor.window?.contentView?.layoutSubtreeIfNeeded()
        let splitWidth = editor.textView?.enclosingScrollView?.frame.width ?? 0
        XCTAssertGreaterThan(splitWidth, 100)
        XCTAssertLessThan(splitWidth, editor.body.bounds.width * 0.7)
        editor.toggleMarkdownPreview(nil)
        editor.window?.contentView?.layoutSubtreeIfNeeded()
        XCTAssertNil(editor.markdownPreview)
        XCTAssertGreaterThan(editor.textView?.enclosingScrollView?.frame.width ?? 0, splitWidth * 1.5)
    }

    @MainActor
    private func waitForPreview(_ preview: MarkdownPreview, note: TextDocument) async {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            preview.renderedNoteID == note.id && preview.renderedRevision == note.revision
        }, object: nil)
        await fulfillment(of: [ready], timeout: 5)
    }
}
