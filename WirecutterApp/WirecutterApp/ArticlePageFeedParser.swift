import Foundation

/// Raw product + image payloads from any upstream (article page, Minotaur, Phoenix).
/// Hi-res is only attached when `ProductImageRanking` is confident; otherwise catalog wins.
struct ProductImageBundle {
    var catalogURLs: [URL]
    var hiResCandidates: [(url: String, alt: String)]
    /// Optional hint (e.g. chapter-proximate hero). Still must pass confidence checks.
    var preferredHiResURL: URL?

    func resolvedDisplayURLs(productName: String) -> [URL] {
        // Safe default: catalog only.
        var urls = catalogURLs

        let hintCandidates: [(url: String, alt: String)] = {
            guard let preferredHiResURL else { return hiResCandidates }
            let hint = (
                url: preferredHiResURL.absoluteString,
                alt: preferredHiResURL.lastPathComponent
            )
            // Evaluate the hint alongside other chapter candidates; never auto-accept proximity.
            return [hint] + hiResCandidates
        }()

        if let matched = ProductImageRanking.bestHiResMatch(
            productName: productName,
            candidates: hintCandidates
        ) {
            // Confident hi-res first, catalog retained as fallback in the array.
            urls = [matched] + catalogURLs.filter { $0 != matched }
        }

        return urls
    }
}

/// Prototype provider: Wirecutter Next.js article HTML (`__NEXT_DATA__`).
/// Long-term: swap or complement with Minotaur `product.images` / Phoenix catalog.
enum ArticlePageFeedParser {
    private static let cdnHost = "cdn.thewirecutter.com"
    private static let catalogHost = "d34mvw1if3ud0g.cloudfront.net"
    private static let mediaPrefix = "https://cdn.thewirecutter.com/wp-content/media/"

    struct ParsedArticle {
        let title: String
        let link: URL
        let postId: Int
        let categoryName: String
        let categorySlug: String
        let heroImageURL: URL?
        let products: [ParsedProduct]
    }

    struct ParsedProduct {
        let productId: Int
        let name: String
        let title: String?
        let description: String?
        let ribbon: String?
        let pickTypeId: Int?
        let catalogImageURL: URL?
        let preferredHiResURL: URL?
        let hiResCandidates: [(url: String, alt: String)]
        let merchantName: String?
        let affiliateURL: URL?
        let priceFormatted: String?
    }

    static func fetchArticle(from link: URL) async throws -> ParsedArticle? {
        var request = URLRequest(url: link)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        return parse(html: html, fallbackLink: link)
    }

    static func parse(html: String, fallbackLink: URL) -> ParsedArticle? {
        guard let jsonText = extractNextDataJSON(from: html),
              let jsonData = jsonText.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let pageProps = dig(root, ["props", "pageProps"]) as? [String: Any],
              let post = pageProps["post"] as? [String: Any] else {
            return nil
        }

        let postId = post["id"] as? Int ?? 0
        let title = (post["title"] as? String) ?? (post["name"] as? String) ?? "Wirecutter"
        let linkString = post["link"] as? String
        let link = linkString.flatMap(URL.init(string:)) ?? fallbackLink

        let primarySection = post["primarySection"] as? [String: Any]
        let category = WirecutterCategory.normalize(
            sectionName: primarySection?["name"] as? String,
            sectionLink: primarySection?["link"] as? String
        )
        let heroImageURL = parseHeroImageURL(from: post["heroImage"])

        var products: [ParsedProduct] = []
        var seenProductIds = Set<Int>()

        // Prefer chapter-scoped products so we can attach nearby editorial heroes.
        if let chapters = post["chapters"] as? [[String: Any]] {
            for chapter in chapters {
                products.append(contentsOf: productsFromChapter(chapter, seen: &seenProductIds))
            }
        }

        // Fall back to structured intro callouts when chapters have no products.
        if products.isEmpty {
            let calloutRoots = [
                post["structuredIntroCallouts"] as? [[String: Any]],
                post["structuredIntro"] as? [[String: Any]],
            ].compactMap { $0 }

            for root in calloutRoots {
                for block in root {
                    for callout in callouts(in: block) {
                        if let parsed = parseCallout(callout, preferredHiRes: nil, chapterCandidates: []),
                           seenProductIds.insert(parsed.productId).inserted {
                            products.append(parsed)
                        }
                    }
                }
            }
        }

        guard !products.isEmpty else { return nil }
        return ParsedArticle(
            title: title,
            link: link,
            postId: postId,
            categoryName: category.name,
            categorySlug: category.slug,
            heroImageURL: heroImageURL,
            products: products
        )
    }

    private static func parseHeroImageURL(from raw: Any?) -> URL? {
        guard let hero = raw as? [String: Any] else { return nil }
        if let source = hero["source"] as? String,
           let absolute = absolutizeMediaURL(source) {
            return URL(string: stripQuery(absolute))
        }
        return nil
    }

    // MARK: - Chapter extraction

    private static func productsFromChapter(
        _ chapter: [String: Any],
        seen: inout Set<Int>
    ) -> [ParsedProduct] {
        guard let body = chapter["body"] as? [[String: Any]] else { return [] }

        var candidates: [(url: String, alt: String)] = []
        var seenURLs = Set<String>()
        var calloutsByIndex: [(index: Int, callout: [String: Any])] = []

        for (index, node) in body.enumerated() {
            for candidate in collectHiResCandidates(in: node) {
                if seenURLs.insert(candidate.url).inserted {
                    candidates.append(candidate)
                }
            }
            for callout in callouts(in: node) {
                calloutsByIndex.append((index, callout))
            }
        }

        var parsed: [ParsedProduct] = []
        for (_, callout) in calloutsByIndex {
            // No proximity auto-pick — only confident name/alt matches may replace catalog.
            guard let product = parseCallout(
                callout,
                preferredHiRes: nil,
                chapterCandidates: candidates
            ), seen.insert(product.productId).inserted else {
                continue
            }
            parsed.append(product)
        }
        return parsed
    }

    private static func parseCallout(
        _ callout: [String: Any],
        preferredHiRes: URL?,
        chapterCandidates: [(url: String, alt: String)]
    ) -> ParsedProduct? {
        let productId = callout["productId"] as? Int
            ?? callout["calloutId"] as? Int
            ?? 0
        guard productId != 0 else { return nil }

        let name = (callout["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }

        let images = callout["images"] as? [String: Any]
        let catalogString = images?["full"] as? String
        let catalogURL = catalogString.flatMap(URL.init(string:))

        let sources = callout["sources"] as? [[String: Any]] ?? []
        let primary = sources.first
        let merchant = primary?["merchantName"] as? String ?? primary?["store"] as? String
        let affiliate = (primary?["url"] as? String).flatMap(URL.init(string:))
        let price: String? = {
            if let formatted = (primary?["price"] as? [String: Any])?["formatted"] as? String {
                return formatted
            }
            return nil
        }()

        return ParsedProduct(
            productId: productId,
            name: name,
            title: callout["title"] as? String,
            description: callout["description"] as? String,
            ribbon: callout["ribbon"] as? String,
            pickTypeId: callout["pickTypeId"] as? Int,
            catalogImageURL: catalogURL,
            preferredHiResURL: preferredHiRes,
            hiResCandidates: chapterCandidates,
            merchantName: merchant,
            affiliateURL: affiliate,
            priceFormatted: price
        )
    }

    private static func callouts(in node: [String: Any]) -> [[String: Any]] {
        guard let dbData = node["dbData"] else { return [] }
        if let dict = dbData as? [String: Any], let callouts = dict["callouts"] as? [[String: Any]] {
            return callouts
        }
        return []
    }

    // MARK: - URL / alt collection

    /// Walk chapter JSON for hi-res CDN images, preferring real `img` alt text when present.
    private static func collectHiResCandidates(in obj: Any) -> [(url: String, alt: String)] {
        var out: [(url: String, alt: String)] = []
        var seen = Set<String>()
        collectHiResCandidates(in: obj, into: &out, seen: &seen)
        return out
    }

    private static func collectHiResCandidates(
        in obj: Any,
        into out: inout [(url: String, alt: String)],
        seen: inout Set<String>
    ) {
        guard let dict = obj as? [String: Any] else {
            if let array = obj as? [Any] {
                for value in array {
                    collectHiResCandidates(in: value, into: &out, seen: &seen)
                }
            }
            return
        }

        // Prefer structured <img> nodes with alt.
        if dict["name"] as? String == "img",
           let attribs = dict["attribs"] as? [String: Any],
           let src = attribs["src"] as? String,
           let absolute = absolutizeMediaURL(src),
           isHiRes(absolute) {
            let normalized = stripQuery(absolute)
            if seen.insert(normalized).inserted {
                let alt = (attribs["alt"] as? String) ?? altFromURL(normalized)
                out.append((normalized, alt))
            }
        }

        for value in dict.values {
            collectHiResCandidates(in: value, into: &out, seen: &seen)
        }
    }

    private static func absolutizeMediaURL(_ raw: String) -> String? {
        let cleaned = H.unescape(raw)
        if cleaned.hasPrefix("http"),
           cleaned.contains(cdnHost) || cleaned.contains(catalogHost) || cleaned.contains("/wp-content/media/") {
            return ProductImageRanking.normalizeMediaURL(cleaned)
        }
        if cleaned.contains("wp-content/media/") {
            var path = cleaned
            while path.hasPrefix("/") { path.removeFirst() }
            if let range = path.range(of: "wp-content/media/") {
                path = String(path[range.lowerBound...])
                return "https://cdn.thewirecutter.com/\(path)"
            }
        }
        // imagePaths.full style: "2025/09/BEST-….jpg"
        if cleaned.range(of: #"^\d{4}/\d{2}/.+\.(jpe?g|png|webp)$"#, options: .regularExpression) != nil {
            return mediaPrefix + cleaned
        }
        return nil
    }

    private static func isHiRes(_ url: String) -> Bool {
        ProductImageRanking.tier(of: url) == .hires
    }

    private static func altFromURL(_ url: String) -> String {
        guard let last = url.split(separator: "/").last else { return "" }
        let stem = last.split(separator: ".").first.map(String.init) ?? String(last)
        return stem.replacingOccurrences(of: "-", with: " ")
    }

    private static func stripQuery(_ url: String) -> String {
        if let q = url.firstIndex(of: "?") {
            return String(url[..<q])
        }
        return url
    }

    private static func extractNextDataJSON(from html: String) -> String? {
        guard let scriptRange = html.range(of: "id=\"__NEXT_DATA__\"") ?? html.range(of: "id='__NEXT_DATA__'") else {
            return nil
        }
        let afterId = html[scriptRange.upperBound...]
        guard let open = afterId.range(of: ">"),
              let close = afterId.range(of: "</script>") else {
            return nil
        }
        return String(afterId[open.upperBound..<close.lowerBound])
    }

    private static func dig(_ obj: Any, _ path: [String]) -> Any? {
        var current: Any = obj
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else { return nil }
            current = next
        }
        return current
    }
}

private enum H {
    static func unescape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x2F;", with: "/")
            .replacingOccurrences(of: "\\u0026", with: "&")
    }
}
