import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Create Account")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.Color.textPrimary)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.danger)
            }

            Button("Sign Up") {
                Task { await signUp() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Color.background)
    }

    private func signUp() async {
        errorMessage = nil
        do {
            try await authManager.signUp(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
