import Foundation
import Combine

/// Per-profile recently viewed products.
/// Demo: profiles can be seeded once from feed candidates; real taps always update
/// only the active profile’s list (never shared across profiles).
@MainActor
final class RecentlyViewedStore: ObservableObject {
    static let shared = RecentlyViewedStore()

    private let maxItemsPerProfile = 20
    private let demoSeedCount = 6

    @Published private(set) var itemsByProfileID: [String: [CommerceItem]] = [:]
    private var seededProfileIDs: Set<String> = []

    private init() {}

    func items(for profileID: String) -> [CommerceItem] {
        itemsByProfileID[profileID] ?? []
    }

    /// Records a product view for a single profile and moves it to the front.
    func record(_ item: CommerceItem, for profileID: String) {
        var list = itemsByProfileID[profileID] ?? []
        list.removeAll { $0.productId == item.productId }
        list.insert(item, at: 0)
        if list.count > maxItemsPerProfile {
            list = Array(list.prefix(maxItemsPerProfile))
        }
        itemsByProfileID[profileID] = list
    }

    /// Demo-only: prepopulate a profile once from feed candidates if it has no history yet.
    func seedDemoIfNeeded(profileID: String, from candidates: [CommerceItem]) {
        guard !seededProfileIDs.contains(profileID) else { return }
        guard items(for: profileID).isEmpty else {
            seededProfileIDs.insert(profileID)
            return
        }
        guard !candidates.isEmpty else { return }

        var pool = candidates
        let seed = UInt64(bitPattern: Int64(profileID.hashValue)) &* 31 &+ 17
        var rng = SeededRandomNumberGenerator(seed: seed == 0 ? 1 : seed)
        pool.shuffle(using: &rng)

        let seeded = Array(pool.prefix(demoSeedCount))
        guard !seeded.isEmpty else { return }
        itemsByProfileID[profileID] = seeded
        seededProfileIDs.insert(profileID)
    }
}
