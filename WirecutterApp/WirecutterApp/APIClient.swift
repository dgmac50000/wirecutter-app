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

    /// Commerce feed for the prototype.
    ///
    /// Image strategy (source-agnostic ranking via `ProductImageRanking`):
    /// 1. Prefer Next.js article `__NEXT_DATA__` (catalog callouts + chapter CDN heroes)
    /// 2. Fall back to WP `content.rendered` HTML scrape
    /// Long-term: add Minotaur / Phoenix providers that fill the same `ProductImageBundle`.
    func fetchCommerceFeed() async throws -> [CommerceItem] {
        var reviews = try await fetchReviews(count: 8)

        // Prototype: always include a known rich-media review so hi-res chapter
        // images are easy to verify (article-page parser uses the URL, not WP HTML).
        let seedLink = "https://www.nytimes.com/wirecutter/reviews/best-smartwatch-iphone/"
        if !reviews.contains(where: { $0.link.contains("best-smartwatch-iphone") }) {
            reviews.insert(
                WPReview(
                    id: 882,
                    title: WPRendered(rendered: "The Apple Watch Is the Best Smartwatch for iPhone Owners"),
                    link: seedLink,
                    content: WPRendered(rendered: ""),
                    featuredMedia: 0
                ),
                at: 0
            )
        }

        var allProducts: [CommerceItem] = []
        var seenProductIds = Set<Int>()

        await withTaskGroup(of: [CommerceItem].self) { group in
            for review in reviews {
                group.addTask { [self] in
                    await self.products(for: review)
                }
            }
            for await products in group {
                for product in products where seenProductIds.insert(product.productId).inserted {
                    allProducts.append(product)
                }
            }
        }

        return allProducts
    }

    // MARK: - Per-review resolution

    private func products(for review: WPReview) async -> [CommerceItem] {
        let articleTitle = cleanHTML(review.title.rendered)
        guard let articleURL = URL(string: review.link) else { return [] }

        // Prototype path: structured article page (has editorial hi-res in chapters).
        if let parsed = try? await ArticlePageFeedParser.fetchArticle(from: articleURL),
           !parsed.products.isEmpty {
            return parsed.products.map { product in
                commerceItem(
                    from: product,
                    articleId: parsed.postId != 0 ? parsed.postId : review.id,
                    articleTitle: parsed.title.isEmpty ? articleTitle : parsed.title,
                    articleURL: parsed.link,
                    categoryName: parsed.categoryName,
                    categorySlug: parsed.categorySlug,
                    articleHeroImageURL: parsed.heroImageURL
                )
            }
        }

        // Fallback: thin WP REST HTML (catalog CloudFront only on most reviews).
        return extractProductsFromWPHTML(review: review, articleTitle: articleTitle, articleURL: articleURL)
    }

    private func commerceItem(
        from product: ArticlePageFeedParser.ParsedProduct,
        articleId: Int,
        articleTitle: String,
        articleURL: URL,
        categoryName: String,
        categorySlug: String,
        articleHeroImageURL: URL?
    ) -> CommerceItem {
        var catalog: [URL] = []
        if let catalogImageURL = product.catalogImageURL {
            catalog.append(catalogImageURL)
        }

        let bundle = ProductImageBundle(
            catalogURLs: catalog,
            hiResCandidates: product.hiResCandidates,
            preferredHiResURL: product.preferredHiResURL
        )
        let imageURLs = bundle.resolvedDisplayURLs(productName: product.name)

        return CommerceItem(
            articleId: articleId,
            articleTitle: articleTitle,
            articleUrl: articleURL,
            productId: product.productId,
            productTitle: product.name,
            productDescription: product.description,
            images: imageURLs.isEmpty ? nil : imageURLs,
            hasDealData: false,
            sources: nil,
            imageUrl: imageURLs.first ?? product.catalogImageURL,
            merchantName: product.merchantName,
            affiliateUrl: product.affiliateURL,
            priceFormatted: product.priceFormatted,
            pickTypeId: product.pickTypeId,
            ribbon: product.ribbon,
            categoryName: categoryName,
            categorySlug: categorySlug,
            articleHeroImageURL: articleHeroImageURL
        )
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

    // MARK: - WP HTML fallback

    private func extractProductsFromWPHTML(
        review: WPReview,
        articleTitle: String,
        articleURL: URL
    ) -> [CommerceItem] {
        let html = review.content.rendered

        let catalogImages = matches(for: "src=\"(https://d34mvw1if3ud0g\\.cloudfront\\.net/[^\"]+)\"", in: html)
        let hiResCandidates = extractHiResCandidates(from: html)
        let affiliateLinks = matches(for: "href=\"(https://wclink\\.co/link/[^\"]+)\"", in: html)
        let prices = matches(for: "\\$(\\d[\\d,]*)", in: html)

        guard !catalogImages.isEmpty else { return [] }

        let productDescriptions = extractDescriptions(from: html, imageUrls: catalogImages)

        var products: [CommerceItem] = []

        for (index, catalogUrlString) in catalogImages.enumerated() {
            let productName = extractProductName(from: catalogUrlString)
            let price = index < prices.count ? "$\(prices[index])" : nil
            let affiliate = index < affiliateLinks.count ? URL(string: affiliateLinks[index]) : nil
            let catalogUrl = URL(string: catalogUrlString)
            let description = index < productDescriptions.count ? productDescriptions[index] : nil

            let bundle = ProductImageBundle(
                catalogURLs: catalogUrl.map { [$0] } ?? [],
                hiResCandidates: hiResCandidates,
                preferredHiResURL: nil
            )
            let imageURLs = bundle.resolvedDisplayURLs(productName: productName)

            let item = CommerceItem(
                articleId: review.id,
                articleTitle: articleTitle,
                articleUrl: articleURL,
                productId: review.id * 100 + index,
                productTitle: productName,
                productDescription: description,
                images: imageURLs.isEmpty ? nil : imageURLs,
                hasDealData: false,
                sources: nil,
                imageUrl: imageURLs.first ?? catalogUrl,
                merchantName: "Amazon",
                affiliateUrl: affiliate,
                priceFormatted: price,
                pickTypeId: index == 0 ? 1 : nil,
                ribbon: index == 0 ? "Top Pick" : (index == 1 ? "Also Great" : nil),
                categoryName: "Other",
                categorySlug: "other",
                articleHeroImageURL: nil
            )
            products.append(item)
        }

        return products
    }

    private func extractHiResCandidates(from html: String) -> [(url: String, alt: String)] {
        let imgTags = matches(for: "(<img\\b[^>]*>)", in: html)
        var candidates: [(url: String, alt: String)] = []
        var seen = Set<String>()

        for tag in imgTags {
            guard let src = attribute("src", in: tag) else { continue }
            let normalized = ProductImageRanking.normalizeMediaURL(src)
            guard ProductImageRanking.tier(of: normalized) == .hires else { continue }
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            let alt = attribute("alt", in: tag).map(cleanHTML) ?? ""
            candidates.append((normalized, alt))
        }

        return candidates
    }

    private func attribute(_ name: String, in tag: String) -> String? {
        let patterns = [
            "\(name)=\"([^\"]*)\"",
            "\(name)='([^']*)'",
        ]
        for pattern in patterns {
            if let value = matches(for: pattern, in: tag).first {
                return value
            }
        }
        return nil
    }

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
        guard let lastSlash = imageUrl.lastIndex(of: "/") else { return "Product" }
        var name = String(imageUrl[imageUrl.index(after: lastSlash)...])
        if let underscore = name.range(of: "_20") {
            name = String(name[..<underscore.lowerBound])
        }
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
