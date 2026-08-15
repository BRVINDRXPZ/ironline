import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var showSignUp = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("IRON LINE")
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Color.textPrimary)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.danger)
            }

            Button("Log In") {
                Task { await logIn() }
            }
            .buttonStyle(.borderedProminent)

            Button("Create Account") { showSignUp = true }
                .font(Theme.Font.caption)

            // TODO: Sign in with Apple button (ASAuthorizationAppleIDButton)
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Color.background)
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }

    private func logIn() async {
        errorMessage = nil
        do {
            try await authManager.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
