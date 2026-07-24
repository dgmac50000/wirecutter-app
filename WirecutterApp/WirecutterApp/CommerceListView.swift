import SwiftUI

struct CommerceListView: View {
    @State private var items: [CommerceItem] = []
    @State private var shopifyProducts: [CommerceItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?
    @State private var quickViewItem: CommerceItem?
    @State private var selectedFilter: String = "For you"
    @State private var showHeader = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showAsk = false

    private let filters: [(name: String, icon: String?)] = [
        ("For you", nil),
        ("My Lists", nil),
        ("Prime Day", "tag.fill"),
        ("Gifts", nil),
        ("Sleep", nil),
        ("Home", nil),
    ]

    private var shuffledProducts: [CommerceItem] {
        var all = items + shopifyProducts
        var rng = SeededRandomNumberGenerator(seed: UInt64(all.count))
        all.shuffle(using: &rng)
        return all
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
                } else if shuffledProducts.isEmpty {
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
                        LazyVStack(spacing: 16) {
                            ForEach(Array(shuffledProducts.enumerated()), id: \.element.id) { index, item in
                                ProductCardView(
                                    item: item,
                                    onTap: { quickViewItem = item },
                                    showAddToList: index % 5 == 4
                                )
                                .padding(.horizontal, 20)
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

    // MARK: - Load Feed

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

// MARK: - Product Card (unified full-width card)

private struct ProductCardView: View {
    let item: CommerceItem
    let onTap: () -> Void
    let showAddToList: Bool

    private var hasBullets: Bool { !bulletPoints.isEmpty }

    private var bulletPoints: [String] {
        if let desc = item.productDescription, !desc.isEmpty {
            let lines = desc.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return Array(lines.prefix(3))
        }
        if item.isShopifyProduct == true {
            return generateBullets()
        }
        return []
    }

    private func generateBullets() -> [String] {
        let name = item.productTitle.lowercased()
        if name.contains("mattress") || name.contains("pillow") || name.contains("blanket") || name.contains("sheet") || name.contains("duvet") || name.contains("sleep") {
            return ["Wirecutter's top pick for better sleep", "Premium materials for lasting comfort", "Risk-free trial period included"]
        } else if name.contains("air purifier") || name.contains("airmega") || name.contains("filter") {
            return ["True HEPA filtration for cleaner air", "Auto mode adjusts to air quality", "Quiet operation even on high settings"]
        } else if name.contains("headphone") || name.contains("earbuds") || name.contains("speaker") {
            return ["Immersive sound tested by experts", "Comfortable for extended wear", "Long battery life for all-day use"]
        } else if name.contains("bag") || name.contains("carry-on") || name.contains("duffel") || name.contains("backpack") {
            return ["Durable materials for frequent travel", "Thoughtful organization for essentials", "Fits airline carry-on requirements"]
        } else if name.contains("camera") || name.contains("bird") {
            return ["Crystal-clear image quality", "Easy setup with guided app", "Smart notifications and recording"]
        } else {
            return ["Wirecutter tested and recommended", "Built to last with quality materials", "Handpicked by our experts"]
        }
    }

    private var buyButtons: [(text: String, url: URL?)] {
        if let sources = item.sources, !sources.isEmpty {
            return Array(sources.prefix(2)).map { source in
                let price = source.dealPriceFormatted ?? source.priceFormatted ?? ""
                let merchant = source.merchantName
                let text = price.isEmpty ? "From \(merchant)" : "\(price) from \(merchant)"
                return (text: text, url: source.dealAffiliateUrl ?? source.affiliateUrl)
            }
        }
        let text: String
        switch (item.displayPrice, item.displayMerchant) {
        case let (price?, merchant?):
            text = "\(price) from \(merchant)"
        case let (price?, nil):
            text = price
        case let (nil, merchant?):
            text = "From \(merchant)"
        default:
            text = "View Details"
        }
        return [(text: text, url: item.shopUrl)]
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
                                .font(.largeTitle)
                                .foregroundStyle(Color(.systemGray3))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

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
            .frame(height: 280)
            .overlay(alignment: .bottom) {
                HStack(spacing: 4) {
                    Circle().fill(Color.black).frame(width: 6, height: 6)
                    Circle().fill(Color(hex: 0xCCCCCC)).frame(width: 4, height: 4)
                    Circle().fill(Color(hex: 0xCCCCCC)).frame(width: 4, height: 4)
                }
                .padding(.bottom, 12)
            }

            // Info section
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.displayMerchant ?? item.productTitle)
                        .font(.custom("NYTVFranklin-Medium", fixedSize: 12))
                        .foregroundStyle(Color(hex: 0x666666))

                    Text(item.productTitle)
                        .font(.custom("NYTVFranklin-Bold", fixedSize: 20))
                        .foregroundStyle(.black)
                        .lineSpacing(6)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if hasBullets {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(bulletPoints, id: \.self) { bullet in
                                Text("• \(bullet)")
                                    .font(.custom("NYTVFranklin-Medium", fixedSize: 14))
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                }

                VStack(spacing: 8) {
                    ForEach(Array(buyButtons.enumerated()), id: \.offset) { _, button in
                        Button {
                            onTap()
                        } label: {
                            Text(button.text)
                                .font(.custom("NYTVFranklin-Bold", fixedSize: 14))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 39)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, showAddToList ? 0 : 12)

            if showAddToList {
                HStack(spacing: 8) {
                    Image("NYTAIIcon")
                        .resizable()
                        .frame(width: 21, height: 20)
                        .foregroundStyle(Color(hex: 0x5B69EB))
                    Text("Add to my \"\(item.resolvedCategoryName)\" list")
                        .font(.custom("NYTVFranklin-Medium", fixedSize: 16))
                        .foregroundStyle(Color(hex: 0x191919))
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color(hex: 0xF0F1FF))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
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

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Seeded RNG for stable shuffle

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

#Preview {
    CommerceListView()
}
