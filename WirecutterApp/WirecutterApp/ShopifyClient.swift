import Foundation

/// Client for the Wirecutter Shopify Storefront GraphQL API.
/// Uses the public storefront access token (safe for client-side use).
final class ShopifyClient {
    static let shared = ShopifyClient()

    private let endpoint = URL(string: "https://wirecutterstore.nytimes.com/api/2026-01/graphql.json")!
    private let storefrontToken = "a3462b5fc8c4b4d031925a4d9800243d"
    private let storeDomain = "wirecutterstore.nytimes.com"

    /// Maps Shopify collection handles → app category slugs.
    private let collectionToSlug: [String: (slug: String, name: String)] = [
        "in-the-kitchen": ("kitchen", "Kitchen"),
        "kitchen": ("kitchen", "Kitchen"),
        "home": ("home", "Home"),
        "clothing-accessories": ("style", "Style"),
        "travel": ("travel", "Travel"),
        "gifts": ("gifts", "Gifts"),
        "best-sellers": ("electronics", "Electronics"),
        "summer-favorites": ("outdoors", "Outdoors"),
    ]

    // MARK: - Public

    /// Fetches products from all known Shopify collections and converts to `CommerceItem`.
    func fetchAllProducts() async -> [CommerceItem] {
        let handles = Array(collectionToSlug.keys)

        var allItems: [CommerceItem] = []
        var seenIds = Set<Int>()

        await withTaskGroup(of: [CommerceItem].self) { group in
            for handle in handles {
                group.addTask { [self] in
                    await self.fetchCollection(handle: handle)
                }
            }
            for await items in group {
                for item in items where seenIds.insert(item.productId).inserted {
                    allItems.append(item)
                }
            }
        }

        return allItems
    }

    // MARK: - Per-Collection Fetch

    private func fetchCollection(handle: String) async -> [CommerceItem] {
        let query = """
        {
          collection(handle: "\(handle)") {
            title
            handle
            products(first: 10) {
              edges {
                node {
                  id
                  title
                  handle
                  description
                  images(first: 3) {
                    edges {
                      node {
                        url
                      }
                    }
                  }
                  priceRange {
                    minVariantPrice {
                      amount
                      currencyCode
                    }
                  }
                  variants(first: 1) {
                    edges {
                      node {
                        id
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """

        guard let data = await executeQuery(query) else { return [] }

        do {
            let response = try JSONDecoder().decode(ShopifyResponse.self, from: data)
            guard let collection = response.data?.collection else { return [] }

            let mapping = collectionToSlug[handle] ?? (slug: "other", name: "Other")

            return collection.products.edges.compactMap { edge -> CommerceItem? in
                let product = edge.node
                return shopifyProductToCommerceItem(product, categorySlug: mapping.slug, categoryName: mapping.name)
            }
        } catch {
            return []
        }
    }

    // MARK: - GraphQL Execution

    private func executeQuery(_ query: String) async -> Data? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(storefrontToken, forHTTPHeaderField: "X-Shopify-Storefront-Access-Token")
        request.timeoutInterval = 10

        let body: [String: Any] = ["query": query]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    // MARK: - Conversion

    private func shopifyProductToCommerceItem(
        _ product: ShopifyProduct,
        categorySlug: String,
        categoryName: String
    ) -> CommerceItem? {
        let imageURLs = product.images.edges.compactMap { URL(string: $0.node.url) }
        let variantId = product.variants.edges.first?.node.id

        let priceAmount = product.priceRange.minVariantPrice.amount
        let currencyCode = product.priceRange.minVariantPrice.currencyCode
        let priceFormatted = formatPrice(amount: priceAmount, currency: currencyCode)

        let shopUrl = URL(string: "https://\(storeDomain)/products/\(product.handle)")

        let stableId = abs(product.id.hashValue) % 900_000 + 100_000

        return CommerceItem(
            articleId: stableId,
            articleTitle: "Wirecutter Store",
            articleUrl: shopUrl ?? URL(string: "https://\(storeDomain)")!,
            productId: stableId,
            productTitle: product.title,
            productDescription: product.description.isEmpty ? nil : product.description,
            images: imageURLs.isEmpty ? nil : imageURLs,
            hasDealData: nil,
            sources: nil,
            imageUrl: imageURLs.first,
            merchantName: "Wirecutter Store",
            affiliateUrl: shopUrl,
            priceFormatted: priceFormatted,
            pickTypeId: nil,
            ribbon: nil,
            categoryName: categoryName,
            categorySlug: categorySlug,
            articleHeroImageURL: nil,
            isShopifyProduct: true,
            shopifyVariantId: variantId
        )
    }

    private func formatPrice(amount: String, currency: String) -> String {
        guard let value = Double(amount) else { return "$\(amount)" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: value)) ?? "$\(amount)"
    }
}

// MARK: - Shopify GraphQL Response Models

private struct ShopifyResponse: Decodable {
    let data: ShopifyData?
}

private struct ShopifyData: Decodable {
    let collection: ShopifyCollection?
}

private struct ShopifyCollection: Decodable {
    let title: String
    let handle: String
    let products: ShopifyProductConnection
}

private struct ShopifyProductConnection: Decodable {
    let edges: [ShopifyProductEdge]
}

private struct ShopifyProductEdge: Decodable {
    let node: ShopifyProduct
}

private struct ShopifyProduct: Decodable {
    let id: String
    let title: String
    let handle: String
    let description: String
    let images: ShopifyImageConnection
    let priceRange: ShopifyPriceRange
    let variants: ShopifyVariantConnection
}

private struct ShopifyImageConnection: Decodable {
    let edges: [ShopifyImageEdge]
}

private struct ShopifyImageEdge: Decodable {
    let node: ShopifyImageNode
}

private struct ShopifyImageNode: Decodable {
    let url: String
}

private struct ShopifyPriceRange: Decodable {
    let minVariantPrice: ShopifyPrice
}

private struct ShopifyPrice: Decodable {
    let amount: String
    let currencyCode: String
}

private struct ShopifyVariantConnection: Decodable {
    let edges: [ShopifyVariantEdge]
}

private struct ShopifyVariantEdge: Decodable {
    let node: ShopifyVariantNode
}

private struct ShopifyVariantNode: Decodable {
    let id: String
}
