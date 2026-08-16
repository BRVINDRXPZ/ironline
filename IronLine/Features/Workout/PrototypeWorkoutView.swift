import Foundation
import SwiftUI

/// First playable vertical slice:
/// manual weight + camera-verified reps + personalized target + beat/miss result.
///
/// This deliberately proves the core game feel before Duels, Crews, Ghosts,
/// physique scanning, or automatic weight recognition are allowed into scope.
struct PrototypeWorkoutView: View {
    @StateObject private var camera = CameraManager()

    @State private var weight = 70.0
    @State private var line = PerformanceLine(weight: 70, reps: 10)
    @State private var result: LineResult?
    @State private var countdown: Int?

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
        .task { camera.prepareAndStart() }
        .onDisappear { camera.stop() }
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
                .frame(height: 24)

            if let angle = camera.elbowAngle {
                Text("ELBOW  \(Int(angle.rounded()))°")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
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
        .foregroundStyle(result.beatLine ? Theme.Color.success : Theme.Color.intensity)
        .padding(14)
        .background(Theme.Color.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var feedbackText: String {
        if let last = camera.lastFeedback { return last }
        switch camera.trackingState {
        case .tracking: return camera.isSetActive ? "VERIFYING" : "READY"
        case .trackingLost: return "STEP INTO FRAME"
        case .requestingPermission: return "REQUESTING CAMERA"
        case .denied: return "CAMERA ACCESS REQUIRED"
        case .failed(let message): return message.uppercased()
        default: return "POSITION PHONE SIDE-ON"
        }
    }

    private var feedbackColor: Color {
        guard let feedback = camera.lastFeedback else { return Theme.Color.textSecondary }
        return feedback.hasPrefix("NO REP") ? Theme.Color.intensity : Theme.Color.success
    }

    private var primaryButtonTitle: String {
        if let countdown { return "STARTING IN \(countdown)" }
        return camera.isSetActive ? "END SET" : "START VERIFIED SET"
    }

    private var cameraReadyToStart: Bool {
        switch camera.trackingState {
        case .ready, .tracking:
            return true
        default:
            return false
        }
    }

    private func toggleSet() {
        if camera.isSetActive {
            camera.endSet()
            result = LineScoring.score(
                actualWeight: weight,
                actualReps: camera.repsCompleted,
                against: line
            )
            return
        }

        result = nil
        Task { @MainActor in
            for value in stride(from: 3, through: 1, by: -1) {
                countdown = value
                try? await Task.sleep(for: .seconds(1))
            }
            countdown = nil
            camera.beginSet()
        }
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
