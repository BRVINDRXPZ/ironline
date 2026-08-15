import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, other
    var id: String { rawValue }
}

enum TrainingExperience: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
}

enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
    case strength, hypertrophy, general
    var id: String { rawValue }
}

enum PreferredUnits: String, Codable, CaseIterable, Identifiable {
    case lbs, kg
    var id: String { rawValue }
}

/// Mirrors the `users` table (supabase/migrations/001_users.sql).
struct UserProfile: Codable, Identifiable {
    let id: UUID
    var displayName: String?
    var avatarUrl: String?
    var heightInches: Int?
    var weightLbs: Double?
    var age: Int?
    var gender: Gender?
    var trainingExperience: TrainingExperience?
    var trainingGoal: TrainingGoal?
    var preferredUnits: PreferredUnits

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case heightInches = "height_inches"
        case weightLbs = "weight_lbs"
        case age
        case gender
        case trainingExperience = "training_experience"
        case trainingGoal = "training_goal"
        case preferredUnits = "preferred_units"
    }

    init(
        id: UUID,
        displayName: String? = nil,
        avatarUrl: String? = nil,
        heightInches: Int? = nil,
        weightLbs: Double? = nil,
        age: Int? = nil,
        gender: Gender? = nil,
        trainingExperience: TrainingExperience? = nil,
        trainingGoal: TrainingGoal? = nil,
        preferredUnits: PreferredUnits = .lbs
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.heightInches = heightInches
        self.weightLbs = weightLbs
        self.age = age
        self.gender = gender
        self.trainingExperience = trainingExperience
        self.trainingGoal = trainingGoal
        self.preferredUnits = preferredUnits
    }
}
