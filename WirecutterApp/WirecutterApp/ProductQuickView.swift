import SwiftUI

struct ProductQuickView: View {
    let item: CommerceItem
    let onShop: (URL) -> Void
    let onReadArticle: (URL) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                dragHandle
                header
                heroImage
                productTile
                articleReference
                ledeText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .background(Color(.systemBackground))
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray3))
                .frame(width: 40, height: 5)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quick view")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(item.productTitle)
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.5)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        Group {
            if let imageUrl = item.displayImageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 335)
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 335)
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Product Tile

    private var productTile: some View {
        HStack(alignment: .top, spacing: 16) {
            if let imageUrl = item.displayImageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 109, height: 100)
                            .clipped()
                    default:
                        thumbnailPlaceholder
                    }
                }
                .frame(width: 109, height: 100)
                .clipped()
            } else {
                thumbnailPlaceholder
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.productTitle)
                    .font(.system(size: 16, weight: .bold))
                    .tracking(-0.5)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)

                affiliateLinks
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Affiliate Links

    private var affiliateLinks: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let sources = item.sources, !sources.isEmpty {
                ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                    affiliateLinkRow(
                        price: source.dealPriceFormatted ?? source.priceFormatted,
                        merchant: source.merchantName,
                        url: source.dealAffiliateUrl ?? source.affiliateUrl
                    )
                }
            } else if let price = item.priceFormatted, let merchant = item.merchantName {
                affiliateLinkRow(
                    price: price,
                    merchant: merchant,
                    url: item.affiliateUrl
                )
            }
        }
    }

    private func affiliateLinkRow(price: String?, merchant: String, url: URL?) -> some View {
        Button {
            if let url = url {
                onShop(url)
            }
        } label: {
            Text("\(price ?? "") from \(merchant)")
                .font(.system(size: 14, weight: .medium))
                .underline()
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .disabled(url == nil)
    }

    // MARK: - Article Reference

    private var articleReference: some View {
        Button {
            onReadArticle(item.articleUrl)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("From")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(item.articleTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Lede Text

    private var ledeText: some View {
        Group {
            if let description = item.productDescription {
                Text(description)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(12)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Placeholders

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color(hex: 0xEEEEEE))
            .frame(maxWidth: .infinity)
            .frame(height: 335)
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color(hex: 0xEEEEEE))
            .frame(width: 109, height: 100)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

#Preview {
    ProductQuickView(
        item: CommerceItem(
            articleId: 1,
            articleTitle: "Best Throw Blankets",
            articleUrl: URL(string: "https://www.nytimes.com/wirecutter/reviews/best-throw-blankets/")!,
            productId: 100,
            productTitle: "Pendleton Block Plaid Organic Cotton Fringed Throw",
            productDescription: "A classic Pendleton wool blanket can set you back as much as $500. Fortunately, we might like these Pendleton Block Plaid Organic Cotton Fringed Throws even better. They're made with layers of exceptionally soft cotton and crossed horizontally with tiny quilt-like hand stitching.",
            images: nil,
            hasDealData: false,
            sources: nil,
            imageUrl: URL(string: "https://d34mvw1if3ud0g.cloudfront.net/product-image.jpg"),
            merchantName: "Nordstrom",
            affiliateUrl: URL(string: "https://wclink.co/link/example"),
            priceFormatted: "$98",
            pickTypeId: 1,
            ribbon: "Top Pick",
            categoryName: "Home",
            categorySlug: "home",
            articleHeroImageURL: nil
        ),
        onShop: { _ in },
        onReadArticle: { _ in },
        onDismiss: {}
    )
}
