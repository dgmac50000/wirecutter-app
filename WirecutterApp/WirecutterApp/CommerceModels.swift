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

    var id: Int { productId }

    /// Best image: first from `images` array, otherwise fallback to `imageUrl`
    var displayImageUrl: URL? {
        images?.first ?? imageUrl
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
}

struct CommerceFeedResponse: Codable {
    let items: [CommerceItem]
}
