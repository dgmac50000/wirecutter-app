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

    /// `true` for products sourced from the Wirecutter Shopify Store (direct-buy).
    let isShopifyProduct: Bool?
    /// Shopify variant ID used for checkout (e.g. "gid://shopify/ProductVariant/...").
    let shopifyVariantId: String?

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

    /// Best affiliate URL: deal link > source link > legacy field.
    /// For Shopify products, links directly to the storefront product page.
    var shopUrl: URL? {
        if isShopifyProduct == true {
            return affiliateUrl
        }
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

/// Result of the commerce feed loader: affiliate products grouped by category,
/// plus a separate pool of Shopify Store products to display as interstitials.
struct CommerceFeedResult {
    let products: [CommerceItem]
    let shopifyProducts: [CommerceItem]
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

// MARK: - Series (editorial carousel)

struct SeriesData: Identifiable {
    let id: String
    let title: String
    let heroImageURL: URL?
    /// Bundled asset name for the hero image (takes priority over heroImageURL).
    let heroImageAsset: String?
    let articleURL: URL
    let products: [CommerceItem]
    /// Maps product IDs to bundled asset names for local image display.
    let localImageOverrides: [Int: String]
    /// Maps product IDs to hex background colors for the image area.
    let productBackgrounds: [Int: UInt]

    static let headphones = SeriesData(
        id: "series-headphones",
        title: "How to choose the best headphones for you",
        heroImageURL: URL(string: "https://cdn.thewirecutter.com/wp-content/media/2025/04/headphones-2048px-8797.jpg"),
        heroImageAsset: "SeriesImages/SonyXM5",
        articleURL: URL(string: "https://www.nytimes.com/wirecutter/reviews/best-headphones/")!,
        products: [
            CommerceItem(
                articleId: 90001,
                articleTitle: "Best Headphones",
                articleUrl: URL(string: "https://www.nytimes.com/wirecutter/reviews/best-headphones/")!,
                productId: 900001,
                productTitle: "The best Bluetooth wireless headphones",
                productDescription: "Lightweight and comfortable\nGreat battery life (30-50 hours)\nIPX5 water resistant",
                images: nil,
                hasDealData: false,
                sources: [
                    CommerceSource(merchantName: "Walmart", affiliateUrl: nil, priceFormatted: "$150", priceRaw: 15000, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                ],
                imageUrl: nil,
                merchantName: "JBL",
                affiliateUrl: nil,
                priceFormatted: nil,
                pickTypeId: nil,
                ribbon: nil,
                categoryName: "Electronics",
                categorySlug: "electronics",
                articleHeroImageURL: nil,
                isShopifyProduct: false,
                shopifyVariantId: nil
            ),
            CommerceItem(
                articleId: 90001,
                articleTitle: "Best Headphones",
                articleUrl: URL(string: "https://www.nytimes.com/wirecutter/reviews/best-headphones/")!,
                productId: 900002,
                productTitle: "The best wireless noise-cancelling headphones",
                productDescription: "Lightweight and comfortable\nGreat noise reduction\nHigh price tag",
                images: nil,
                hasDealData: false,
                sources: [
                    CommerceSource(merchantName: "Amazon", affiliateUrl: nil, priceFormatted: "$458", priceRaw: 45800, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                    CommerceSource(merchantName: "Walmart", affiliateUrl: nil, priceFormatted: "$458", priceRaw: 45800, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                    CommerceSource(merchantName: "Best Buy", affiliateUrl: nil, priceFormatted: "$458", priceRaw: 45800, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                ],
                imageUrl: nil,
                merchantName: "Sony",
                affiliateUrl: nil,
                priceFormatted: nil,
                pickTypeId: nil,
                ribbon: nil,
                categoryName: "Electronics",
                categorySlug: "electronics",
                articleHeroImageURL: nil,
                isShopifyProduct: false,
                shopifyVariantId: nil
            ),
            CommerceItem(
                articleId: 90001,
                articleTitle: "Best Headphones",
                articleUrl: URL(string: "https://www.nytimes.com/wirecutter/reviews/best-headphones/")!,
                productId: 900003,
                productTitle: "The best noise-cancelling earbuds",
                productDescription: "Excellent noise cancellation in a small package\nBest noise-reducing microphones we've tested\nIP55 water and dust resistant",
                images: nil,
                hasDealData: false,
                sources: [
                    CommerceSource(merchantName: "Amazon", affiliateUrl: nil, priceFormatted: "$170", priceRaw: 17000, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                    CommerceSource(merchantName: "Walmart", affiliateUrl: nil, priceFormatted: "$170", priceRaw: 17000, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                    CommerceSource(merchantName: "Best Buy", affiliateUrl: nil, priceFormatted: "$170", priceRaw: 17000, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                ],
                imageUrl: nil,
                merchantName: "Soundcore",
                affiliateUrl: nil,
                priceFormatted: nil,
                pickTypeId: nil,
                ribbon: nil,
                categoryName: "Electronics",
                categorySlug: "electronics",
                articleHeroImageURL: nil,
                isShopifyProduct: false,
                shopifyVariantId: nil
            ),
            CommerceItem(
                articleId: 90001,
                articleTitle: "Best Headphones",
                articleUrl: URL(string: "https://www.nytimes.com/wirecutter/reviews/best-headphones/")!,
                productId: 900004,
                productTitle: "The best bone-conduction headphones",
                productDescription: "Leaves ears uncovered for awareness\nBetter bass than other bone-conduction pairs\n12-hour battery life",
                images: nil,
                hasDealData: false,
                sources: [
                    CommerceSource(merchantName: "Amazon", affiliateUrl: nil, priceFormatted: "$180", priceRaw: 18000, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                    CommerceSource(merchantName: "Walmart", affiliateUrl: nil, priceFormatted: "$180", priceRaw: 18000, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                    CommerceSource(merchantName: "REI", affiliateUrl: nil, priceFormatted: "$180", priceRaw: 18000, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                ],
                imageUrl: nil,
                merchantName: "Shokz",
                affiliateUrl: nil,
                priceFormatted: nil,
                pickTypeId: nil,
                ribbon: nil,
                categoryName: "Electronics",
                categorySlug: "electronics",
                articleHeroImageURL: nil,
                isShopifyProduct: false,
                shopifyVariantId: nil
            ),
            CommerceItem(
                articleId: 90001,
                articleTitle: "Best Headphones",
                articleUrl: URL(string: "https://www.nytimes.com/wirecutter/reviews/best-headphones/")!,
                productId: 900005,
                productTitle: "The best clip-on earbuds",
                productDescription: "Lightweight clip-on design\nSolid bass response with EQ app\n10-hour battery life, IP55 rated",
                images: nil,
                hasDealData: false,
                sources: [
                    CommerceSource(merchantName: "Amazon", affiliateUrl: nil, priceFormatted: "$56", priceRaw: 5600, dealAffiliateUrl: nil, promoCode: nil, promoEffect: nil, dealPriceFormatted: nil, streetPriceFormatted: nil),
                ],
                imageUrl: nil,
                merchantName: "EarFun",
                affiliateUrl: nil,
                priceFormatted: nil,
                pickTypeId: nil,
                ribbon: nil,
                categoryName: "Electronics",
                categorySlug: "electronics",
                articleHeroImageURL: nil,
                isShopifyProduct: false,
                shopifyVariantId: nil
            ),
        ],
        localImageOverrides: [
            900001: "SeriesImages/JBLTourOne",
            900002: "SeriesImages/SonyXM5",
            900003: "SeriesImages/SoundcoreEarbuds",
            900004: "SeriesImages/ShokzOpenRun",
            900005: "SeriesImages/EarFunClip",
        ],
        productBackgrounds: [
            900001: 0x8BC78B,
            900002: 0xC5E4E7,
            900003: 0x3366CC,
            900004: 0xD4E8ED,
            900005: 0xD0E4EA,
        ]
    )
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
