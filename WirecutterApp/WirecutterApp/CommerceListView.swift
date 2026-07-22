import SwiftUI

struct CommerceListView: View {
    private static let pageSize = 8

    @State private var items: [CommerceItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?
    @State private var searchText = ""
    @State private var quickViewItem: CommerceItem?
    @State private var feedMode: FeedMode = .forYou
    /// How many products are visible per section (`mode|sectionId` → count).
    @State private var visibleCountBySection: [String: Int] = [:]

    private var filteredItems: [CommerceItem] {
        if searchText.isEmpty { return items }
        let query = searchText.lowercased()
        return items.filter {
            $0.productTitle.lowercased().contains(query) ||
            $0.articleTitle.lowercased().contains(query) ||
            $0.resolvedCategoryName.lowercased().contains(query) ||
            ($0.merchantName?.lowercased().contains(query) ?? false)
        }
    }

    private var sections: [CommerceCategorySection] {
        switch feedMode {
        case .forYou:
            return CommerceCategorySection.build(from: filteredItems)
        case .assistant:
            return CommerceCategorySection.buildAssistantPersonas(from: filteredItems)
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
                } else if sections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28, pinnedViews: [.sectionHeaders]) {
                            ForEach(sections) { section in
                                let visibleItems = visibleItems(for: section)
                                let remaining = section.items.count - visibleItems.count

                                Section {
                                    if let heroURL = section.heroImageURL {
                                        CategoryHeroImage(url: heroURL)
                                    }

                                    ForEach(visibleItems.map {
                                        FeedRow(sectionID: section.id, item: $0)
                                    }) { row in
                                        CommerceCardView(
                                            item: row.item,
                                            onShop: { url in
                                                safariItem = IdentifiableURL(url: url)
                                            },
                                            onQuickView: {
                                                quickViewItem = row.item
                                            }
                                        )
                                    }

                                    if remaining > 0 {
                                        Button {
                                            loadMore(in: section)
                                        } label: {
                                            Text(loadMoreLabel(remaining: remaining))
                                                .font(.subheadline.weight(.semibold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.primary)
                                    }
                                } header: {
                                    CategorySectionHeader(
                                        title: section.name,
                                        count: section.items.count,
                                        subtitle: feedMode == .assistant ? "Gift ideas" : nil
                                    )
                                }
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
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Mode", selection: $feedMode) {
                    ForEach(FeedMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground))
            }
            .searchable(text: $searchText, prompt: searchPrompt)
            .background(Color(.systemGroupedBackground))
            .onChange(of: feedMode) { _, _ in
                visibleCountBySection = [:]
            }
            .onChange(of: searchText) { _, _ in
                visibleCountBySection = [:]
            }
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

    private var searchPrompt: String {
        feedMode == .assistant
            ? "Search gifts for Dad, Alex…"
            : "Search products, brands…"
    }

    private func sectionKey(_ section: CommerceCategorySection) -> String {
        "\(feedMode.rawValue)|\(section.id)"
    }

    private func visibleLimit(for section: CommerceCategorySection) -> Int {
        visibleCountBySection[sectionKey(section)] ?? Self.pageSize
    }

    private func visibleItems(for section: CommerceCategorySection) -> [CommerceItem] {
        Array(section.items.prefix(visibleLimit(for: section)))
    }

    private func loadMore(in section: CommerceCategorySection) {
        let key = sectionKey(section)
        let current = visibleCountBySection[key] ?? Self.pageSize
        visibleCountBySection[key] = min(current + Self.pageSize, section.items.count)
    }

    private func loadMoreLabel(remaining: Int) -> String {
        let next = min(Self.pageSize, remaining)
        if remaining <= Self.pageSize {
            return "Load more (\(remaining))"
        }
        return "Load more (\(next) of \(remaining))"
    }

    private func loadFeed() async {
        do {
            let fetched = try await APIClient.shared.fetchCommerceFeed()
            items = fetched
            visibleCountBySection = [:]
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Category chrome

private struct CategorySectionHeader: View {
    let title: String
    let count: Int
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground).opacity(0.96))
    }
}

private struct CategoryHeroImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 220)
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
            @unknown default:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 220)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
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

private struct FeedRow: Identifiable {
    let sectionID: String
    let item: CommerceItem
    var id: String { "\(sectionID)-\(item.productId)" }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    CommerceListView()
}
