import Foundation

/// Prefers Wirecutter editorial hi-res assets only when the match is confident.
/// Otherwise keeps Phoenix/catalog CloudFront shots (the safe default).
enum ProductImageRanking {
    enum Tier: Int, Comparable {
        case catalog = 0
        case unknown = 1
        case hires = 2

        static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Strict bar for swapping off the catalog default (aligned with product-images alt matching).
    static let confidentOverlapThreshold: Double = 0.85
    /// Best match must beat the runner-up by at least this much (reduces same-article mixups).
    static let uniqueLeadMargin: Double = 0.2
    static let minimumTokenHits: Int = 2

    private static let stopwords: Set<String> = [
        "the", "le", "la", "a", "an", "of", "and", "set", "for", "with", "plus", "in",
        "glass", "glasses", "tumbler", "tumblers", "drinking", "sound", "labs", "co",
        "closeup", "five", "four", "three", "two", "lip", "on", "to", "our", "pick",
        // Article / CDN path noise — not product identity
        "best", "review", "reviews", "wirecutter", "cdn", "https", "http", "www",
        "com", "media", "content", "wp", "jpg", "jpeg", "png", "webp", "full",
        "2048px", "1024x1024", "1024x683", "3x2", "2x1",
    ]

    static func tier(of urlString: String) -> Tier {
        let lower = urlString.lowercased()
        if lower.contains("cdn.thewirecutter.com")
            || lower.contains("/wp-content/media/")
            || lower.contains("2048px") {
            return .hires
        }
        if lower.contains("d34mvw1if3ud0g.cloudfront.net")
            || lower.contains("phoenixstagingimages")
            || lower.contains("product_images") {
            return .catalog
        }
        return .unknown
    }

    static func tier(of url: URL) -> Tier {
        tier(of: url.absoluteString)
    }

    /// Normalize WP upload paths to the public media CDN path.
    static func normalizeMediaURL(_ urlString: String) -> String {
        urlString.replacingOccurrences(of: "/wp-content/uploads/", with: "/wp-content/media/")
    }

    /// Sort so hi-res comes first; stable within the same tier.
    static func preferHiRes(_ urls: [URL]) -> [URL] {
        urls.enumerated()
            .sorted { lhs, rhs in
                let lt = tier(of: lhs.element)
                let rt = tier(of: rhs.element)
                if lt != rt { return lt > rt }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    static func preferHiRes(_ urlStrings: [String]) -> [String] {
        urlStrings.enumerated()
            .sorted { lhs, rhs in
                let lt = tier(of: lhs.element)
                let rt = tier(of: rhs.element)
                if lt != rt { return lt > rt }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Display URL: use a confident hi-res when present in `images`, else catalog/`fallback`.
    /// Does **not** promote arbitrary CDN URLs — callers must only put vetted hi-res in `images`.
    static func preferredDisplayURL(images: [URL]?, fallback: URL?) -> URL? {
        if let images {
            if let hiRes = images.first(where: { tier(of: $0) == .hires }) {
                return hiRes
            }
            if let catalog = images.first(where: { tier(of: $0) == .catalog }) {
                return catalog
            }
            return images.first ?? fallback
        }
        return fallback
    }

    // MARK: - Name matching

    static func tokens(from string: String) -> Set<String> {
        let parts = string.lowercased().matches(for: "[a-z0-9]+")
        return Set(parts.filter { $0.count > 1 && !stopwords.contains($0) })
    }

    /// Fraction of `productTokens` that appear in `candidate` (alt text or filename).
    static func overlap(productTokens: Set<String>, candidate: String) -> Double {
        guard !productTokens.isEmpty else { return 0 }
        let other = tokens(from: candidate)
        let hits = productTokens.filter { other.contains($0) }.count
        return Double(hits) / Double(productTokens.count)
    }

    static func tokenHitCount(productTokens: Set<String>, candidate: String) -> Int {
        let other = tokens(from: candidate)
        return productTokens.filter { other.contains($0) }.count
    }

    /// Score a single candidate for a product (max of alt vs URL token overlap).
    static func matchScore(
        productName: String,
        candidateURL: String,
        candidateAlt: String
    ) -> Double {
        let productTokens = tokens(from: productName)
        guard !productTokens.isEmpty else { return 0 }
        return max(
            overlap(productTokens: productTokens, candidate: candidateAlt),
            overlap(productTokens: productTokens, candidate: candidateURL)
        )
    }

    /// Whether a score is confident enough to replace the catalog default.
    static func isConfidentMatch(
        score: Double,
        productName: String,
        candidateURL: String,
        candidateAlt: String
    ) -> Bool {
        guard score >= confidentOverlapThreshold else { return false }
        let productTokens = tokens(from: productName)
        let hits = max(
            tokenHitCount(productTokens: productTokens, candidate: candidateAlt),
            tokenHitCount(productTokens: productTokens, candidate: candidateURL)
        )
        // Short names (e.g. "Currex RunPro"): allow 1 hit only if overlap is perfect.
        if productTokens.count <= 2 {
            return hits >= 1 && score >= 0.99
        }
        return hits >= minimumTokenHits
    }

    /// Best hi-res candidate only when uniquely and confidently matched.
    /// Returns nil → caller should keep the boring catalog default.
    static func bestHiResMatch(
        productName: String,
        candidates: [(url: String, alt: String)],
        minimumOverlap: Double = confidentOverlapThreshold
    ) -> URL? {
        let productTokens = tokens(from: productName)
        guard !productTokens.isEmpty else { return nil }

        var scored: [(url: String, score: Double)] = []

        for candidate in candidates {
            guard tier(of: candidate.url) == .hires else { continue }
            let score = max(
                overlap(productTokens: productTokens, candidate: candidate.alt),
                overlap(productTokens: productTokens, candidate: candidate.url)
            )
            guard isConfidentMatch(
                score: score,
                productName: productName,
                candidateURL: candidate.url,
                candidateAlt: candidate.alt
            ), score >= minimumOverlap else {
                continue
            }
            scored.append((candidate.url, score))
        }

        scored.sort { $0.score > $1.score }
        guard let best = scored.first else { return nil }

        // Reject near-misses (likely wrong product in the same article).
        // Exact ties are fine — multiple equally good shots of the same product.
        if scored.count >= 2 {
            let second = scored[1].score
            if second < best.score && best.score - second < uniqueLeadMargin {
                return nil
            }
        }

        return URL(string: normalizeMediaURL(best.url))
    }
}

private extension String {
    func matches(for pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)
        return regex.matches(in: self, range: range).compactMap { match in
            guard let captureRange = Range(match.range, in: self) else { return nil }
            return String(self[captureRange])
        }
    }
}
