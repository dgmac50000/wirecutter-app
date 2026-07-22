import Foundation

struct CommerceSource: Codable {
    let merchantName: String
    let affiliateUrl: URL?
    let priceFormatted: String?
    let priceRaw: Int?
    let dealAffiliateUrl: URL?
    let promoCode: String?
    let promoEffect: String?
    let dealPriceFormatted: String?
    let streetPriceFormatted: String?
}

struct CommerceItem: Codable, Identifiable {
    let articleId: Int
    let articleTitle: String
    let articleUrl: URL
    let productId: Int
    let productTitle: String
    let productDescription: String?
    let images: [URL]?
    let hasDealData: Bool?
    let sources: [CommerceSource]?

    // Legacy fields (still supported for backwards compatibility)
    let imageUrl: URL?
    let merchantName: String?
    let affiliateUrl: URL?
    let priceFormatted: String?
    let pickTypeId: Int?
    let ribbon: String?

    /// Wirecutter primary section (e.g. Electronics, Home), used for feed grouping.
    let categoryName: String?
    let categorySlug: String?
    /// Article-level editorial hero (often hi-res CDN) — used to lead category sections.
    let articleHeroImageURL: URL?

    var id: Int { productId }

    /// Prefer editorial hi-res CDN assets when present; otherwise fall back to catalog / legacy URL.
    var displayImageUrl: URL? {
        ProductImageRanking.preferredDisplayURL(images: images, fallback: imageUrl)
    }

    /// Best price: first source's deal price, or regular price, or legacy field
    var displayPrice: String? {
        if let source = sources?.first {
            return source.dealPriceFormatted ?? source.priceFormatted
        }
        return priceFormatted
    }

    /// Best merchant name from sources or legacy field
    var displayMerchant: String? {
        sources?.first?.merchantName ?? merchantName
    }

    /// Best affiliate URL: deal link > source link > legacy field
    var shopUrl: URL? {
        if let source = sources?.first {
            return source.dealAffiliateUrl ?? source.affiliateUrl
        }
        return affiliateUrl
    }

    var resolvedCategoryName: String {
        let trimmed = categoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Other" : trimmed
    }

    var resolvedCategorySlug: String {
        let trimmed = categorySlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return resolvedCategoryName.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

struct CommerceFeedResponse: Codable {
    let items: [CommerceItem]
}

/// Grouped feed section for the commerce list UI (categories or Assistant personas).
struct CommerceCategorySection: Identifiable {
    let id: String
    let name: String
    let heroImageURL: URL?
    let items: [CommerceItem]

    static func build(from items: [CommerceItem]) -> [CommerceCategorySection] {
        let grouped = Dictionary(grouping: items) { $0.resolvedCategorySlug }
        let preferredOrder = WirecutterCategory.preferredOrder

        return grouped.keys.sorted { a, b in
            let ai = preferredOrder.firstIndex(of: a) ?? Int.max
            let bi = preferredOrder.firstIndex(of: b) ?? Int.max
            if ai != bi { return ai < bi }
            let an = grouped[a]?.first?.resolvedCategoryName ?? a
            let bn = grouped[b]?.first?.resolvedCategoryName ?? b
            return an.localizedCaseInsensitiveCompare(bn) == .orderedAscending
        }
        .compactMap { slug -> CommerceCategorySection? in
            guard var sectionItems = grouped[slug], !sectionItems.isEmpty else { return nil }
            // Within a section, surface products that already have confident hi-res first.
            sectionItems.sort { lhs, rhs in
                let lHi = lhs.displayImageUrl.map { ProductImageRanking.tier(of: $0) == .hires } ?? false
                let rHi = rhs.displayImageUrl.map { ProductImageRanking.tier(of: $0) == .hires } ?? false
                if lHi != rHi { return lHi && !rHi }
                return false
            }
            let name = sectionItems.first?.resolvedCategoryName ?? slug
            return CommerceCategorySection(
                id: slug,
                name: name,
                heroImageURL: Self.leadImage(for: sectionItems),
                items: sectionItems
            )
        }
    }

    /// Assistant mode: persona-labeled sections (Dad, Alex, …), each with a
    /// category-mixed shuffle of the full product pool.
    static func buildAssistantPersonas(from items: [CommerceItem]) -> [CommerceCategorySection] {
        guard !items.isEmpty else { return [] }

        return AssistantPersona.all.map { persona in
            let mixed = persona.mixedProducts(from: items)
            return CommerceCategorySection(
                id: persona.id,
                name: persona.name,
                heroImageURL: leadImage(for: mixed),
                items: mixed
            )
        }
    }

    /// Prefer article hero (CDN), else first confident product hi-res in the section.
    private static func leadImage(for items: [CommerceItem]) -> URL? {
        if let hero = items.compactMap(\.articleHeroImageURL).first(where: {
            ProductImageRanking.tier(of: $0) == .hires
        }) {
            return hero
        }
        return items.compactMap(\.displayImageUrl).first(where: {
            ProductImageRanking.tier(of: $0) == .hires
        })
    }
}

/// Prototype gift-assistant people. Each section shows a mixed (non-category) product list.
struct AssistantPersona: Identifiable {
    let id: String
    let name: String
    /// Stable shuffle salt so Dad / Alex get different orderings of the same pool.
    let shuffleSeed: UInt64

    static let all: [AssistantPersona] = [
        AssistantPersona(id: "dad", name: "Dad", shuffleSeed: 11),
        AssistantPersona(id: "alex", name: "Alex", shuffleSeed: 29),
    ]

    /// Full product pool, interleaved across categories then persona-shuffled —
    /// so the list feels like mixed picks, not an Electronics block then Home block.
    func mixedProducts(from items: [CommerceItem]) -> [CommerceItem] {
        let byCategory = Dictionary(grouping: items) { $0.resolvedCategorySlug }
        let categoryKeys = byCategory.keys.sorted()

        // Round-robin across categories for an even mix.
        var interleaved: [CommerceItem] = []
        var indices = Dictionary(uniqueKeysWithValues: categoryKeys.map { ($0, 0) })
        var added = 0
        while added < items.count {
            var progressed = false
            for key in categoryKeys {
                let bucket = byCategory[key] ?? []
                let i = indices[key] ?? 0
                if i < bucket.count {
                    interleaved.append(bucket[i])
                    indices[key] = i + 1
                    added += 1
                    progressed = true
                }
            }
            if !progressed { break }
        }

        return Self.shuffle(interleaved, seed: shuffleSeed)
    }

    private static func shuffle(_ items: [CommerceItem], seed: UInt64) -> [CommerceItem] {
        var result = items
        var state = seed == 0 ? 1 : seed
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            state = state &* 6364136223846793005 &+ 1
            let j = Int(state % UInt64(i + 1))
            result.swapAt(i, j)
        }
        return result
    }
}

enum FeedMode: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case assistant = "Assistant"

    var id: String { rawValue }
}

/// Canonical Wirecutter / app category slugs for stable section ordering.
enum WirecutterCategory {
    static let preferredOrder = [
        "electronics",
        "home",
        "home-garden",
        "kitchen",
        "appliances",
        "sleep",
        "health-fitness",
        "outdoors",
        "style",
        "travel",
        "gifts",
        "other",
    ]

    /// Normalize Wirecutter `primarySection` into a display name + slug.
    static func normalize(sectionName: String?, sectionLink: String?) -> (name: String, slug: String) {
        let rawName = sectionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let link = sectionLink?.lowercased() ?? ""

        if link.contains("/electronics") || rawName.caseInsensitiveCompare("Electronics") == .orderedSame {
            return ("Electronics", "electronics")
        }
        if link.contains("/home-garden") || link.contains("/home/")
            || rawName.localizedCaseInsensitiveContains("home") {
            return ("Home", "home")
        }
        if link.contains("/kitchen") || rawName.localizedCaseInsensitiveContains("kitchen") {
            return ("Kitchen", "kitchen")
        }
        if link.contains("/sleep") || rawName.localizedCaseInsensitiveContains("sleep") {
            return ("Sleep", "sleep")
        }
        if link.contains("/health-fitness") || rawName.localizedCaseInsensitiveContains("health") {
            return ("Health & Fitness", "health-fitness")
        }
        if link.contains("/outdoors") || rawName.localizedCaseInsensitiveContains("outdoor") {
            return ("Outdoors", "outdoors")
        }
        if link.contains("/style") || rawName.localizedCaseInsensitiveContains("style") {
            return ("Style", "style")
        }
        if link.contains("/travel") || rawName.localizedCaseInsensitiveContains("travel") {
            return ("Travel", "travel")
        }
        if link.contains("/gifts") || rawName.localizedCaseInsensitiveContains("gift") {
            return ("Gifts", "gifts")
        }
        if link.contains("/appliances") || rawName.localizedCaseInsensitiveContains("appliance") {
            return ("Appliances", "appliances")
        }

        if rawName.isEmpty {
            return ("Other", "other")
        }
        let slug = rawName.lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: " ", with: "-")
        return (rawName, slug)
    }
}
