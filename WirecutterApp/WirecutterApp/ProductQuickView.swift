import SwiftUI

struct ProductQuickView: View {
    let item: CommerceItem
    let onShop: (URL) -> Void
    let onDismiss: () -> Void

    @State private var showApplePayConfirmation = false
    @State private var selectedDetent: PresentationDetent = .medium

    private var bulletSummary: [String] {
        guard let desc = item.productDescription, !desc.isEmpty else {
            return []
        }
        let lines = desc.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(lines.prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 24)

            if selectedDetent == .medium {
                mediumContent
            } else {
                largeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .overlay {
            if showApplePayConfirmation {
                applePayConfirmationOverlay
            }
        }
        .presentationDetents([.medium, .fraction(1.0)], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .animation(.easeInOut(duration: 0.25), value: selectedDetent)
    }

    // MARK: - Medium Content (summary state)

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageUrl = item.displayImageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 180)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: 0xF5F5F5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                    }
                }
                .padding(.horizontal, 20)
            }

            if !bulletSummary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(bulletSummary, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(bullet)
                                .font(.nytFranklin(.medium, size: 15))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(spacing: 8) {
                ForEach(Array(mediumBuyButtons.enumerated()), id: \.offset) { _, btn in
                    Button {
                        if let url = btn.url { onShop(url) }
                    } label: {
                        Text(btn.text)
                            .font(.nytFranklin(.bold, size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text("Full review")
                        .font(.nytFranklin(.medium, size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.bottom, 12)
        }
        .padding(.top, 4)
    }

    private var mediumBuyButtons: [(text: String, url: URL?)] {
        if let sources = item.sources, !sources.isEmpty {
            return Array(sources.prefix(2)).map { source in
                let price = source.dealPriceFormatted ?? source.priceFormatted ?? ""
                let merchant = source.merchantName
                return (text: "\(price) from \(merchant)", url: source.dealAffiliateUrl ?? source.affiliateUrl)
            }
        }
        if let price = item.priceFormatted, let merchant = item.merchantName {
            return [(text: "\(price) from \(merchant)", url: item.affiliateUrl)]
        }
        return []
    }

    // MARK: - Large Content (article state)

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let imageUrl = item.displayImageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        default:
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: 0xEEEEEE))
                                .frame(width: 44, height: 44)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.articleTitle)
                        .font(.nytFranklin(.bold, size: 14))
                        .lineLimit(1)
                    Text("Wirecutter")
                        .font(.nytFranklin(.medium, size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                buyPill
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 20)

            ArticleWebView(url: item.articleUrl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var buyPill: some View {
        Group {
            if let source = item.sources?.first, let url = source.dealAffiliateUrl ?? source.affiliateUrl {
                Button {
                    onShop(url)
                } label: {
                    Text(source.dealPriceFormatted ?? source.priceFormatted ?? "Buy")
                        .font(.nytFranklin(.bold, size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
            } else if let url = item.affiliateUrl {
                Button {
                    onShop(url)
                } label: {
                    Text(item.priceFormatted ?? "Buy")
                        .font(.nytFranklin(.bold, size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Deep Dive")
                    .font(.nytFranklin(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(item.productTitle)
                    .font(.nytFranklin(size: 22, weight: .heavy))
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
                    .font(.nytFranklin(size: 18, weight: .semibold))
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
                    .font(.nytFranklin(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text(item.productTitle)
                    .font(.nytFranklin(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let price = item.displayPrice {
                    Text(price)
                        .font(.nytFranklin(size: 18, weight: .semibold))
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
                .font(.nytFranklin(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .disabled(url == nil)
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
