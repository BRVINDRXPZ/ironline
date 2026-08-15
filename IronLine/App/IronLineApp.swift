import SwiftUI

@main
struct IronLineApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(appState)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
            } else if authManager.session == nil {
                LoginView()
            } else if appState.currentUser == nil {
                ProfileSetupView()
                    .task { await loadProfile() }
            } else {
                HomeView()
            }
        }
    }

    private func loadProfile() async {
        guard let userId = authManager.session?.user.id else { return }
        appState.currentUser = try? await SupabaseConfig.client
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }
}
