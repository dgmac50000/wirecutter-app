import SwiftUI

struct CommerceListView: View {
    @State private var items: [CommerceItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?
    @State private var searchText = ""
    @State private var quickViewItem: CommerceItem?

    private var filteredItems: [CommerceItem] {
        if searchText.isEmpty { return items }
        let query = searchText.lowercased()
        return items.filter {
            $0.productTitle.lowercased().contains(query) ||
            $0.articleTitle.lowercased().contains(query) ||
            ($0.merchantName?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading deals…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredItems) { item in
                                CommerceCardView(item: item, onShop: { url in
                                    safariItem = IdentifiableURL(url: url)
                                }, onQuickView: {
                                    quickViewItem = item
                                })
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("WirecutterLogo")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 22)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search products, brands…")
            .background(Color(.systemGroupedBackground))
            .sheet(item: $safariItem) { item in
                SafariView(url: item.url)
                    .ignoresSafeArea()
            }
            .sheet(item: $quickViewItem) { item in
                ProductQuickView(
                    item: item,
                    onShop: { url in
                        quickViewItem = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            safariItem = IdentifiableURL(url: url)
                        }
                    },
                    onReadArticle: { url in
                        quickViewItem = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            safariItem = IdentifiableURL(url: url)
                        }
                    },
                    onDismiss: {
                        quickViewItem = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
        }
        .task {
            await loadFeed()
        }
    }

    private func loadFeed() async {
        do {
            let fetched = try await APIClient.shared.fetchCommerceFeed()
            items = fetched
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Commerce Card

private struct CommerceCardView: View {
    let item: CommerceItem
    let onShop: (URL) -> Void
    let onQuickView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageUrl = item.displayImageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    @unknown default:
                        placeholder
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let ribbon = item.ribbon {
                Text(ribbon)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ribbonColor(for: ribbon))
                    .clipShape(Capsule())
            }

            Text(item.productTitle)
                .font(.headline)
                .lineLimit(2)

            if let price = item.displayPrice {
                HStack(spacing: 6) {
                    Text(price)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    if item.hasDealData == true,
                       let street = item.sources?.first?.streetPriceFormatted {
                        Text(street)
                            .font(.subheadline)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let merchant = item.displayMerchant {
                HStack(spacing: 6) {
                    Text("at \(merchant)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let promo = item.sources?.first?.promoCode, !promo.isEmpty {
                        Text("Code: \(promo)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 12) {
                if let shopUrl = item.shopUrl {
                    Button {
                        onShop(shopUrl)
                    } label: {
                        Label(item.displayMerchant ?? "Buy", systemImage: "cart")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                }

                Button {
                    onQuickView()
                } label: {
                    Label("Quick view", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 200)
    }

    private func ribbonColor(for ribbon: String) -> Color {
        switch ribbon {
        case "Top Pick": return .red
        case "Budget Pick": return .green
        case "Upgrade Pick": return .blue
        default: return .gray
        }
    }
}

// MARK: - Identifiable URL wrapper for .sheet(item:)

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    CommerceListView()
}
