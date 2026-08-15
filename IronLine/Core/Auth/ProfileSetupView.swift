import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appState: AppState

    @State private var displayName = ""
    @State private var heightInches = ""
    @State private var weightLbs = ""
    @State private var age = ""
    @State private var gender: Gender = .other
    @State private var trainingExperience: TrainingExperience = .beginner
    @State private var trainingGoal: TrainingGoal = .general
    @State private var preferredUnits: PreferredUnits = .lbs
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("About you") {
                TextField("Display name", text: $displayName)
                TextField("Height (inches)", text: $heightInches).keyboardType(.numberPad)
                TextField("Weight (lbs)", text: $weightLbs).keyboardType(.decimalPad)
                TextField("Age", text: $age).keyboardType(.numberPad)

                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Experience", selection: $trainingExperience) {
                    ForEach(TrainingExperience.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Goal", selection: $trainingGoal) {
                    ForEach(TrainingGoal.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Units", selection: $preferredUnits) {
                    ForEach(PreferredUnits.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(Theme.Color.danger)
            }

            Button(isSaving ? "Saving..." : "Continue") {
                Task { await save() }
            }
            .disabled(isSaving)
        }
    }

    private func save() async {
        guard let userId = authManager.session?.user.id else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let profile = UserProfile(
            id: userId,
            displayName: displayName.isEmpty ? nil : displayName,
            heightInches: Int(heightInches),
            weightLbs: Double(weightLbs),
            age: Int(age),
            gender: gender,
            trainingExperience: trainingExperience,
            trainingGoal: trainingGoal,
            preferredUnits: preferredUnits
        )

        do {
            try await SupabaseConfig.client
                .from("users")
                .upsert(profile)
                .execute()
            appState.currentUser = profile
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
