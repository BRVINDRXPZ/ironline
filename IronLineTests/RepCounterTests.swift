import XCTest
@testable import IronLine

final class RepCounterTests: XCTestCase {
    func testFullROMRepCounts() {
        var counter = RepCounter()
        let angles: [Double] = [165, 150, 125, 98, 120, 158]
        let events = angles.compactMap { counter.update(angle: $0, confidence: 0.9) }

        XCTAssertEqual(counter.repsCompleted, 1)
        XCTAssertEqual(counter.repsAttempted, 1)
        XCTAssertEqual(events.last, .counted(rep: 1))
    }

    func testShallowAttemptIsNoRep() {
        var counter = RepCounter()
        let angles: [Double] = [165, 145, 125, 118, 140, 160]
        let events = angles.compactMap { counter.update(angle: $0, confidence: 0.9) }

        XCTAssertEqual(counter.repsCompleted, 0)
        XCTAssertEqual(counter.repsAttempted, 1)
        XCTAssertEqual(events.last, .noRep(reason: "INSUFFICIENT ROM"))
    }

    func testLowConfidenceSamplesAreIgnored() {
        var counter = RepCounter()
        _ = counter.update(angle: 165, confidence: 0.9)
        _ = counter.update(angle: 90, confidence: 0.1)
        _ = counter.update(angle: 160, confidence: 0.9)

        XCTAssertEqual(counter.repsCompleted, 0)
        XCTAssertEqual(counter.repsAttempted, 0)
    }

    func testEnteringFrameAtBottomDoesNotCreateGhostRep() {
        var counter = RepCounter()
        let angles: [Double] = [90, 110, 140, 160, 140, 95, 120, 160]
        for angle in angles {
            _ = counter.update(angle: angle, confidence: 0.9)
        }

        XCTAssertEqual(counter.repsCompleted, 1)
        XCTAssertEqual(counter.repsAttempted, 1)
    }
}
