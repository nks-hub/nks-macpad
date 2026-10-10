import AppKit
import XCTest
import MacPadCore

final class PerformanceTests: XCTestCase {
    @MainActor func testOneMiBDocument() async throws { try await sampleDocument(mebibytes: 1) }
    @MainActor func testTenMiBDocument() async throws { try await sampleDocument(mebibytes: 10) }
    @MainActor func testFiftyMiBDocument() async throws { try await sampleDocument(mebibytes: 50) }
    @MainActor func testTwoMillionCharacterLine() async throws {
        try await sampleDocument(mebibytes: 2, line: String(repeating: "x", count: 2_000_000) + "\n")
    }
    @MainActor func testTenMiBCzechDocument() async throws {
        try await sampleDocument(mebibytes: 10, line: "Příliš žluťoučký kůň úpěl ďábelské ódy 0123456789\n")
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
                openTimes.append(ProcessInfo.processInfo.systemUptime - openedAt)
                let end = (view.string as NSString).length
                let navigatedAt = ProcessInfo.processInfo.systemUptime
                view.setSelectedRange(NSRange(location: end, length: 0))
                view.scrollRangeToVisible(view.selectedRange())
                navigationTimes.append(ProcessInfo.processInfo.systemUptime - navigatedAt)
                let editedAt = ProcessInfo.processInfo.systemUptime
                view.insertText("x", replacementRange: NSRange(location: end, length: 0))
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
        print(String(format: "PERFORMANCE %d MiB %@ open median=%.3fs max=%.3fs edit median=%.3fs max=%.3fs navigation median=%.3fs max=%.3fs",
                     mebibytes, line.utf8.count == line.utf16.count ? "ASCII" : "Unicode", open[2], open[4], edit[2], edit[4], navigation[2], navigation[4]))
    }
}
