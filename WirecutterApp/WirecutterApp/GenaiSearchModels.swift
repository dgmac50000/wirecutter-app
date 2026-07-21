import Foundation

struct SearchArticle: Codable, Identifiable {
    let id: Int
    let title: String
    let url: URL
    let summary: String?
    let imageUrl: URL?
    let publishedDate: String?
}

struct SearchAnswer: Codable {
    let text: String
    let citations: [Int]
}

struct SearchProduct: Codable, Identifiable {
    var id = UUID()
    let productId: Int
    let name: String
    let priceFormatted: String?
    let merchantName: String?
    let affiliateUrl: URL?

    enum CodingKeys: String, CodingKey {
        case productId, name, priceFormatted, merchantName, affiliateUrl
    }
}

struct GenaiSearchResponse: Codable {
    let articles: [SearchArticle]
    let answer: SearchAnswer
    let products: [SearchProduct]
}
