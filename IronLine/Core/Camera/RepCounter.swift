import Foundation

/// Camera-agnostic state machine for a press-style rep.
///
/// V1 contract:
/// - top/lockout: elbow angle >= `topAngle`
/// - full ROM: elbow angle <= `bottomAngle`
/// - a rep only counts after top -> bottom -> top
/// - a shallow attempt that returns to top is surfaced as a no-rep
struct RepCounter {
    enum Event: Equatable {
        case counted(rep: Int)
        case noRep(reason: String)
    }

    private(set) var repsCompleted = 0
    private(set) var repsAttempted = 0
    private(set) var minimumAngleThisAttempt: Double?

    let topAngle: Double
    let bottomAngle: Double
    let attemptDepth: Double
    let minimumConfidence: Double

    private var armedAtTop = false
    private var attemptInProgress = false

    init(
        topAngle: Double = 155,
        bottomAngle: Double = 100,
        attemptDepth: Double = 20,
        minimumConfidence: Double = 0.35
    ) {
        precondition(bottomAngle < topAngle)
        self.topAngle = topAngle
        self.bottomAngle = bottomAngle
        self.attemptDepth = attemptDepth
        self.minimumConfidence = minimumConfidence
    }

    /// Feed one smoothed elbow-angle sample into the state machine.
    /// Returns an event only when an attempt resolves at lockout.
    mutating func update(angle: Double, confidence: Double) -> Event? {
        guard angle.isFinite, confidence >= minimumConfidence else { return nil }

        // Before the first rep, require a clean lockout so we don't count a user
        // who enters frame halfway through a repetition.
        if !armedAtTop {
            if angle >= topAngle {
                armedAtTop = true
                minimumAngleThisAttempt = angle
            }
            return nil
        }

        if !attemptInProgress {
            minimumAngleThisAttempt = min(minimumAngleThisAttempt ?? angle, angle)

            if angle <= topAngle - attemptDepth {
                attemptInProgress = true
                minimumAngleThisAttempt = angle
            }
            return nil
        }

        minimumAngleThisAttempt = min(minimumAngleThisAttempt ?? angle, angle)

        guard angle >= topAngle else { return nil }

        repsAttempted += 1
        let minimum = minimumAngleThisAttempt ?? angle
        attemptInProgress = false
        minimumAngleThisAttempt = angle

        if minimum <= bottomAngle {
            repsCompleted += 1
            return .counted(rep: repsCompleted)
        }

        return .noRep(reason: "INSUFFICIENT ROM")
    }

    /// 0 = lockout/top, 1 = target bottom depth.
    func romProgress(for angle: Double) -> Double {
        let span = topAngle - bottomAngle
        guard span > 0 else { return 0 }
        return min(1, max(0, (topAngle - angle) / span))
    }

    mutating func reset() {
        repsCompleted = 0
        repsAttempted = 0
        minimumAngleThisAttempt = nil
        armedAtTop = false
        attemptInProgress = false
    }
}
