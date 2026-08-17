import XCTest
@testable import IronLine

final class FirstPlayableTestLedgerTests: XCTestCase {
    func testPerfectAgreementMeetsNinetyPercentGate() {
        var ledger = FirstPlayableTestLedger()
        ledger.append(record(ironVerified: 10, ironNoReps: 2, humanVerified: 10, humanNoReps: 2))

        let summary = ledger.summary

        XCTAssertEqual(summary.repCountAgreement, 1, accuracy: 0.0001)
        XCTAssertTrue(summary.meetsRepAgreementGate)
        XCTAssertEqual(summary.totalHumanAttempts, 12)
        XCTAssertEqual(summary.totalIronResolvedAttempts, 12)
    }

    func testOneMissingVerifiedRepAcrossTenAttemptsMeetsGate() {
        var ledger = FirstPlayableTestLedger()
        ledger.append(record(ironVerified: 8, ironNoReps: 2, humanVerified: 9, humanNoReps: 1))

        XCTAssertEqual(ledger.summary.repCountAgreement, 0.9, accuracy: 0.0001)
        XCTAssertTrue(ledger.summary.meetsRepAgreementGate)
    }

    func testTwoMissingVerifiedRepsAcrossTenAttemptsFailsGate() {
        var ledger = FirstPlayableTestLedger()
        ledger.append(record(ironVerified: 7, ironNoReps: 3, humanVerified: 9, humanNoReps: 1))

        XCTAssertEqual(ledger.summary.repCountAgreement, 0.8, accuracy: 0.0001)
        XCTAssertFalse(ledger.summary.meetsRepAgreementGate)
    }

    func testTrustAndCompetitiveTensionRatesIgnoreUnansweredSets() {
        var ledger = FirstPlayableTestLedger()
        ledger.append(record(
            ironVerified: 10,
            ironNoReps: 1,
            humanVerified: 10,
            humanNoReps: 1,
            agreed: true,
            pushed: true
        ))
        ledger.append(record(
            ironVerified: 8,
            ironNoReps: 2,
            humanVerified: 8,
            humanNoReps: 2,
            agreed: false,
            pushed: false
        ))
        ledger.append(record(
            ironVerified: 9,
            ironNoReps: 0,
            humanVerified: 9,
            humanNoReps: 0,
            agreed: nil,
            pushed: nil
        ))

        XCTAssertEqual(ledger.summary.noRepTrustRate, 0.5)
        XCTAssertEqual(ledger.summary.linePushRate, 0.5)
    }

    func testLedgerRoundTripsThroughLocalStore() throws {
        let suiteName = "FirstPlayableTestLedgerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var ledger = FirstPlayableTestLedger()
        ledger.append(record(
            ironVerified: 11,
            ironNoReps: 1,
            humanVerified: 11,
            humanNoReps: 1,
            trackingGaps: 2,
            agreed: true,
            pushed: true
        ))

        FirstPlayableTestStore.save(ledger, defaults: defaults)
        let restored = FirstPlayableTestStore.load(defaults: defaults)

        XCTAssertEqual(restored, ledger)
        XCTAssertEqual(restored.summary.totalTrackingGaps, 2)
    }

    private func record(
        ironVerified: Int,
        ironNoReps: Int,
        humanVerified: Int,
        humanNoReps: Int,
        trackingGaps: Int = 0,
        agreed: Bool? = nil,
        pushed: Bool? = nil
    ) -> FirstPlayableSetRecord {
        FirstPlayableSetRecord(
            weight: 70,
            ironVerifiedReps: ironVerified,
            ironNoReps: ironNoReps,
            ironTrackingGaps: trackingGaps,
            humanCompletedReps: humanVerified,
            humanShallowNoReps: humanNoReps,
            agreedWithEveryNoRepCall: agreed,
            lineMadeUserPushHarder: pushed,
            lineScorePercent: 0
        )
    }
}
