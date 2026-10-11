import AppKit
import XCTest
import MacPadCore

final class PerformanceTests: XCTestCase {
    @MainActor func testOneMiBDocument() async throws { try await sampleDocument(mebibytes: 1) }
    @MainActor func testTenMiBDocument() async throws { try await sampleDocument(mebibytes: 10) }
    @MainActor func testFiftyMiBDocument() async throws { try await sampleDocument(mebibytes: 50) }
    @MainActor func testOneMiBInsertion() throws { try sampleInsertion(mebibytes: 1) }
    @MainActor func testTenMiBInsertion() throws { try sampleInsertion(mebibytes: 10) }
    @MainActor func testTwoMillionCharacterLine() async throws {
        try await sampleDocument(mebibytes: 2, line: String(repeating: "x", count: 2_000_000) + "\n")
    }
    @MainActor func testTenMiBCzechDocument() async throws {
        try await sampleDocument(mebibytes: 10, line: "Příliš žluťoučký kůň úpěl ďábelské ódy 0123456789\n")
    }

    /// Time from the command until results are listed, including the 0.15 s typing pause before a search starts.
    @MainActor
    func testSearchAcrossTwentyTabsWithTenMiB() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let app = AppDelegate(sessionDirectory: directory)
        defer {
            app.editors.forEach { $0.window?.orderOut(nil) }
            try? FileManager.default.removeItem(at: directory)
        }
        let editor = app.makeWindow()
        let line = "Příliš žluťoučký kůň úpěl ďábelské ódy 0123456789\n"
        let text = String(repeating: line, count: 10 * 1_048_576 / 20 / line.utf8.count) + "hledaný výraz\n"
        for _ in 0..<20 {
            let note = TextDocument()
            note.text = text
            editor.addNote(note)
        }
        editor.showWindow(nil)
        var times: [Double] = []
        for _ in 0..<5 {
            editor.findAll.stringValue = "hledaný"
            let started = ProcessInfo.processInfo.systemUptime
            editor.showSearchAll(nil)
            // XCTNSPredicateExpectation polls about once a second, too coarse for this measurement.
            while editor.results.arrangedSubviews.count != 21 && ProcessInfo.processInfo.systemUptime - started < 10 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.002))
            }
            XCTAssertEqual(editor.results.arrangedSubviews.count, 21)
            editor.window?.contentView?.layoutSubtreeIfNeeded()
            editor.window?.displayIfNeeded()
            times.append(ProcessInfo.processInfo.systemUptime - started)
            editor.escape()
        }
        times.sort()
        print(String(format: "PERFORMANCE search 20 tabs 10 MiB median=%.3fs max=%.3fs", times[2], times[4]))
    }

    @MainActor
    func testQuickNoteInvocation() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let app = AppDelegate(sessionDirectory: directory)
        defer {
            app.editors.forEach { $0.window?.orderOut(nil) }
            try? FileManager.default.removeItem(at: directory)
        }
        app.newWindow(nil)
        var times: [Double] = []
        for _ in 0..<5 {
            let started = ProcessInfo.processInfo.systemUptime
            app.quickNote(nil)
            let quick = try XCTUnwrap(app.editors.first(where: \.quick))
            quick.window?.displayIfNeeded()
            XCTAssertEqual(quick.window?.isVisible, true)
            times.append(ProcessInfo.processInfo.systemUptime - started)
            quick.window?.orderOut(nil)
        }
        times.sort()
        print(String(format: "PERFORMANCE quick note median=%.3fs max=%.3fs", times[2], times[4]))
    }

    @MainActor
    private func sampleDocument(mebibytes: Int, line: String = String(repeating: "0123456789", count: 7) + "\n") async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let content = String(repeating: line, count: mebibytes * 1_048_576 / line.utf8.count)
        let url = directory.appendingPathComponent("sample.txt")
        try Data(content.utf8).write(to: url)
        var openTimes: [Double] = []
        var editTimes: [Double] = []
        var navigationTimes: [Double] = []
        for _ in 0..<5 {
            let (app, editor) = try autoreleasepool { () -> (AppDelegate, EditorWindowController) in
                let app = AppDelegate(sessionDirectory: directory.appendingPathComponent(UUID().uuidString))
                let editor = app.makeWindow()
                let note = TextDocument()
                let openedAt = ProcessInfo.processInfo.systemUptime
                try note.load(url)
                editor.addNote(note)
                editor.showWindow(nil)
                editor.window?.contentView?.layoutSubtreeIfNeeded()
                let view = try XCTUnwrap(editor.textView)
                if let container = view.textContainer {
                    view.layoutManager?.ensureLayout(forBoundingRect: view.visibleRect, in: container)
                }
                editor.window?.displayIfNeeded()
                openTimes.append(ProcessInfo.processInfo.systemUptime - openedAt)
                let end = (view.string as NSString).length
                let navigatedAt = ProcessInfo.processInfo.systemUptime
                view.setSelectedRange(NSRange(location: end, length: 0))
                view.scrollRangeToVisible(view.selectedRange())
                editor.window?.displayIfNeeded()
                navigationTimes.append(ProcessInfo.processInfo.systemUptime - navigatedAt)
                let editedAt = ProcessInfo.processInfo.systemUptime
                view.insertText("x", replacementRange: NSRange(location: end, length: 0))
                editor.window?.displayIfNeeded()
                editTimes.append(ProcessInfo.processInfo.systemUptime - editedAt)
                XCTAssertEqual(note.text.utf8.count, content.utf8.count + 1)
                XCTAssertTrue(note.isDocumentEdited)
                return (app, editor)
            }
            let drained = expectation(description: "Background file checks finished")
            app.diskQueue.async { drained.fulfill() }
            await fulfillment(of: [drained], timeout: 10)
            editor.window?.delegate = nil
            editor.window?.close()
        }
        let open = openTimes.sorted()
        let edit = editTimes.sorted()
        let navigation = navigationTimes.sorted()
        print(String(format: "PERFORMANCE with display %d MiB %@ open median=%.3fs max=%.3fs edit median=%.3fs max=%.3fs navigation median=%.3fs max=%.3fs",
                     mebibytes, line.utf8.count == line.utf16.count ? "ASCII" : "Unicode", open[2], open[4], edit[2], edit[4], navigation[2], navigation[4]))
    }

    @MainActor
    private func sampleInsertion(mebibytes: Int) throws {
        _ = NSApplication.shared
        let line = "Příliš žluťoučký kůň 0123456789\n"
        let text = String(repeating: line, count: mebibytes * 1_048_576 / line.utf8.count)
        var times: [Double] = []
        for _ in 0..<5 {
            try autoreleasepool {
                let app = AppDelegate(sessionDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
                let editor = app.makeWindow()
                defer { editor.window?.delegate = nil; editor.window?.close() }
                let note = TextDocument()
                editor.addNote(note)
                editor.showWindow(nil)
                let view = try XCTUnwrap(editor.textView)
                let started = ProcessInfo.processInfo.systemUptime
                view.insertText(text, replacementRange: NSRange(location: 0, length: 0))
                view.scrollRangeToVisible(view.selectedRange())
                editor.window?.contentView?.layoutSubtreeIfNeeded()
                editor.window?.displayIfNeeded()
                times.append(ProcessInfo.processInfo.systemUptime - started)
                XCTAssertEqual(note.text, text)
                view.breakUndoCoalescing()
                note.undoManager?.undo()
                XCTAssertEqual(note.text, "")
            }
        }
        times.sort()
        print(String(format: "PERFORMANCE with display %d MiB Unicode insertion median=%.3fs max=%.3fs", mebibytes, times[2], times[4]))
    }
}
