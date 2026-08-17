import Foundation

struct FirstPlayableSetRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let recordedAt: Date
    let weight: Double
    let ironVerifiedReps: Int
    let ironNoReps: Int
    let ironTrackingGaps: Int
    let humanCompletedReps: Int
    let humanShallowNoReps: Int
    let agreedWithEveryNoRepCall: Bool?
    let lineMadeUserPushHarder: Bool?
    let lineScorePercent: Double

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        weight: Double,
        ironVerifiedReps: Int,
        ironNoReps: Int,
        ironTrackingGaps: Int,
        humanCompletedReps: Int,
        humanShallowNoReps: Int,
        agreedWithEveryNoRepCall: Bool?,
        lineMadeUserPushHarder: Bool?,
        lineScorePercent: Double
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.weight = weight
        self.ironVerifiedReps = max(0, ironVerifiedReps)
        self.ironNoReps = max(0, ironNoReps)
        self.ironTrackingGaps = max(0, ironTrackingGaps)
        self.humanCompletedReps = max(0, humanCompletedReps)
        self.humanShallowNoReps = max(0, humanShallowNoReps)
        self.agreedWithEveryNoRepCall = agreedWithEveryNoRepCall
        self.lineMadeUserPushHarder = lineMadeUserPushHarder
        self.lineScorePercent = lineScorePercent
    }

    var humanAttempts: Int {
        humanCompletedReps + humanShallowNoReps
    }

    var ironResolvedAttempts: Int {
        ironVerifiedReps + ironNoReps
    }

    /// Best count-based approximation of per-attempt referee agreement until
    /// Phase 1 captures labels for every individual attempt.
    ///
    /// Matching verified reps and matching no-reps are credited separately.
    /// This prevents compensating errors (for example, one false NO REP and one
    /// false verified rep) from cancelling each other out and appearing as 100%
    /// agreement merely because the final verified-rep totals match.
    var matchedAttemptClassifications: Int {
        min(ironVerifiedReps, humanCompletedReps) +
        min(ironNoReps, humanShallowNoReps)
    }

    var agreementDenominator: Int {
        max(humanAttempts, ironResolvedAttempts)
    }

    var repCountAgreement: Double {
        guard agreementDenominator > 0 else { return 1 }
        return Double(matchedAttemptClassifications) / Double(agreementDenominator)
    }

    /// Surplus NO REP calls relative to the human observer. These are not proof
    /// of a false no-rep without per-attempt labels, but they are the highest-risk
    /// cases to review when tuning ROM thresholds.
    var potentialFalseNoReps: Int {
        max(0, ironNoReps - humanShallowNoReps)
    }

    /// Human-observed shallow attempts that IronLine did not resolve as NO REP.
    var missedShallowNoReps: Int {
        max(0, humanShallowNoReps - ironNoReps)
    }
}

struct FirstPlayableTestSummary: Equatable {
    let setCount: Int
    let totalHumanAttempts: Int
    let totalIronResolvedAttempts: Int
    let totalTrackingGaps: Int
    let setsWithTrackingGaps: Int
    let potentialFalseNoReps: Int
    let missedShallowNoReps: Int
    let repCountAgreement: Double
    let noRepTrustRate: Double?
    let linePushRate: Double?

    var meetsRepAgreementGate: Bool {
        repCountAgreement >= 0.90
    }
}

struct FirstPlayableTestLedger: Codable, Equatable {
    private(set) var records: [FirstPlayableSetRecord] = []

    mutating func append(_ record: FirstPlayableSetRecord) {
        records.append(record)
    }

    mutating func replace(_ record: FirstPlayableSetRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            records.append(record)
            return
        }
        records[index] = record
    }

    var summary: FirstPlayableTestSummary {
        let humanAttempts = records.reduce(0) { $0 + $1.humanAttempts }
        let ironAttempts = records.reduce(0) { $0 + $1.ironResolvedAttempts }
        let trackingGaps = records.reduce(0) { $0 + $1.ironTrackingGaps }
        let setsWithTrackingGaps = records.filter { $0.ironTrackingGaps > 0 }.count
        let falseNoRepRisks = records.reduce(0) { $0 + $1.potentialFalseNoReps }
        let missedNoReps = records.reduce(0) { $0 + $1.missedShallowNoReps }

        // Compute agreement per set and then aggregate matched classifications.
        // Doing this per record prevents errors in one set from cancelling errors
        // in another set before the Phase 1 gate is evaluated.
        let matchedClassifications = records.reduce(0) { $0 + $1.matchedAttemptClassifications }
        let agreementDenominator = records.reduce(0) { $0 + $1.agreementDenominator }
        let agreement = agreementDenominator == 0
            ? 1
            : Double(matchedClassifications) / Double(agreementDenominator)

        let noRepAnswers = records.compactMap(\.agreedWithEveryNoRepCall)
        let noRepTrustRate = noRepAnswers.isEmpty
            ? nil
            : Double(noRepAnswers.filter { $0 }.count) / Double(noRepAnswers.count)

        let pushAnswers = records.compactMap(\.lineMadeUserPushHarder)
        let linePushRate = pushAnswers.isEmpty
            ? nil
            : Double(pushAnswers.filter { $0 }.count) / Double(pushAnswers.count)

        return FirstPlayableTestSummary(
            setCount: records.count,
            totalHumanAttempts: humanAttempts,
            totalIronResolvedAttempts: ironAttempts,
            totalTrackingGaps: trackingGaps,
            setsWithTrackingGaps: setsWithTrackingGaps,
            potentialFalseNoReps: falseNoRepRisks,
            missedShallowNoReps: missedNoReps,
            repCountAgreement: agreement,
            noRepTrustRate: noRepTrustRate,
            linePushRate: linePushRate
        )
    }
}

/// Small local persistence layer for the physical-iPhone test loop.
/// The first playable must remain usable without backend credentials, so test
/// observations are stored on-device and can later be shared/exported.
enum FirstPlayableTestStore {
    static let storageKey = "ironline.firstPlayable.testLedger.v1"

    static func load(defaults: UserDefaults = .standard) -> FirstPlayableTestLedger {
        guard
            let data = defaults.data(forKey: storageKey),
            let ledger = try? JSONDecoder().decode(FirstPlayableTestLedger.self, from: data)
        else {
            return FirstPlayableTestLedger()
        }
        return ledger
    }

    static func save(_ ledger: FirstPlayableTestLedger, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
