import Foundation
import SwiftUI

/// First playable vertical slice:
/// manual weight + camera-verified reps + personalized target + beat/miss result.
///
/// This deliberately proves the core game feel before Duels, Crews, Ghosts,
/// physique scanning, or automatic weight recognition are allowed into scope.
struct PrototypeWorkoutView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var camera = CameraManager()

    @State private var weight = 70.0
    @State private var line = PerformanceLine(weight: 70, reps: 10)
    @State private var result: LineResult?
    @State private var countdown: Int?

    @State private var workoutSessionID: UUID?
    @State private var exerciseID: UUID?
    @State private var setNumber = 1
    @State private var setStartedAt: Date?
    @State private var backendStatus = "CONNECTING"

    var body: some View {
        ZStack {
            Theme.Color.background.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .opacity(0.58)

            LinearGradient(
                colors: [.clear, Theme.Color.background.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                trackingHUD
                Spacer()
                controls
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
        .navigationBarBackButtonHidden(false)
        .task {
            camera.prepareAndStart()
            await prepareBackend()
        }
        .onDisappear {
            camera.stop()
            Task { await finishBackendSession() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("THE LINE")
                .font(.caption.weight(.black))
                .tracking(3)
                .foregroundStyle(Theme.Color.textSecondary)

            Text("\(format(line.weight)) × \(line.reps)")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text("INCLINE DUMBBELL PRESS")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Theme.Color.accent)

            Text(backendStatus)
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var trackingHUD: some View {
        VStack(spacing: 14) {
            Text("\(camera.repsCompleted)")
                .font(.system(size: 112, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            ProgressView(value: camera.romProgress)
                .tint(camera.romProgress >= 0.98 ? Theme.Color.success : Theme.Color.accent)
                .frame(maxWidth: 260)

            Text(feedbackText)
                .font(.headline.weight(.black))
                .foregroundStyle(feedbackColor)
                .multilineTextAlignment(.center)
                .frame(minHeight: 24)

            HStack(spacing: 14) {
                if let angle = camera.elbowAngle {
                    telemetryLabel("ELBOW", value: "\(Int(angle.rounded()))°")
                }
                telemetryLabel("NO REPS", value: "\(camera.noRepCount)")
                telemetryLabel("TRACK GAPS", value: "\(camera.trackingLossCount)")
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if let result {
                resultCard(result)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WEIGHT")
                        .font(.caption2.weight(.black))
                        .tracking(1.5)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("\(format(weight)) LB")
                        .font(.title2.monospacedDigit().weight(.black))
                }

                Spacer()

                Stepper("", value: $weight, in: 5...250, step: 5)
                    .labelsHidden()
                    .disabled(camera.isSetActive || countdown != nil)
            }
            .padding(14)
            .background(Theme.Color.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: Theme.Radius.card))

            Button(action: toggleSet) {
                Text(primaryButtonTitle)
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(camera.isSetActive ? Theme.Color.intensity : Theme.Color.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .disabled(countdown != nil || (!camera.isSetActive && !cameraReadyToStart))
        }
    }

    private func resultCard(_ result: LineResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.beatLine ? "LINE BEATEN" : "LINE MISSED")
                        .font(.headline.weight(.black))
                    Text(String(format: "%+.1f%% VS EXPECTATION", result.scorePercent))
                        .font(.caption.monospacedDigit().weight(.bold))
                }
                Spacer()
                Image(systemName: result.beatLine ? "arrow.up.right" : "arrow.down.right")
                    .font(.title.weight(.black))
            }

            HStack(spacing: 12) {
                resultMetric("VERIFIED", value: "\(camera.repsCompleted)")
                resultMetric("NO REPS", value: "\(camera.noRepCount)")
                resultMetric("TRACK GAPS", value: "\(camera.trackingLossCount)")
            }

            ShareLink(item: setReportText(result)) {
                Label("SHARE TEST SNAPSHOT", systemImage: "square.and.arrow.up")
                    .font(.caption.weight(.black))
            }
            .foregroundStyle(Theme.Color.textPrimary)
        }
        .foregroundStyle(result.beatLine ? Theme.Color.success : Theme.Color.intensity)
        .padding(14)
        .background(Theme.Color.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func telemetryLabel(_ title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(Theme.Color.textSecondary)
            Text(value)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .font(.caption2.monospacedDigit().weight(.bold))
    }

    private func resultMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.Color.textSecondary)
            Text(value)
                .font(.headline.monospacedDigit().weight(.black))
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setReportText(_ result: LineResult) -> String {
        let outcome = result.beatLine ? "LINE BEATEN" : "LINE MISSED"
        return """
        IronLine First Playable Test
        Exercise: Incline Dumbbell Press
        Weight: \(format(weight)) lb
        Verified reps: \(camera.repsCompleted)
        No reps: \(camera.noRepCount)
        Attempts resolved: \(camera.repsAttempted)
        Tracking gaps: \(camera.trackingLossCount)
        THE LINE: \(format(line.weight)) × \(line.reps)
        Result: \(outcome) (\(String(format: "%+.1f%%", result.scorePercent)))
        """
    }

    private var feedbackText: String {
        switch camera.trackingState {
        case .trackingLost:
            return camera.isSetActive ? "TRACKING LOST — RESET AT TOP" : "STEP INTO FRAME"
        case .requestingPermission:
            return "REQUESTING CAMERA"
        case .denied:
            return "CAMERA ACCESS REQUIRED"
        case .failed(let message):
            return message.uppercased()
        default:
            break
        }

        if let last = camera.lastFeedback { return last }

        switch camera.trackingState {
        case .tracking:
            return camera.isSetActive ? "VERIFYING" : "READY — HOLD POSITION"
        case .ready:
            return "STEP INTO FRAME"
        default:
            return "POSITION PHONE SIDE-ON"
        }
    }

    private var feedbackColor: Color {
        switch camera.trackingState {
        case .trackingLost, .denied, .failed:
            return Theme.Color.intensity
        default:
            break
        }

        guard let feedback = camera.lastFeedback else { return Theme.Color.textSecondary }
        return feedback.hasPrefix("NO REP") ? Theme.Color.intensity : Theme.Color.success
    }

    private var primaryButtonTitle: String {
        if let countdown { return "STARTING IN \(countdown)" }
        if camera.isSetActive { return "END SET" }
        return cameraReadyToStart ? "START VERIFIED SET" : "GET IN FRAME TO START"
    }

    private var cameraReadyToStart: Bool {
        if case .tracking = camera.trackingState {
            return true
        }
        return false
    }

    private func toggleSet() {
        if camera.isSetActive {
            camera.endSet()
            let endedAt = Date()
            let startedAt = setStartedAt ?? endedAt
            let completed = camera.repsCompleted
            let attempted = camera.repsAttempted
            let completedWeight = weight

            result = LineScoring.score(
                actualWeight: completedWeight,
                actualReps: completed,
                against: line
            )

            Task {
                await persistSet(
                    weight: completedWeight,
                    repsCompleted: completed,
                    repsAttempted: attempted,
                    startedAt: startedAt,
                    endedAt: endedAt
                )
            }
            return
        }

        result = nil
        Task { @MainActor in
            for value in stride(from: 3, through: 1, by: -1) {
                guard cameraReadyToStart else {
                    countdown = nil
                    return
                }

                countdown = value
                try? await Task.sleep(for: .seconds(1))
            }

            guard cameraReadyToStart else {
                countdown = nil
                return
            }

            countdown = nil
            setStartedAt = Date()
            camera.beginSet()
        }
    }

    @MainActor
    private func prepareBackend() async {
        guard let userID = authManager.session?.user.id else {
            backendStatus = "LOCAL MODE · NO SESSION"
            return
        }

        do {
            let resolvedExerciseID = try await WorkoutService.exerciseID(named: "Incline Dumbbell Press")
            let resolvedSessionID = try await WorkoutService.startSession(userID: userID)

            exerciseID = resolvedExerciseID
            workoutSessionID = resolvedSessionID

            let envelope = try await WorkoutService.getLine(exerciseID: resolvedExerciseID)
            if let activeLine = envelope.line {
                line = activeLine.performanceLine
                backendStatus = "LINE V\(activeLine.version) · \(Int((activeLine.confidence * 100).rounded()))% CONF"
            } else if envelope.baseline == true {
                backendStatus = "BUILDING LINE · \(envelope.sessionsRemaining ?? 0) SESSIONS"
            } else {
                backendStatus = "PROTOTYPE LINE"
            }
        } catch {
            backendStatus = "LOCAL MODE · \(error.localizedDescription.uppercased())"
        }
    }

    @MainActor
    private func persistSet(
        weight: Double,
        repsCompleted: Int,
        repsAttempted: Int,
        startedAt: Date,
        endedAt: Date
    ) async {
        guard let workoutSessionID, let exerciseID else {
            backendStatus = "LOCAL RESULT · NOT SYNCED"
            return
        }

        backendStatus = "SYNCING VERIFIED SET"

        do {
            let saved = try await WorkoutService.saveVerifiedSet(
                sessionID: workoutSessionID,
                exerciseID: exerciseID,
                setNumber: setNumber,
                weight: weight,
                repsCompleted: repsCompleted,
                repsAttempted: repsAttempted,
                startedAt: startedAt,
                endedAt: endedAt
            )
            backendStatus = saved.isPR ? "VERIFIED PR · SYNCED" : "VERIFIED · SYNCED"
            setNumber += 1
        } catch {
            backendStatus = "SAVE FAILED · LOCAL RESULT KEPT"
        }
    }

    @MainActor
    private func finishBackendSession() async {
        guard let workoutSessionID else { return }

        do {
            try await WorkoutService.completeSession(id: workoutSessionID)
            if let exerciseID {
                _ = try await WorkoutService.recalculateLine(exerciseID: exerciseID)
            }
        } catch {
            // Leaving the screen must never block on a network cleanup failure.
        }
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
