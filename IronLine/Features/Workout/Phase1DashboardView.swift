import SwiftUI

/// Read-only dashboard for the physical-iPhone validation loop.
///
/// It surfaces the exact trust signals in `docs/phase1-test-plan.md` without
/// expanding the product beyond the incline dumbbell press first playable.
struct Phase1DashboardView: View {
    @State private var ledger = FirstPlayableTestLedger()

    private var summary: FirstPlayableTestSummary { ledger.summary }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                gateCard
                diagnosticsCard
                trustCard
                historyCard
                ShareLink(item: shareText) {
                    Label("SHARE PHASE 1 REPORT", systemImage: "square.and.arrow.up")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, 32)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle("Phase 1 Test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ledger = FirstPlayableTestStore.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CAMERA TRUST")
                .font(.caption.weight(.black))
                .tracking(2.2)
                .foregroundStyle(Theme.Color.accent)
            Text("Is the referee believable yet?")
                .font(.system(size: 30, weight: .black, design: .rounded))
            Text("Incline dumbbell press only. Real sets decide whether the thresholds are trustworthy enough to move forward.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private var gateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(percent(summary.repCountAgreement))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text(summary.meetsRepAgreementGate ? "PASS" : "NOT YET")
                    .font(.caption.monospaced().weight(.black))
                    .foregroundStyle(summary.meetsRepAgreementGate ? Theme.Color.success : Theme.Color.intensity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        (summary.meetsRepAgreementGate ? Theme.Color.success : Theme.Color.intensity).opacity(0.12),
                        in: Capsule()
                    )
            }

            Text("REP AGREEMENT · 90% GATE")
                .font(.caption.weight(.black))
                .tracking(1.6)
                .foregroundStyle(Theme.Color.textSecondary)

            HStack(spacing: 10) {
                metric("SETS", value: "\(summary.setCount)")
                metric("HUMAN ATTEMPTS", value: "\(summary.totalHumanAttempts)")
                metric("IRON RESOLVED", value: "\(summary.totalIronResolvedAttempts)")
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("REFEREE DIAGNOSTICS")
                .font(.caption.weight(.black))
                .tracking(1.8)
                .foregroundStyle(Theme.Color.textSecondary)

            diagnosticRow(
                title: "Potential false NO REPs",
                value: summary.potentialFalseNoReps,
                note: "IronLine called more shallow reps than the human observer. Review ROM depth / smoothing first."
            )
            diagnosticRow(
                title: "Missed shallow NO REPs",
                value: summary.missedShallowNoReps,
                note: "The human observer saw shallow attempts that IronLine did not reject. Review bottom threshold / attempt depth."
            )
            diagnosticRow(
                title: "Tracking gaps",
                value: summary.totalTrackingGaps,
                note: "Across \(summary.setsWithTrackingGaps) logged set\(summary.setsWithTrackingGaps == 1 ? "" : "s"). Any gap invalidates the in-flight rep."
            )
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var trustCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GAME FEEL")
                .font(.caption.weight(.black))
                .tracking(1.8)
                .foregroundStyle(Theme.Color.textSecondary)

            valueRow("NO-REP TRUST", value: summary.noRepTrustRate.map(percent) ?? "NO DATA")
            valueRow("THE LINE PUSH RATE", value: summary.linePushRate.map(percent) ?? "NO DATA")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT SETS")
                .font(.caption.weight(.black))
                .tracking(1.8)
                .foregroundStyle(Theme.Color.textSecondary)

            if ledger.records.isEmpty {
                Text("No human-checked sets logged yet.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
            } else {
                ForEach(ledger.records.suffix(8).reversed()) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(format(record.weight)) LB")
                                .font(.subheadline.monospacedDigit().weight(.black))
                            Text("IRON \(record.ironVerifiedReps)V / \(record.ironNoReps)NR · HUMAN \(record.humanCompletedReps)V / \(record.humanShallowNoReps)NR")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        Spacer()
                        Text(percent(record.repCountAgreement))
                            .font(.caption.monospacedDigit().weight(.black))
                            .foregroundStyle(record.repCountAgreement >= 0.90 ? Theme.Color.success : Theme.Color.intensity)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.Color.textSecondary)
            Text(value)
                .font(.headline.monospacedDigit().weight(.black))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diagnosticRow(title: String, value: Int, note: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(value)")
                    .font(.headline.monospacedDigit().weight(.black))
                    .foregroundStyle(value == 0 ? Theme.Color.success : Theme.Color.intensity)
            }
            Text(note)
                .font(.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private func valueRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit().weight(.black))
        }
    }

    private var shareText: String {
        """
        IronLine Phase 1 Referee Report
        Exercise: Incline Dumbbell Press
        Sets logged: \(summary.setCount)
        Rep agreement: \(percent(summary.repCountAgreement))
        90% gate: \(summary.meetsRepAgreementGate ? "PASS" : "NOT YET")
        Human attempts: \(summary.totalHumanAttempts)
        IronLine resolved attempts: \(summary.totalIronResolvedAttempts)
        Potential false NO REPs: \(summary.potentialFalseNoReps)
        Missed shallow NO REPs: \(summary.missedShallowNoReps)
        Tracking gaps: \(summary.totalTrackingGaps) across \(summary.setsWithTrackingGaps) sets
        No-rep trust: \(summary.noRepTrustRate.map(percent) ?? "NO DATA")
        THE LINE push rate: \(summary.linePushRate.map(percent) ?? "NO DATA")
        """
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
