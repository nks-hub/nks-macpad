import AppKit
import XCTest
import MacPadCore

final class FileEncodingPickerTests: XCTestCase {
    @MainActor
    func testBOMlessUTF16PreviewUsesExplicitEncodingAndPreservesBytes() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let text = "Příliš 😀\n"
        let bytes = try XCTUnwrap(text.data(using: .utf16LittleEndian))
        let url = directory.appendingPathComponent("utf16.txt")
        try bytes.write(to: url)
        let picker = FileEncodingPicker(url: url)
        defer { picker.cancel() }
        picker.encoding = .utf16LE
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in picker.isValid }, object: nil)
        await fulfillment(of: [ready], timeout: 3)
        XCTAssertEqual(picker.preview.string, text)
        XCTAssertGreaterThan(picker.preview.visibleRect.width, 100)
        XCTAssertGreaterThan(picker.preview.visibleRect.height, 20)
        XCTAssertEqual(picker.encoding, .utf16LE)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    @MainActor
    func testInvalidUTF8PreviewCanBeCorrectedToWindows1250() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.txt")
        try Data([0x50, 0xF8, 0xED, 0x6C, 0x69, 0x9A]).write(to: url)
        let picker = FileEncodingPicker(url: url)
        defer { picker.cancel() }
        let failed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            picker.preview.string == errorMessage(TextFileCodecError.invalidData(.utf8))
        }, object: nil)
        await fulfillment(of: [failed], timeout: 3)
        XCTAssertFalse(picker.isValid)
        picker.encoding = .windows1250
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in picker.isValid }, object: nil)
        await fulfillment(of: [ready], timeout: 3)
        XCTAssertEqual(picker.preview.string, "Příliš")
    }

    @MainActor
    func testEncodingChoiceFinishesInsideModalAsyncOpenCallback() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.txt")
        try Data([0x50, 0xF8, 0xED, 0x6C, 0x69, 0x9A]).write(to: url)
        let app = AppDelegate(sessionDirectory: directory.appendingPathComponent("session"))
        defer { app.editors.forEach { $0.window?.orderOut(nil) } }
        var confirmed = false
        let deadline = Date().addingTimeInterval(5)
        func picker(in view: NSView) -> FileEncodingPicker? {
            if let picker = view as? FileEncodingPicker { return picker }
            return view.subviews.lazy.compactMap { picker(in: $0) }.first
        }
        let timer = Timer(timeInterval: 0.02, repeats: true) { _ in
            guard let modal = NSApp.modalWindow else { return }
            if Date() > deadline { NSApp.stopModal(withCode: .alertSecondButtonReturn); return }
            guard let content = modal.contentView, let view = picker(in: content) else { return }
            if view.encoding != .windows1250 { view.encoding = .windows1250 }
            if view.isValid && view.preview.string == "Příliš" {
                confirmed = true
                NSApp.stopModal(withCode: .alertFirstButtonReturn)
            }
        }
        RunLoop.main.add(timer, forMode: .modalPanel)
        defer { timer.invalidate() }
        app.open([url])
        let opened = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.editors.flatMap(\.notes).contains { $0.fileURL == url && $0.text == "Příliš" }
        }, object: nil)
        await fulfillment(of: [opened], timeout: 7)
        XCTAssertTrue(confirmed)
        XCTAssertEqual(app.editors.flatMap(\.notes).first(where: { $0.fileURL == url })?.format.encoding, .windows1250)
    }
}
