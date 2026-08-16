import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    lineCard
                    prototypeCard
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("IRON LINE")
                .font(.caption.weight(.black))
                .tracking(3)
                .foregroundStyle(Theme.Color.accent)

            Text("\(appState.currentUser?.displayName ?? "ATHLETE"), beat expectation.")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .padding(.top, 12)
    }

    private var lineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S LINE")
                    .font(.caption.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.Color.textSecondary)
                Spacer()
                Text("PROTOTYPE")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Theme.Color.gold)
            }

            Text("70 LB × 10")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .monospacedDigit()

            Text("Incline Dumbbell Press")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var prototypeCard: some View {
        NavigationLink {
            PrototypeWorkoutView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.Color.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text("START VERIFIED SET")
                        .font(.headline.weight(.black))
                    Text("Camera referee · reps · ROM · Line score")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .padding(Theme.Spacing.md)
            .foregroundStyle(Theme.Color.textPrimary)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }
}
