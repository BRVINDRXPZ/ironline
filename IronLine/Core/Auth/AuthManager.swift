import Foundation
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true

    private let client = SupabaseConfig.client

    init() {
        Task { await observeAuthState() }
    }

    private func observeAuthState() async {
        for await (event, session) in client.auth.authStateChanges {
            if [.initialSession, .signedIn, .signedOut].contains(event) {
                self.session = session
                self.isLoading = false
            }
        }
    }

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // TODO: signInWithApple — wire up Sign in with Apple, then
    // client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken))
}
