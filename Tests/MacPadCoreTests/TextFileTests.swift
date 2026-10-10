import XCTest
@testable import MacPadCore

final class TextFileTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("MacPadFiles-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testUnicodeFormatsPreserveBOMAndNewlines() throws {
        let text = "Příliš žluťoučký kůň 🐴\nDruhý řádek\n"
        for encoding in [TextEncoding.utf8, .utf8BOM, .utf16LE, .utf16BE] {
            for ending in [LineEnding.lf, .crlf, .cr] {
                let format = TextFormat(encoding: encoding, lineEnding: ending)
                let bytes = try TextFileCodec.encode(text, format: format)
                let decoded = try TextFileCodec.decode(bytes)
                XCTAssertEqual(decoded.text, text)
                XCTAssertEqual(decoded.format, format)
                XCTAssertEqual(try TextFileCodec.encode(decoded.text, format: decoded.format), bytes)
            }
        }
    }

    func testKnownByteSequencesAndExplicitBOMlessUTF16() throws {
        XCTAssertEqual(try TextFileCodec.encode("A", format: TextFormat(encoding: .utf16LE)), Data([0xFF, 0xFE, 65, 0]))
        XCTAssertEqual(try TextFileCodec.encode("A", format: TextFormat(encoding: .utf16BE)), Data([0xFE, 0xFF, 0, 65]))
        XCTAssertEqual(try TextFileCodec.encode("A", format: TextFormat(encoding: .utf8BOM)), Data([0xEF, 0xBB, 0xBF, 65]))
        XCTAssertEqual(try TextFileCodec.decode(Data([65, 0]), encoding: .utf16LE).text, "A")
        XCTAssertEqual(try TextFileCodec.decode(Data([0, 65]), encoding: .utf16BE).text, "A")
        XCTAssertEqual(try TextFileCodec.decode(Data()).text, "")
    }

    func testWindows1250RequiresExplicitSelectionAndRejectsLoss() throws {
        let bytes = Data([0x50, 0xF8, 0xED, 0x6C, 0x69, 0x9A])
        let decoded = try TextFileCodec.decode(bytes, encoding: .windows1250)
        XCTAssertEqual(decoded.text, "Příliš")
        XCTAssertEqual(try TextFileCodec.encode(decoded.text, format: decoded.format), bytes)
        XCTAssertThrowsError(try TextFileCodec.decode(bytes))
        XCTAssertThrowsError(try TextFileCodec.encode("📝", format: TextFormat(encoding: .windows1250))) {
            XCTAssertEqual($0 as? TextFileCodecError, .unrepresentableText(.windows1250))
        }
        XCTAssertThrowsError(try TextFileCodec.encode("e\u{301}", format: TextFormat(encoding: .windows1250)))
    }

    func testExplicitBOMlessUTF16RoundTripAndFormatPersistence() throws {
        for (encoding, bytes) in [(TextEncoding.utf16LE, Data([65, 0, 10, 0])),
                                  (TextEncoding.utf16BE, Data([0, 65, 0, 10]))] {
            let decoded = try TextFileCodec.decode(bytes, encoding: encoding)
            XCTAssertFalse(decoded.format.hasBOM)
            XCTAssertEqual(try TextFileCodec.encode(decoded.text, format: decoded.format), bytes)
            let restored = try JSONDecoder().decode(TextFormat.self, from: JSONEncoder().encode(decoded.format))
            XCTAssertFalse(restored.hasBOM)
        }
        let oldFormat = Data(#"{"encoding":"utf16LE","lineEnding":"crlf"}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(TextFormat.self, from: oldFormat).hasBOM)
    }

    func testBOMOverridesPreviouslySelectedEncoding() throws {
        let text = "Příliš 📝\n"
        for (current, previous) in [(TextEncoding.utf16BE, TextEncoding.utf16LE),
                                    (.utf8BOM, .windows1250)] {
            let format = TextFormat(encoding: current, lineEnding: .lf)
            let bytes = try TextFileCodec.encode(text, format: format)
            let decoded = try TextFileCodec.decode(bytes, encoding: previous)
            XCTAssertEqual(decoded.text, text)
            XCTAssertEqual(decoded.format, format)
            XCTAssertEqual(try TextFileCodec.encode(decoded.text, format: decoded.format), bytes)
        }
    }

    func testRemovedUTF8BOMStaysRemovedWithPreviousEncoding() throws {
        let bytes = Data("Příliš\n".utf8)
        let decoded = try TextFileCodec.decode(bytes, encoding: .utf8BOM)
        XCTAssertEqual(decoded.format.encoding, .utf8)
        XCTAssertFalse(decoded.format.hasBOM)
        XCTAssertEqual(try TextFileCodec.encode(decoded.text, format: decoded.format), bytes)
    }

    func testUTF32BOMIsRejectedInsteadOfDecodingAsUTF16() {
        for bytes in [Data([0xFF, 0xFE, 0, 0, 65, 0, 0, 0]), Data([0, 0, 0xFE, 0xFF, 0, 0, 0, 65])] {
            XCTAssertThrowsError(try TextFileCodec.decode(bytes, encoding: .windows1250)) {
                XCTAssertEqual($0 as? TextFileCodecError, .unsupportedUTF32)
            }
        }
    }

    func testInvalidUTF8AndUTF16AreNotSilentlyRepaired() {
        for data in [Data([0xC0, 0xAF]), Data([0xFF]), Data([0xED, 0xA0, 0x80])] {
            XCTAssertThrowsError(try TextFileCodec.decode(data))
        }
        for data in [Data([0xFF, 0xFE, 0]), Data([0xFF, 0xFE, 0, 0xD8]),
                     Data([0xFE, 0xFF, 0xDC, 0]), Data([0xFF, 0xFE, 0, 0xD8, 65, 0])] {
            XCTAssertThrowsError(try TextFileCodec.decode(data))
        }
    }

    func testMixedLineEndingsRequireExplicitConversion() throws {
        let decoded = try TextFileCodec.decode(Data("a\r\nb\nc\rd".utf8))
        XCTAssertEqual(decoded.text, "a\nb\nc\nd")
        XCTAssertEqual(decoded.format.lineEnding, .mixed)
        XCTAssertThrowsError(try TextFileCodec.encode(decoded.text, format: decoded.format)) {
            XCTAssertEqual($0 as? TextFileCodecError, .mixedLineEndings)
        }
        XCTAssertEqual(try TextFileCodec.encode(decoded.text, format: TextFormat(lineEnding: .crlf)), Data("a\r\nb\r\nc\r\nd".utf8))
    }

    func testCreateSaveReadAndPermissions() throws {
        let file = directory.appendingPathComponent("note.txt")
        XCTAssertEqual(try TextFileStore.stamp(file), .missing)
        let first = try TextFileStore.write("one\ntwo", format: TextFormat(), to: file, expected: .missing)
        XCTAssertEqual(try Data(contentsOf: file), Data("one\r\ntwo".utf8))
        let loaded = try TextFileStore.read(file)
        XCTAssertEqual(loaded.text, "one\ntwo")
        XCTAssertEqual(loaded.stamp, first)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)
        let second = try TextFileStore.write("changed", format: loaded.format, to: file, expected: first)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try TextFileStore.read(file).text, "changed")
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)?.intValue, 0o640)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["note.txt"])
    }

    func testChangedOrDeletedFileCannotBeOverwrittenUsingOldStamp() throws {
        let file = directory.appendingPathComponent("note.txt")
        let old = try TextFileStore.write("original", format: TextFormat(), to: file, expected: .missing)
        try Data("external".utf8).write(to: file)
        let external = try TextFileStore.stamp(file)
        XCTAssertThrowsError(try TextFileStore.write("ours", format: TextFormat(), to: file, expected: old)) {
            XCTAssertEqual($0 as? TextFileStoreError, .conflict(expected: old, actual: external))
        }
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "external")
        try FileManager.default.removeItem(at: file)
        XCTAssertThrowsError(try TextFileStore.write("ours", format: TextFormat(), to: file, expected: old)) {
            XCTAssertEqual($0 as? TextFileStoreError, .conflict(expected: old, actual: .missing))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testLongFilenameCanBeReplacedWithoutLeavingBackup() throws {
        let file = directory.appendingPathComponent(String(repeating: "a", count: 230) + ".txt")
        let old = try TextFileStore.write("original", format: TextFormat(), to: file, expected: .missing)
        _ = try TextFileStore.write("updated", format: TextFormat(), to: file, expected: old)
        XCTAssertEqual(try TextFileStore.read(file).text, "updated")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [file.lastPathComponent])
    }

    func testReadOnlyFileCannotBeReplacedAndKeepsItsContents() throws {
        let file = directory.appendingPathComponent("read-only.txt")
        let old = try TextFileStore.write("original", format: TextFormat(), to: file, expected: .missing)
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }
        XCTAssertFalse(FileManager.default.isWritableFile(atPath: file.path), "Run permission tests as an unprivileged user")
        XCTAssertThrowsError(try TextFileStore.write("updated", format: TextFormat(), to: file, expected: old)) {
            XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteNoPermission)
        }
        XCTAssertEqual(try Data(contentsOf: file), Data("original".utf8))
    }

    func testReadOnlyDirectoryPreventsCreationAndReplacement() throws {
        let file = directory.appendingPathComponent("existing.txt")
        let newFile = directory.appendingPathComponent("new.txt")
        let old = try TextFileStore.write("original", format: TextFormat(), to: file, expected: .missing)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
        XCTAssertFalse(FileManager.default.isWritableFile(atPath: directory.path), "Run permission tests as an unprivileged user")
        XCTAssertThrowsError(try TextFileStore.write("updated", format: TextFormat(), to: file, expected: old))
        XCTAssertThrowsError(try TextFileStore.write("new", format: TextFormat(), to: newFile, expected: .missing))
        XCTAssertEqual(try Data(contentsOf: file), Data("original".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: newFile.path))
    }

    func testFailedEncodingLeavesOriginalFileIntact() throws {
        let file = directory.appendingPathComponent("note.txt")
        let stamp = try TextFileStore.write("original", format: TextFormat(), to: file, expected: .missing)
        XCTAssertThrowsError(try TextFileStore.write("📝", format: TextFormat(encoding: .windows1250), to: file, expected: stamp))
        XCTAssertEqual(try Data(contentsOf: file), Data("original".utf8))
        XCTAssertEqual(try TextFileStore.stamp(file), stamp)
    }

    func testUncoordinatedWriterAfterFinalCheckIsPreserved() throws {
        let file = directory.appendingPathComponent("note.txt")
        let old = try TextFileStore.write("original", format: TextFormat(), to: file, expected: .missing)
        var recovery: URL?
        var written: FileStamp?
        XCTAssertThrowsError(try TextFileStore.write("ours", format: TextFormat(), to: file, expected: old,
                                                    beforeReplace: { try Data("external".utf8).write(to: file) })) {
            guard case TextFileStoreError.conflictRecovered(let saved, let stamp) = $0 else {
                return XCTFail("Expected recovery path, received \($0)")
            }
            recovery = saved
            written = stamp
        }
        let backup = try XCTUnwrap(recovery)
        XCTAssertEqual(try Data(contentsOf: backup), Data("external".utf8))
        XCTAssertEqual(try Data(contentsOf: file), Data("ours".utf8))
        XCTAssertEqual(written, try TextFileStore.stamp(file))
    }

    func testNewFileFollowsUmaskAndReplacedFileKeepsItsMode() throws {
        let file = directory.appendingPathComponent("shared.txt")
        let mask = umask(0)
        umask(mask)
        func mode() throws -> mode_t {
            mode_t(truncating: try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as! NSNumber)
        }
        let first = try TextFileStore.write("a", format: TextFormat(), to: file, expected: .missing)
        XCTAssertEqual(try mode(), 0o666 & ~mask)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)
        _ = try TextFileStore.write("b", format: TextFormat(), to: file, expected: first)
        XCTAssertEqual(try mode(), 0o640)
    }

    func testSymlinkWritesTargetAndHardlinksShareIdentity() throws {
        let file = directory.appendingPathComponent("note.txt")
        let symbolic = directory.appendingPathComponent("symbolic.txt")
        let hard = directory.appendingPathComponent("hard.txt")
        let old = try TextFileStore.write("original", format: TextFormat(), to: file, expected: .missing)
        try FileManager.default.createSymbolicLink(at: symbolic, withDestinationURL: file)
        try FileManager.default.linkItem(at: file, to: hard)
        XCTAssertEqual(try TextFileStore.identity(file), try TextFileStore.identity(symbolic))
        XCTAssertEqual(try TextFileStore.identity(file), try TextFileStore.identity(hard))
        _ = try TextFileStore.write("new", format: TextFormat(), to: symbolic, expected: old)
        XCTAssertEqual(try TextFileStore.read(file).text, "new")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: symbolic.path), file.path)
    }

    func testDirectoryCannotBeOpenedOrReplaced() throws {
        XCTAssertThrowsError(try TextFileStore.read(directory))
        XCTAssertThrowsError(try TextFileStore.write("text", format: TextFormat(), to: directory, expected: .missing))
        XCTAssertTrue(try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
    }
}
