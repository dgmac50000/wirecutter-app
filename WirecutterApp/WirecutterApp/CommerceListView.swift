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
                                VStack(alignment: .leading, spacing: 12) {
                                    CategorySectionHeader(
                                        title: section.name,
                                        count: section.items.count,
                                        onSeeAll: {
                                            seeAllSection = section
                                        }
                                    )

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 14) {
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
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0x5B69EB))
                Text("Search Wirecutter")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x727272))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .overlay(
                Capsule()
                    .stroke(Color(hex: 0xC7C7C7), lineWidth: 1)
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
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Spacer()
            if let onSeeAll {
                Button {
                    onSeeAll()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray5))
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

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    if let imageUrl = item.displayImageUrl {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 160, height: 160)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 160, height: 160)
                            case .empty:
                                ProgressView()
                                    .frame(width: 160, height: 160)
                            @unknown default:
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 160, height: 160)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Shopify products no longer appear in carousels;
                    // they are shown as full-width interstitial cards instead.
                }

                if let ribbon = item.ribbon {
                    Text(ribbon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ribbonColor(for: ribbon))
                        .clipShape(Capsule())
                }

                Text(item.productTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let price = item.displayPrice {
                    Text(price)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(.label))
                }

                if let merchant = item.displayMerchant {
                    Text("at \(merchant)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
    }

    private func ribbonColor(for ribbon: String) -> Color {
        switch ribbon {
        case "Top Pick": return .red
        case "Budget Pick": return .green
        case "Upgrade Pick": return .blue
        case "Also Great": return .orange
        default: return .gray
        }
    }
}

// MARK: - Full-Width Shopify Interstitial Card

private struct ShopifyProductCard: View {
    let item: CommerceItem
    let onTap: () -> Void
    let onBuy: () -> Void

    @State private var showApplePayConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "Wirecutter Store" badge
            HStack(spacing: 5) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Wirecutter Store")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black)
            .clipShape(Capsule())
            .padding(.bottom, 10)

            // Full-width product image
            Button {
                onTap()
            } label: {
                if let imageUrl = item.displayImageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                        @unknown default:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .buttonStyle(.plain)

            // Product title
            Button {
                onTap()
            } label: {
                Text(item.productTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            // Price
            if let price = item.displayPrice {
                Text(price)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .padding(.top, 4)
            }

            // Apple Pay / Buy button
            HStack(spacing: 10) {
                Button {
                    simulateApplePay()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Pay")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Button {
                    onBuy()
                } label: {
                    Text("Buy Now")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
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
                .clipShape(RoundedRectangle(cornerRadius: 16))

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
            // Radial gradient background
            RadialGradient(
                colors: [Color(hex: 0xE8EAFF), Color.white],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Main content — bottom-aligned
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Wirecutter Finder")
                            .font(.custom("NYTKarnak-Medium", size: 32))
                            .foregroundStyle(Color(hex: 0x191919))

                        if response == nil && !isLoading {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(suggestedPrompts, id: \.self) { prompt in
                                    Button {
                                        query = prompt
                                        performAsk()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color(hex: 0x5B69EB))
                                            Text(prompt)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(Color(hex: 0x191919))
                                        }
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 10)
                                        .background(Color(hex: 0xF0F1FF))
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                    }
                                }
                            }
                        }

                        if isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Finding recommendations…")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 20)
                        } else if let response {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: 0x5B69EB))
                                    Text("Wirecutter Finder")
                                        .font(.system(size: 14, weight: .semibold))
                                }

                                Text(response)
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                                    .lineSpacing(8)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: 0xF8F7FF))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Bottom search bar
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: 0x5B69EB))
                        TextField("I need something with SPF for a beach trip.", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .submitLabel(.send)
                            .onSubmit { performAsk() }
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: 0x5B69EB).opacity(0.3), lineWidth: 1)
                    )

                    Button {
                        performAsk()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(hex: 0x5B69EB))
                    }
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Close button — top-right overlay
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x191919))
                    .frame(width: 32, height: 32)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }

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
