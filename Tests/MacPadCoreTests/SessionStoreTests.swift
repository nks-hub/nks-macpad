import Foundation
import XCTest
@testable import MacPadCore

final class SessionStoreTests: XCTestCase {
    private var directory: URL!
    private var store: SessionStore!
    private var currentURL: URL { directory.appendingPathComponent("session.json") }
    private var backupURL: URL { directory.appendingPathComponent("session.backup.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = SessionStore(directory: directory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testFreshStoreDoesNotCreateFilesOnRead() throws {
        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testRestoresUnsavedUnicodeAndWindowState() throws {
        let note = NoteSnapshot(text: "Žlutý 🦋\ntext", title: "Nápad", pinned: true,
                                selectionLocation: 6, selectionLength: 2, scrollY: 42)
        let window = WindowSnapshot(notes: [note], activeNoteID: note.id,
                                    frame: "{{10, 20}, {700, 500}}", quickNote: true, visible: false)
        try store.save(SessionSnapshot(windows: [window]))

        let loaded = try XCTUnwrap(try store.load())
        let restoredWindow = try XCTUnwrap(loaded.windows.first)
        let restored = try XCTUnwrap(restoredWindow.notes.first)
        XCTAssertEqual(restored.id, note.id)
        XCTAssertEqual(restored.text, note.text)
        XCTAssertNil(restored.savedText)
        XCTAssertNil(restored.path)
        XCTAssertEqual(restored.title, "Nápad")
        XCTAssertTrue(restored.pinned)
        XCTAssertEqual(restored.selectionLocation, 6)
        XCTAssertEqual(restored.selectionLength, 2)
        XCTAssertEqual(restored.scrollY, 42)
        XCTAssertEqual(restoredWindow.activeNoteID, note.id)
        XCTAssertEqual(restoredWindow.frame, window.frame)
        XCTAssertTrue(restoredWindow.quickNote)
        XCTAssertFalse(restoredWindow.visible)
        XCTAssertFalse(store.lastLoadRecoveredFromBackup)
    }

    func testSavedBaselineIsDistinctFromEditedText() throws {
        let note = NoteSnapshot(text: "updated", savedText: "original", path: "/tmp/example.txt",
                                savedFormat: TextFormat(), stamp: .existing(sha256: "abc"))
        try store.save(SessionSnapshot(windows: [WindowSnapshot(notes: [note])]))
        let restored = try XCTUnwrap(try store.load()?.windows.first?.notes.first)
        XCTAssertEqual(restored.text, "updated")
        XCTAssertEqual(restored.savedText, "original")
        XCTAssertEqual(restored.savedFormat, note.savedFormat)
        XCTAssertEqual(restored.stamp, note.stamp)
    }

    func testCorruptMainRecoversBackupAndReportsRecovery() throws {
        try store.save(session("retained"))
        try Data("broken JSON".utf8).write(to: currentURL)
        XCTAssertEqual(try store.load()?.windows.first?.notes.first?.text, "retained")
        XCTAssertTrue(store.lastLoadRecoveredFromBackup)
        XCTAssertEqual(try String(contentsOf: currentURL, encoding: .utf8), "broken JSON")

        try store.save(session("continued"))
        XCTAssertEqual(try store.load()?.windows.first?.notes.first?.text, "continued")
        XCTAssertFalse(store.lastLoadRecoveredFromBackup)
    }

    func testBothCorruptCopiesRefuseReadAndWriteWithoutChangingData() throws {
        try store.save(session("important"))
        let current = Data("broken main".utf8)
        let backup = Data("broken backup".utf8)
        try current.write(to: currentURL)
        try backup.write(to: backupURL)
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(session("replacement")))
        XCTAssertEqual(try Data(contentsOf: currentURL), current)
        XCTAssertEqual(try Data(contentsOf: backupURL), backup)
    }

    func testInaccessibleMainRecoversBackupButRefusesOverwrite() throws {
        try assertInaccessibleCopy(at: currentURL, warning: .recoveredFromBackup)
        XCTAssertTrue(store.lastLoadRecoveredFromBackup)
    }

    func testInaccessibleBackupAllowsMainReadButRefusesOverwrite() throws {
        try assertInaccessibleCopy(at: backupURL, warning: .backupUnavailable)
        XCTAssertFalse(store.lastLoadRecoveredFromBackup)
    }

    func testNewerSchemaInEitherCopyPreventsOverwrite() throws {
        try store.save(session("keep"))
        let original = try Data(contentsOf: currentURL)
        let newer = Data(#"{"version":2,"futureState":true}"#.utf8)
        for url in [currentURL, backupURL] {
            try original.write(to: currentURL)
            try original.write(to: backupURL)
            try newer.write(to: url)
            XCTAssertThrowsError(try store.load()) { error in
                guard case SessionStoreError.unsupportedVersion(2) = error else {
                    return XCTFail("Expected an unsupported version error")
                }
            }
            XCTAssertThrowsError(try store.save(session("replacement")))
            XCTAssertEqual(try Data(contentsOf: url), newer)
        }
    }

    func testDiscardPurgesBothCopiesAndCannotReturnThroughRecovery() throws {
        let kept = NoteSnapshot(text: "keep")
        let removed = NoteSnapshot(text: "discarded text", savedText: "discarded baseline")
        try store.save(SessionSnapshot(windows: [WindowSnapshot(notes: [kept, removed])]))
        try store.save(SessionSnapshot(windows: [WindowSnapshot(notes: [kept])]))
        for url in [currentURL, backupURL] {
            let contents = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(contents.contains("discarded"))
        }
        try Data("corrupt".utf8).write(to: currentURL)
        let restored = try XCTUnwrap(try store.load()?.windows.first)
        XCTAssertEqual(restored.notes.map(\.id), [kept.id])
    }

    func testMalformedSelectionInMainFallsBackToBackup() throws {
        try store.save(session("abc"))
        var malformed = session("abc")
        malformed.windows[0].notes[0].selectionLocation = -1
        try JSONEncoder().encode(malformed).write(to: currentURL)
        XCTAssertEqual(try store.load()?.windows.first?.notes.first?.selectionLocation, 0)
        XCTAssertTrue(store.lastLoadRecoveredFromBackup)
    }

    func testInvalidSelectionCannotOverwriteValidSnapshot() throws {
        try store.save(session("original"))
        var invalid = session("abc")
        for (location, length) in [(-1, 0), (4, 0), (1, -1), (1, Int.max)] {
            invalid.windows[0].notes[0].selectionLocation = location
            invalid.windows[0].notes[0].selectionLength = length
            XCTAssertThrowsError(try store.save(invalid))
        }
        XCTAssertEqual(try store.load()?.windows.first?.notes.first?.text, "original")
    }

    func testPrivateDirectoryAndFilePermissions() throws {
        try store.save(session("private"))
        for (url, expected) in [(directory!, 0o700), (currentURL, 0o600), (backupURL, 0o600)] {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
            XCTAssertEqual(permissions.intValue & 0o777, expected)
        }
    }

    func testInvalidIdentitiesCannotOverwriteValidSession() throws {
        try store.save(session("retained"))
        let originalMain = try Data(contentsOf: currentURL)
        let originalBackup = try Data(contentsOf: backupURL)
        for invalid in sessionsWithInvalidIdentities() {
            XCTAssertThrowsError(try store.save(invalid))
            XCTAssertEqual(try Data(contentsOf: currentURL), originalMain)
            XCTAssertEqual(try Data(contentsOf: backupURL), originalBackup)
        }
    }

    func testInvalidIdentitiesInMainRecoverValidBackup() throws {
        try store.save(session("retained"))
        for invalid in sessionsWithInvalidIdentities() {
            try JSONEncoder().encode(invalid).write(to: currentURL)
            XCTAssertEqual(try store.load()?.windows.first?.notes.first?.text, "retained")
            XCTAssertTrue(store.lastLoadRecoveredFromBackup)
        }
    }

    private func sessionsWithInvalidIdentities() -> [SessionSnapshot] {
        let first = NoteSnapshot(text: "first")
        let second = NoteSnapshot(text: "second")
        let firstWindow = WindowSnapshot(notes: [first], activeNoteID: first.id)
        let secondWindow = WindowSnapshot(notes: [second], activeNoteID: second.id)
        let valid = SessionSnapshot(windows: [firstWindow, secondWindow])
        var duplicateWindow = valid
        duplicateWindow.windows[1].id = firstWindow.id
        var duplicateNote = valid
        duplicateNote.windows[0].notes.append(first)
        var duplicateNoteAcrossWindows = valid
        duplicateNoteAcrossWindows.windows[1].notes.append(first)
        var foreignActiveNote = valid
        foreignActiveNote.windows[0].activeNoteID = second.id
        return [duplicateWindow, duplicateNote, duplicateNoteAcrossWindows, foreignActiveNote]
    }

    private func session(_ text: String) -> SessionSnapshot {
        SessionSnapshot(windows: [WindowSnapshot(notes: [NoteSnapshot(text: text)])])
    }

    private func assertInaccessibleCopy(at protectedURL: URL, warning: SessionStoreWarning) throws {
        try store.save(session("retained"))
        let originalMain = try Data(contentsOf: currentURL)
        let originalBackup = try Data(contentsOf: backupURL)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: protectedURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: protectedURL.path) }
        XCTAssertThrowsError(try Data(contentsOf: protectedURL), "Run permission tests as an unprivileged user")
        XCTAssertEqual(try store.load()?.windows.first?.notes.first?.text, "retained")
        XCTAssertEqual(store.lastLoadWarning, warning)
        XCTAssertThrowsError(try store.save(session("replacement"))) { error in
            guard case SessionStoreError.inaccessibleCopy = error else {
                return XCTFail("Expected refusal to overwrite an inaccessible copy")
            }
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: protectedURL.path)
        XCTAssertEqual(try Data(contentsOf: currentURL), originalMain)
        XCTAssertEqual(try Data(contentsOf: backupURL), originalBackup)
    }
}
