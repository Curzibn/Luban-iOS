import XCTest
@testable import Luban

final class CompressionCalculatorTests: XCTestCase {
    private let calculator = CompressionCalculator()

    func testStandardLargeImageShrinksShortSideToBase() {
        let target = calculator.calculateTarget(width: 1920, height: 1080)

        XCTAssertEqual(target.width, 1920)
        XCTAssertEqual(target.height, 1080)
        XCTAssertEqual(target.estimatedSizeKb, 228)
        XCTAssertFalse(target.isLongImage)
        XCTAssertNil(target.targetSizeKb)
        XCTAssertEqual(target.width % 2, 0)
        XCTAssertEqual(target.height % 2, 0)
    }

    func testSmallImageStaysUnchanged() {
        let target = calculator.calculateTarget(width: 100, height: 100)

        XCTAssertEqual(target.width, 100)
        XCTAssertEqual(target.height, 100)
        XCTAssertEqual(target.estimatedSizeKb, 20)
        XCTAssertFalse(target.isLongImage)
        XCTAssertNil(target.targetSizeKb)
    }

    func testLongImageGetsTargetSizeConstraint() {
        let target = calculator.calculateTarget(width: 1000, height: 4000)

        XCTAssertEqual(target.width, 1000)
        XCTAssertEqual(target.height, 4000)
        XCTAssertEqual(target.estimatedSizeKb, 100)
        XCTAssertTrue(target.isLongImage)
        XCTAssertEqual(target.targetSizeKb, 100)
    }

    func testZeroOrNegativeDimensionsReturnZeroTarget() {
        XCTAssertEqual(calculator.calculateTarget(width: 0, height: 0).width, 0)
        XCTAssertEqual(calculator.calculateTarget(width: 0, height: 0).height, 0)
        XCTAssertEqual(calculator.calculateTarget(width: -100, height: 100).width, 0)
        XCTAssertEqual(calculator.calculateTarget(width: -100, height: 100).height, 0)
    }

    func testOddDimensionsAlignToEven() {
        let target = calculator.calculateTarget(width: 1333, height: 750)

        XCTAssertEqual(target.width, 1332)
        XCTAssertEqual(target.height, 750)
        XCTAssertEqual(target.estimatedSizeKb, 149)
        XCTAssertFalse(target.isLongImage)
    }

    func testLongImageWallClampsLongSideToBase() {
        let target = calculator.calculateTarget(width: 5000, height: 12000)

        XCTAssertEqual(target.width, 600)
        XCTAssertEqual(target.height, 1440)
        XCTAssertEqual(target.estimatedSizeKb, 129)
        XCTAssertTrue(target.isLongImage)
        XCTAssertEqual(target.targetSizeKb, 129)
    }

    func testHugePixelCountTriggersQuarterTrap() {
        let target = calculator.calculateTarget(width: 3000, height: 14000)

        XCTAssertEqual(target.width, 750)
        XCTAssertEqual(target.height, 3500)
        XCTAssertEqual(target.estimatedSizeKb, 288)
        XCTAssertTrue(target.isLongImage)
        XCTAssertEqual(target.targetSizeKb, 288)
    }

    func testPixelCapScalesDownTarget() {
        let target = calculator.calculateTarget(width: 2000, height: 10000)

        XCTAssertEqual(target.width, 1428)
        XCTAssertEqual(target.height, 7148)
        XCTAssertEqual(target.estimatedSizeKb, 255)
        XCTAssertTrue(target.isLongImage)
        XCTAssertEqual(target.targetSizeKb, 255)
    }

    func testNarrowImageGetsSizeFloor() {
        let target = calculator.calculateTarget(width: 500, height: 3000)

        XCTAssertEqual(target.width, 500)
        XCTAssertEqual(target.height, 3000)
        XCTAssertEqual(target.estimatedSizeKb, 250)
        XCTAssertTrue(target.isLongImage)
        XCTAssertEqual(target.targetSizeKb, 250)
    }
}
