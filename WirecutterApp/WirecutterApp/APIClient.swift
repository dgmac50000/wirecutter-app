import Foundation

class APIClient {
    static let shared = APIClient()

    private let wirecutterBase = URL(string: "https://www.nytimes.com/wirecutter/wp-json/wp/v2")!
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Public

    func fetchCommerceFeed() async throws -> [CommerceItem] {
        let reviews = try await fetchReviews(count: 10)
        var allProducts: [CommerceItem] = []

        await withTaskGroup(of: [CommerceItem].self) { group in
            for review in reviews {
                group.addTask { [self] in
                    await self.extractProducts(from: review)
                }
            }
            for await products in group {
                allProducts.append(contentsOf: products)
            }
        }

        return allProducts
    }

    // MARK: - WordPress API

    private struct WPReview: Decodable {
        let id: Int
        let title: WPRendered
        let link: String
        let content: WPRendered
        let featuredMedia: Int

        enum CodingKeys: String, CodingKey {
            case id, title, link, content
            case featuredMedia = "featured_media"
        }
    }

    private struct WPRendered: Decodable {
        let rendered: String
    }

    private func fetchReviews(count: Int) async throws -> [WPReview] {
        var components = URLComponents(url: wirecutterBase.appendingPathComponent("review"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "\(count)"),
            URLQueryItem(name: "orderby", value: "modified"),
            URLQueryItem(name: "order", value: "desc"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try decoder.decode([WPReview].self, from: data)
    }

    // MARK: - Product Extraction from HTML

    private func extractProducts(from review: WPReview) async -> [CommerceItem] {
        let html = review.content.rendered
        let articleTitle = cleanHTML(review.title.rendered)
        let articleUrl = review.link

        guard let articleURL = URL(string: articleUrl) else { return [] }

        let images = matches(for: "src=\"(https://d34mvw1if3ud0g\\.cloudfront\\.net/[^\"]+)\"", in: html)
        let affiliateLinks = matches(for: "href=\"(https://wclink\\.co/link/[^\"]+)\"", in: html)
        let prices = matches(for: "\\$(\\d[\\d,]*)", in: html)

        guard !images.isEmpty else { return [] }

        let productDescriptions = extractDescriptions(from: html, imageUrls: images)

        var products: [CommerceItem] = []

        for (index, imageUrlString) in images.enumerated() {
            let productName = extractProductName(from: imageUrlString)
            let price = index < prices.count ? "$\(prices[index])" : nil
            let affiliate = index < affiliateLinks.count ? URL(string: affiliateLinks[index]) : nil
            let imageUrl = URL(string: imageUrlString)
            let description = index < productDescriptions.count ? productDescriptions[index] : nil

            let item = CommerceItem(
                articleId: review.id,
                articleTitle: articleTitle,
                articleUrl: articleURL,
                productId: review.id * 100 + index,
                productTitle: productName,
                productDescription: description,
                images: imageUrl != nil ? [imageUrl!] : nil,
                hasDealData: false,
                sources: nil,
                imageUrl: imageUrl,
                merchantName: "Amazon",
                affiliateUrl: affiliate,
                priceFormatted: price,
                pickTypeId: index == 0 ? 1 : nil,
                ribbon: index == 0 ? "Top Pick" : (index == 1 ? "Also Great" : nil)
            )
            products.append(item)
        }

        return products
    }

    /// Split HTML by product image occurrences and extract paragraph text following each image
    private func extractDescriptions(from html: String, imageUrls: [String]) -> [String?] {
        var descriptions: [String?] = []

        for (index, imageUrl) in imageUrls.enumerated() {
            guard let imageRange = html.range(of: imageUrl) else {
                descriptions.append(nil)
                continue
            }

            let afterImage = html[imageRange.upperBound...]

            let endBoundary: String.Index
            if index + 1 < imageUrls.count,
               let nextImageRange = afterImage.range(of: imageUrls[index + 1]) {
                endBoundary = nextImageRange.lowerBound
            } else {
                endBoundary = html.endIndex
            }

            let section = String(afterImage[afterImage.startIndex..<endBoundary])

            let paragraphs = matches(for: "<p[^>]*>(.*?)</p>", in: section)
            let cleanedParagraphs = paragraphs
                .map { stripHTMLTags($0) }
                .map { cleanHTML($0) }
                .filter { $0.count > 40 }

            let description = cleanedParagraphs.prefix(3).joined(separator: "\n\n")
            descriptions.append(description.isEmpty ? nil : description)
        }

        return descriptions
    }

    private func stripHTMLTags(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private func extractProductName(from imageUrl: String) -> String {
        // Image URLs look like: .../55107/Vornado-Transom_20250418-051442_full
        // Extract the product name portion
        guard let lastSlash = imageUrl.lastIndex(of: "/") else { return "Product" }
        var name = String(imageUrl[imageUrl.index(after: lastSlash)...])
        // Remove the timestamp suffix
        if let underscore = name.range(of: "_20") {
            name = String(name[..<underscore.lowerBound])
        }
        // Replace hyphens with spaces
        name = name.replacingOccurrences(of: "-", with: " ")
        return name
    }

    private func cleanHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#8216;", with: "'")
            .replacingOccurrences(of: "&#8220;", with: "\"")
            .replacingOccurrences(of: "&#8221;", with: "\"")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func matches(for pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[captureRange])
        }
    }
}
