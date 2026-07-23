import SwiftUI

struct CommerceListView: View {
    @State private var items: [CommerceItem] = []
    @State private var shopifyProducts: [CommerceItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?
    @State private var quickViewItem: CommerceItem?
    @State private var feedMode: FeedMode = .forYou
    @State private var selectedFilter: String = "For you"
    @State private var showHeader = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showAsk = false
    @State private var seeAllSection: CommerceCategorySection?

    private let filters: [(name: String, icon: String?)] = [
        ("For you", nil),
        ("My Lists", nil),
        ("Prime Day", "tag.fill"),
        ("Gifts", nil),
        ("Sleep", nil),
        ("Home", nil),
    ]

    private var filteredItems: [CommerceItem] {
        return items
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
        VStack(spacing: 0) {
            if showHeader {
                headerView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            filterRow

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
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No products found")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 32) {
                            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                                // Category carousel
                                VStack(alignment: .leading, spacing: 8) {
                                    CategorySectionHeader(
                                        title: section.name,
                                        count: section.items.count,
                                        onSeeAll: {
                                            seeAllSection = section
                                        }
                                    )

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 12) {
                                            ForEach(Array(section.items.prefix(5)).map {
                                                FeedRow(sectionID: section.id, item: $0)
                                            }) { row in
                                                CarouselCardView(
                                                    item: row.item,
                                                    onTap: {
                                                        quickViewItem = row.item
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }

                                // Interstitial Shopify product card after each section
                                if index < shopifyProducts.count {
                                    ShopifyProductCard(
                                        item: shopifyProducts[index],
                                        onTap: {
                                            quickViewItem = shopifyProducts[index]
                                        },
                                        onBuy: {
                                            if let url = shopifyProducts[index].shopUrl {
                                                safariItem = IdentifiableURL(url: url)
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        let delta = offset - lastScrollOffset
                        if abs(delta) > 10 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showHeader = delta > 0
                            }
                            lastScrollOffset = offset
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
        .overlay(alignment: .bottom) {
            persistentSearchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showAsk) {
            AskSheetView()
                .presentationDetents([.large])
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
                onDismiss: {
                    quickViewItem = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $seeAllSection) { section in
            SeeAllView(
                section: section,
                onProductTap: { item in
                    seeAllSection = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        quickViewItem = item
                    }
                },
                onShop: { url in
                    seeAllSection = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        safariItem = IdentifiableURL(url: url)
                    }
                }
            )
        }
        .task {
            await loadFeed()
        }
    }

    // MARK: - Header (hides on scroll)

    private var headerView: some View {
        HStack(alignment: .center) {
            Image("WirecutterLogo")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)

            Spacer()

            HStack(spacing: 8) {
                headerActionButton(icon: "person.fill")
                headerActionButton(icon: "bell.fill")
                headerActionButton(icon: "cart.fill")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Filter Row (always visible, horizontal scroll)

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.name) { filter in
                    filterPill(title: filter.name, icon: filter.icon, isSelected: selectedFilter == filter.name)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter.name
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func headerActionButton(icon: String) -> some View {
        Button { } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.label))
                .frame(width: 32, height: 32)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
    }

    private func filterPill(title: String, icon: String?, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.label))
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.label))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color(.systemGray5) : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    // MARK: - Persistent Search Bar

    private var persistentSearchBar: some View {
        Button {
            showAsk = true
        } label: {
            HStack(spacing: 6) {
                Image("NYTAIIcon")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color(hex: 0x5B69EB))
                Text("Search Wirecutter")
                    .font(.custom("NYTVFranklin-Medium", fixedSize: 14))
                    .foregroundStyle(Color(hex: 0x222222))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .overlay(
                Capsule()
                    .stroke(Color(hex: 0xDFDFDF), lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers (kept for compatibility)

    private func loadFeed() async {
        do {
            let result = try await APIClient.shared.fetchCommerceFeed()
            items = result.products
            shopifyProducts = result.shopifyProducts
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
    var onSeeAll: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.custom("NYTVFranklin-Bold", fixedSize: 22))
                .tracking(-0.5)
                .foregroundStyle(.black)
                .lineSpacing(2)
            Spacer()
            if let onSeeAll {
                Button {
                    onSeeAll()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(width: 24, height: 24)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Carousel Card (compact horizontal card)

private struct CarouselCardView: View {
    let item: CommerceItem
    let onTap: () -> Void

    private var bulletPoints: [String] {
        if let desc = item.productDescription, !desc.isEmpty {
            let lines = desc.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return Array(lines.prefix(2))
        }
        let name = item.productTitle.lowercased()
        if name.contains("mattress") || name.contains("pillow") || name.contains("blanket") {
            return ["Top pick for better sleep", "Premium comfort materials"]
        } else if name.contains("air purifier") || name.contains("airmega") {
            return ["True HEPA filtration", "Auto air quality mode"]
        } else if name.contains("headphone") || name.contains("earbuds") {
            return ["Wirecutter tested sound", "All-day comfort"]
        } else if name.contains("bag") || name.contains("carry-on") || name.contains("backpack") {
            return ["Durable travel materials", "Smart organization"]
        } else {
            return ["Wirecutter recommended", "Expert tested"]
        }
    }

    private var buyButtonText: String {
        switch (item.displayPrice, item.displayMerchant) {
        case let (price?, merchant?):
            return "\(price) from \(merchant)"
        case let (price?, nil):
            return price
        case let (nil, merchant?):
            return "From \(merchant)"
        default:
            return "View Details"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Image area
            ZStack(alignment: .topTrailing) {
                Color(hex: 0xF6F6F6)

                if let imageUrl = item.displayImageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(12)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(Color(.systemGray3))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                // Bookmark button
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "bookmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.black)
                    )
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
            .frame(width: 220, height: 180)

            // Info area
            VStack(alignment: .leading, spacing: 10) {
                // Subtitle (merchant)
                if let merchant = item.displayMerchant {
                    Text(merchant)
                        .font(.custom("NYTVFranklin-Medium", fixedSize: 12))
                        .foregroundStyle(Color(hex: 0x666666))
                        .lineSpacing(6)
                }

                // Title
                Text(item.productTitle)
                    .font(.custom("NYTVFranklin-Bold", fixedSize: 16))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)

                // Bullets
                if !bulletPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(bulletPoints, id: \.self) { bullet in
                            Text("• \(bullet)")
                                .font(.custom("NYTVFranklin-Medium", fixedSize: 12))
                                .foregroundStyle(.black)
                                .lineSpacing(4)
                        }
                    }
                }

                // Buy button
                Button {
                    onTap()
                } label: {
                    Text(buyButtonText)
                        .font(.custom("NYTVFranklin-Bold", fixedSize: 14))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(hex: 0xFCD843))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(width: 220)
        .overlay(Rectangle().stroke(Color(hex: 0xDFDFDF), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Full-Width Shopify Interstitial Card

private struct ShopifyProductCard: View {
    let item: CommerceItem
    let onTap: () -> Void
    let onBuy: () -> Void

    @State private var showApplePayConfirmation = false

    private var bulletPoints: [String] {
        if let desc = item.productDescription, !desc.isEmpty {
            let lines = desc.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return Array(lines.prefix(3))
        }
        return generateBullets()
    }

    private func generateBullets() -> [String] {
        let name = item.productTitle.lowercased()
        var bullets: [String] = []

        if name.contains("mattress") || name.contains("pillow") || name.contains("blanket") || name.contains("sheet") || name.contains("duvet") || name.contains("sleep") {
            bullets = ["Wirecutter's top pick for better sleep", "Premium materials for lasting comfort", "Risk-free trial period included"]
        } else if name.contains("air purifier") || name.contains("airmega") || name.contains("filter") {
            bullets = ["True HEPA filtration for cleaner air", "Auto mode adjusts to your room's air quality", "Quiet operation even on high settings"]
        } else if name.contains("headphone") || name.contains("earbuds") || name.contains("speaker") {
            bullets = ["Immersive sound tested by Wirecutter experts", "Comfortable for extended wear", "Long battery life for all-day use"]
        } else if name.contains("bag") || name.contains("carry-on") || name.contains("duffel") || name.contains("backpack") {
            bullets = ["Durable materials for frequent travel", "Thoughtful organization for essentials", "Fits airline carry-on requirements"]
        } else if name.contains("camera") || name.contains("bird") {
            bullets = ["Crystal-clear image quality", "Easy setup with guided app", "Smart notifications and recording"]
        } else {
            bullets = ["Wirecutter tested and recommended", "Built to last with quality materials", "Handpicked by our experts"]
        }

        let titleWords = item.productTitle.components(separatedBy: " ").count
        return titleWords > 5 ? Array(bullets.prefix(2)) : Array(bullets.prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Image area
            ZStack(alignment: .topTrailing) {
                Color(hex: 0xF6F6F6)

                if let imageUrl = item.displayImageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(16)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(Color(.systemGray3))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                // Bookmark button
                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "bookmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.black)
                    )
                    .padding(.top, 13)
                    .padding(.trailing, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 312)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            // Info area
            VStack(alignment: .leading, spacing: 20) {
                // Info group
                VStack(alignment: .leading, spacing: 12) {
                    // Subtitle (merchant)
                    if let merchant = item.displayMerchant {
                        Text(merchant)
                            .font(.custom("NYTVFranklin-Medium", fixedSize: 12))
                            .foregroundStyle(Color(hex: 0x666666))
                            .lineSpacing(6)
                    }

                    // Headline (product title)
                    Text(item.productTitle)
                        .font(.custom("NYTVFranklin-Bold", fixedSize: 20))
                        .foregroundStyle(.black)
                        .lineSpacing(6)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    // Bullet points
                    if !bulletPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(bulletPoints, id: \.self) { bullet in
                                Text("• \(bullet)")
                                    .font(.custom("NYTVFranklin-Medium", fixedSize: 14))
                                    .foregroundStyle(.black)
                                    .lineSpacing(6)
                            }
                        }
                    }
                }

                // Apple Pay button
                Button {
                    simulateApplePay()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Pay")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.black)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .overlay(Rectangle().stroke(Color(hex: 0xDFDFDF), lineWidth: 1))
        .overlay {
            if showApplePayConfirmation {
                applePayOverlay
            }
        }
    }

    private func simulateApplePay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showApplePayConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showApplePayConfirmation = false
            }
        }
    }

    private var applePayOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("Order Confirmed")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text(item.productTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                if let price = item.displayPrice {
                    Text(price)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - See All View (full list for a section)

private struct SeeAllView: View {
    let section: CommerceCategorySection
    let onProductTap: (CommerceItem) -> Void
    let onShop: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(section.items) { item in
                        SeeAllRowView(item: item, onTap: {
                            onProductTap(item)
                        }, onShop: {
                            if let url = item.shopUrl {
                                onShop(url)
                            }
                        })
                    }
                }
                .padding()
            }
            .navigationTitle(section.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SeeAllRowView: View {
    let item: CommerceItem
    let onTap: () -> Void
    let onShop: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                if let imageUrl = item.displayImageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                        case .failure, .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                        @unknown default:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let ribbon = item.ribbon {
                        Text(ribbon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    Text(item.productTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(.label))
                        .lineLimit(2)
                    if let price = item.displayPrice {
                        Text(price)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(.label))
                    }
                    if let merchant = item.displayMerchant {
                        Text("at \(merchant)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if item.shopUrl != nil {
                    Button {
                        onShop()
                    } label: {
                        Image(systemName: "cart")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ask AI Sheet

private struct AskSheetView: View {
    @State private var query = ""
    @State private var isLoading = false
    @State private var response: String?
    @Environment(\.dismiss) private var dismiss

    private let suggestedPrompts = [
        "Gift ideas for a baby shower",
        "How do I organize a small space?",
        "What kind of rug should I get?",
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [Color(hex: 0xE8EAFF), Color.white],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                if isLoading {
                    loadingView
                } else if let response {
                    responseView(response)
                } else {
                    promptContent
                }

                searchBar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            closeButton
        }
    }

    // MARK: - Initial prompt state (bottom-aligned)

    private var promptContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Wirecutter Finder")
                .font(.custom("NYTKarnak-Medium", fixedSize: 32))
                .foregroundStyle(Color.black)

            VStack(alignment: .leading, spacing: 24) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button {
                        query = prompt
                        performAsk()
                    } label: {
                        HStack(spacing: 8) {
                            Image("NYTAIIcon")
                                .resizable()
                                .frame(width: 21, height: 20)
                                .foregroundStyle(Color(hex: 0x5B69EB))
                            Text(prompt)
                                .font(.custom("NYTVFranklin-Medium", fixedSize: 16))
                                .foregroundStyle(Color(hex: 0x191919))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Color(hex: 0xF0F1FF))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Loading state

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Finding recommendations…")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    // MARK: - Response state

    private func responseView(_ text: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image("NYTAIIcon")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color(hex: 0x5B69EB))
                    Text("Wirecutter Finder")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(text)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .lineSpacing(8)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xF8F7FF))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Search bar (pinned to bottom)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image("NYTAIIcon")
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color(hex: 0x5B69EB))
            TextField("I need something with SPF for a beach trip.", text: $query)
                .textFieldStyle(.plain)
                .font(.custom("NYTVFranklin-Medium", fixedSize: 14))
                .foregroundStyle(Color(hex: 0x222222))
                .submitLabel(.send)
                .onSubmit { performAsk() }
        }
        .padding(.horizontal, 14)
        .frame(height: 45)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.top, 24)
    }

    // MARK: - Close button (top-right)

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.label))
                .frame(width: 32, height: 32)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.top, 20)
        .padding(.trailing, 20)
    }

    // MARK: - Ask action

    private func performAsk() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        response = nil
        let userQuery = query

        Task {
            do {
                let result = try await GeminiClient.shared.ask(query: userQuery)
                response = result
            } catch {
                response = "Sorry, I couldn't get a response right now. \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}


// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
