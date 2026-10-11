import AppKit
import Carbon
import XCTest

final class QuickNoteTests: XCTestCase {
    @MainActor
    func testShortcutCollisionAndRelease() throws {
        _ = NSApplication.shared
        let modifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        var first: QuickNoteShortcut? = try QuickNoteShortcut(keyCode: UInt32(kVK_F19), modifiers: modifiers) {}
        XCTAssertNotNil(first)
        XCTAssertThrowsError(try QuickNoteShortcut(keyCode: UInt32(kVK_F19), modifiers: modifiers) {})
        first = nil
        let reused = try QuickNoteShortcut(keyCode: UInt32(kVK_F19), modifiers: modifiers) {}
        withExtendedLifetime(reused) {}
    }

    @MainActor
    func testQuickNoteStaysVisibleUntilSnapshotFinishesAndReusesDraft() async throws {
        _ = NSApplication.shared
        let oldRestore = UserDefaults.standard.object(forKey: "restore")
        Preferences.restore = true
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let app = AppDelegate(sessionDirectory: directory)
        defer {
            app.editors.forEach { $0.window?.orderOut(nil) }
            UserDefaults.standard.set(oldRestore, forKey: "restore")
            try? FileManager.default.removeItem(at: directory)
        }
        app.quickNote(nil)
        let quick = try XCTUnwrap(app.editors.first(where: \.quick))
        let note = try XCTUnwrap(quick.active)
        quick.textView?.insertText("Příliš žluťoučký 😀", replacementRange: NSRange(location: 0, length: 0))
        let gate = DispatchSemaphore(value: 0)
        app.diskQueue.async { gate.wait() }
        quick.escape()
        XCTAssertTrue(quick.busyClosing)
        XCTAssertTrue(quick.window?.isVisible == true)
        gate.signal()
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !quick.busyClosing }, object: nil)
        await fulfillment(of: [hidden], timeout: 3)
        XCTAssertFalse(quick.window?.isVisible == true)
        let snapshot = try XCTUnwrap(app.sessionStore.load())
        XCTAssertEqual(snapshot.windows.flatMap(\.notes).first(where: { $0.id == note.id })?.text, note.text)
        app.quickNote(nil)
        XCTAssertEqual(app.editors.filter(\.quick).count, 1)
        XCTAssertTrue(quick.active === note)
        XCTAssertEqual(quick.notes.count, 1)
        XCTAssertEqual(quick.textView?.string, "Příliš žluťoučký 😀")
    }
}
