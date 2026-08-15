import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: UserProfile?
}
