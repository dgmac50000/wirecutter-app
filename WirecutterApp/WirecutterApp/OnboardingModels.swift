import Foundation

/// User preferences collected during onboarding.
struct UserPreferences: Codable {
    var selectedCategories: [String]
    var budgetRange: BudgetRange
    var shoppingContext: [String]
    var completedOnboarding: Bool

    static let empty = UserPreferences(
        selectedCategories: [],
        budgetRange: .moderate,
        shoppingContext: [],
        completedOnboarding: false
    )
}

enum BudgetRange: String, Codable, CaseIterable, Identifiable {
    case budget = "Budget-friendly"
    case moderate = "Mid-range"
    case premium = "Premium"
    case noPreference = "No preference"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .budget: return "I want the best value picks"
        case .moderate: return "Balance of quality and price"
        case .premium: return "I want the best, period"
        case .noPreference: return "Show me everything"
        }
    }
}

/// Categories available for onboarding selection.
struct OnboardingCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: String

    static let all: [OnboardingCategory] = [
        OnboardingCategory(id: "electronics", name: "Electronics", icon: "laptopcomputer", color: "4A90D9"),
        OnboardingCategory(id: "home", name: "Home", icon: "house.fill", color: "7ED321"),
        OnboardingCategory(id: "kitchen", name: "Kitchen", icon: "fork.knife", color: "F5A623"),
        OnboardingCategory(id: "sleep", name: "Sleep", icon: "bed.double.fill", color: "9B59B6"),
        OnboardingCategory(id: "health-fitness", name: "Health & Fitness", icon: "heart.fill", color: "E74C3C"),
        OnboardingCategory(id: "outdoors", name: "Outdoors", icon: "leaf.fill", color: "27AE60"),
        OnboardingCategory(id: "style", name: "Style", icon: "tshirt.fill", color: "E91E63"),
        OnboardingCategory(id: "travel", name: "Travel", icon: "airplane", color: "00BCD4"),
        OnboardingCategory(id: "gifts", name: "Gifts", icon: "gift.fill", color: "FF6B6B"),
        OnboardingCategory(id: "appliances", name: "Appliances", icon: "washer.fill", color: "607D8B"),
        OnboardingCategory(id: "baby-kids", name: "Baby & Kids", icon: "figure.and.child.holdinghands", color: "FF9800"),
    ]
}

/// Shopping context options (multi-select).
struct ShoppingContext: Identifiable {
    let id: String
    let label: String
    let icon: String

    static let all: [ShoppingContext] = [
        ShoppingContext(id: "moving", label: "Moving to a new place", icon: "box.truck.fill"),
        ShoppingContext(id: "upgrading", label: "Upgrading my setup", icon: "arrow.up.circle.fill"),
        ShoppingContext(id: "gifting", label: "Shopping for gifts", icon: "gift.fill"),
        ShoppingContext(id: "baby", label: "Expecting a baby", icon: "figure.and.child.holdinghands"),
        ShoppingContext(id: "first-home", label: "First home/apartment", icon: "key.fill"),
        ShoppingContext(id: "wedding", label: "Wedding registry", icon: "heart.circle.fill"),
        ShoppingContext(id: "just-browsing", label: "Just browsing", icon: "eyes"),
    ]
}

/// Persistence for user preferences via UserDefaults.
final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    private let key = "user_preferences_v1"

    @Published var preferences: UserPreferences {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .empty
        }
    }

    var hasCompletedOnboarding: Bool {
        preferences.completedOnboarding
    }

    func completeOnboarding(categories: [String], budget: BudgetRange, context: [String]) {
        preferences = UserPreferences(
            selectedCategories: categories,
            budgetRange: budget,
            shoppingContext: context,
            completedOnboarding: true
        )
    }

    func reset() {
        preferences = .empty
    }

    private func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
