import Foundation
import Combine

/// Per-profile saved products.
/// Demo: profiles can be seeded once with unique defaults; `save` / `unsave` / `toggle`
/// update only the active profile’s list (never shared across profiles).
@MainActor
final class SavedStore: ObservableObject {
    static let shared = SavedStore()

    private let maxItemsPerProfile = 40

    @Published private(set) var itemsByProfileID: [String: [CommerceItem]] = [:]
    private var seededProfileIDs: Set<String> = []

    private init() {}

    /// Demo defaults: Frodo starts with no saves; Pippin with one; others get a fuller strip.
    /// Custom Saves-tab lists use `list-*` ids.
    static func demoSeedCount(for profileID: String) -> Int {
        switch profileID {
        case "frodo":
            return 0
        case "pippin":
            return 1
        case "sam":
            return 4
        case "gandalf":
            return 6
        case "list-gifts":
            return 3
        case "list-kitchen":
            return 5
        case "list-travel":
            return 2
        default:
            return 5
        }
    }

    func items(for profileID: String) -> [CommerceItem] {
        itemsByProfileID[profileID] ?? []
    }

    func contains(_ item: CommerceItem, for profileID: String) -> Bool {
        items(for: profileID).contains { $0.productId == item.productId }
    }

    /// Saves a product for a single profile and moves it to the front.
    func save(_ item: CommerceItem, for profileID: String) {
        var list = itemsByProfileID[profileID] ?? []
        list.removeAll { $0.productId == item.productId }
        list.insert(item, at: 0)
        if list.count > maxItemsPerProfile {
            list = Array(list.prefix(maxItemsPerProfile))
        }
        itemsByProfileID[profileID] = list
    }

    func unsave(_ item: CommerceItem, for profileID: String) {
        var list = itemsByProfileID[profileID] ?? []
        list.removeAll { $0.productId == item.productId }
        itemsByProfileID[profileID] = list
    }

    @discardableResult
    func toggle(_ item: CommerceItem, for profileID: String) -> Bool {
        if contains(item, for: profileID) {
            unsave(item, for: profileID)
            return false
        } else {
            save(item, for: profileID)
            return true
        }
    }

    /// Demo-only: prepopulate a profile once from feed candidates if it has no saves yet.
    /// Uses a different shuffle seed than recently viewed so lists diverge per profile.
    func seedDemoIfNeeded(profileID: String, from candidates: [CommerceItem]) {
        guard !seededProfileIDs.contains(profileID) else { return }
        guard items(for: profileID).isEmpty else {
            seededProfileIDs.insert(profileID)
            return
        }

        let count = Self.demoSeedCount(for: profileID)
        defer { seededProfileIDs.insert(profileID) }

        guard count > 0, !candidates.isEmpty else {
            itemsByProfileID[profileID] = []
            return
        }

        var pool = candidates
        // Distinct from RecentlyViewedStore’s seed so default strips don’t match.
        let seed = UInt64(bitPattern: Int64(profileID.hashValue)) &* 97 &+ 53
        var rng = SeededRandomNumberGenerator(seed: seed == 0 ? 1 : seed)
        pool.shuffle(using: &rng)

        // Offset into the shuffled pool so neighboring profiles get different slices.
        let offset = abs(profileID.hashValue) % max(pool.count, 1)
        let rotated = Array(pool[offset...]) + Array(pool[..<offset])
        itemsByProfileID[profileID] = Array(rotated.prefix(count))
    }
}
