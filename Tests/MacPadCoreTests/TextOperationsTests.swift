import Foundation
import XCTest
@testable import MacPadCore

final class TextOperationsTests: XCTestCase {
    func testSortingUsesCzechAlphabetIncludingCh() {
        XCTAssertEqual(TextOperations.sortedLines("chata\nžába\nhad\ncibule\n", locale: Locale(identifier: "cs_CZ")),
                       "cibule\nhad\nchata\nžába\n")
    }

    func testSortingPreservesBlankLinesAndFinalNewlineState() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(TextOperations.sortedLines("b\n\na", locale: locale), "\na\nb")
        XCTAssertEqual(TextOperations.sortedLines("b\n\na\n", locale: locale), "\na\nb\n")
        XCTAssertEqual(TextOperations.sortedLines("", locale: locale), "")
        XCTAssertEqual(TextOperations.sortedLines("\n", locale: locale), "\n")
    }

    func testRemovingDuplicatesKeepsFirstOccurrenceCaseAndWhitespace() {
        XCTAssertEqual(TextOperations.uniqueLines("b\na\nb\nA\n a\na \na\n"), "b\na\nA\n a\na \n")
    }

    func testRemovingDuplicatesPreservesFinalNewlineAndOneBlankLine() {
        XCTAssertEqual(TextOperations.uniqueLines("a\na"), "a")
        XCTAssertEqual(TextOperations.uniqueLines("\n\na\n\n"), "\na\n")
        XCTAssertEqual(TextOperations.uniqueLines("\n"), "\n")
        XCTAssertEqual(TextOperations.uniqueLines(""), "")
    }

    func testRemovingDuplicatesDoesNotNormalizeUnicode() {
        let text = "\u{00E9}\ne\u{0301}\n\u{00E9}"
        let result = TextOperations.uniqueLines(text)
        XCTAssertEqual(Array(result.utf8), Array("\u{00E9}\ne\u{0301}".utf8))
    }
}
