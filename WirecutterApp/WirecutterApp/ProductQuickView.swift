import SwiftUI

struct ProductQuickView: View {
    let item: CommerceItem
    let onShop: (URL) -> Void
    let onDismiss: () -> Void

    @State private var showApplePayConfirmation = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                dragHandle
                header
                heroImage
                productTile
                buyButtons
                ledeText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .background(Color(.systemBackground))
        .overlay {
            if showApplePayConfirmation {
                applePayConfirmationOverlay
            }
        }
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

            VStack(alignment: .leading, spacing: 4) {
                Text(item.productTitle)
                    .font(.system(size: 16, weight: .bold))
                    .tracking(-0.5)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Buy Buttons

    private var buyButtons: some View {
        VStack(spacing: 10) {
            if item.isShopifyProduct == true {
                applePayButton
            }

            if let sources = item.sources, !sources.isEmpty {
                ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                    buyButton(
                        price: source.dealPriceFormatted ?? source.priceFormatted,
                        merchant: source.merchantName,
                        url: source.dealAffiliateUrl ?? source.affiliateUrl
                    )
                }
            } else if item.isShopifyProduct == true {
                buyButton(
                    price: item.priceFormatted,
                    merchant: "Wirecutter Store",
                    url: item.shopUrl
                )
            } else if let price = item.priceFormatted, let merchant = item.merchantName {
                buyButton(
                    price: price,
                    merchant: merchant,
                    url: item.affiliateUrl
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Apple Pay Button

    private var applePayButton: some View {
        Button {
            simulateApplePayCheckout()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 16, weight: .semibold))
                Text("Pay")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func simulateApplePayCheckout() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showApplePayConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showApplePayConfirmation = false
            }
        }
    }

    // MARK: - Apple Pay Confirmation Overlay

    private var applePayConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text("Order Confirmed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text(item.productTitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let price = item.displayPrice {
                    Text(price)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(32)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func buyButton(price: String?, merchant: String, url: URL?) -> some View {
        Button {
            if let url = url {
                onShop(url)
            }
        } label: {
            Text("\(price ?? "") from \(merchant)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .disabled(url == nil)
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
            articleHeroImageURL: nil,
            isShopifyProduct: nil,
            shopifyVariantId: nil
        ),
        onShop: { _ in },
        onDismiss: {}
    )
}
