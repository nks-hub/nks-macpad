import XCTest
import MacPadCore

final class LineComparisonTests: XCTestCase {
    func testInsertedAndRemovedCzechLinesKeepUnchangedLines() {
        let value = LineComparison(local: "společný\nstarý\nřádek\n", disk: "společný\nnový\nřádek\nnavíc\n")
        XCTAssertEqual(value.localChanges, [1])
        XCTAssertEqual(value.diskChanges, [1, 3])
        XCTAssertEqual(value.annotatedLocal(), "  1  společný\n− 2  starý\n  3  řádek\n  4  ")
        XCTAssertEqual(value.annotatedDisk(), "  1  společný\n+ 2  nový\n  3  řádek\n+ 4  navíc\n  5  ")
    }

    func testDifferentUnicodeBytesAndFinalNewlineAreVisible() {
        let value = LineComparison(local: "é\n", disk: "e\u{301}")
        XCTAssertEqual(value.localChanges, [0, 1])
        XCTAssertEqual(value.diskChanges, [0])
        XCTAssertEqual(LineComparison(local: "", disk: "").localChanges, [])
    }
}
