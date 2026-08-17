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

    /// Aggregate count agreement for the controlled first-playable test.
    ///
    /// The Phase 1 protocol asks whether verified-rep count agrees with the
    /// human observer on at least 90% of attempts. Until per-attempt labels are
    /// captured, this is intentionally conservative: every excess or missing
    /// verified rep is treated as one disagreement and the denominator is the
    /// larger observed attempt count.
    var repCountAgreement: Double {
        let denominator = max(humanAttempts, ironResolvedAttempts)
        guard denominator > 0 else { return 1 }

        let disagreements = abs(ironVerifiedReps - humanCompletedReps)
        return max(0, 1 - (Double(disagreements) / Double(denominator)))
    }
}

struct FirstPlayableTestSummary: Equatable {
    let setCount: Int
    let totalHumanAttempts: Int
    let totalIronResolvedAttempts: Int
    let totalTrackingGaps: Int
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
        let verifiedDelta = abs(
            records.reduce(0) { $0 + $1.ironVerifiedReps } -
            records.reduce(0) { $0 + $1.humanCompletedReps }
        )
        let agreementDenominator = max(humanAttempts, ironAttempts)
        let agreement = agreementDenominator == 0
            ? 1
            : max(0, 1 - (Double(verifiedDelta) / Double(agreementDenominator)))

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
