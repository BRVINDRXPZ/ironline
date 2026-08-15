import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Welcome, \(appState.currentUser?.displayName ?? "athlete")")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.Color.textPrimary)

            // TODO: dashboard — today's LINE status, active duels, recent PRs
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.background)
    }
}
