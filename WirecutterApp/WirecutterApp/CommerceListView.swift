import SwiftUI

struct CommerceListView: View {
    private static let pageSize = 8

    @State private var items: [CommerceItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?
    @State private var quickViewItem: CommerceItem?
    @State private var feedMode: FeedMode = .forYou
    @State private var visibleCountBySection: [String: Int] = [:]
    @State private var selectedFilter: String = "For you"
    @State private var showHeader = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showSearch = false
    @State private var showAsk = false

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
                        LazyVStack(alignment: .leading, spacing: 28, pinnedViews: [.sectionHeaders]) {
                            ForEach(sections) { section in
                                let visible = visibleItems(for: section)
                                let remaining = section.items.count - visible.count

                                Section {
                                    if let heroURL = section.heroImageURL {
                                        CategoryHeroImage(url: heroURL)
                                    }

                                    ForEach(visible.map {
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
        .sheet(isPresented: $showSearch) {
            SearchSheetView()
                .presentationDetents([.large])
        }
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
        HStack {
            Button {
                showSearch = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: 0x727272))
                    Text("Search Wirecutter")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: 0x727272))
                }
            }

            Spacer()

            Button {
                showAsk = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: 0x5B69EB))
                    Text("Ask")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: 0x5A5A5A))
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Capsule()
                .stroke(Color(hex: 0xC7C7C7), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Section pagination

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

// MARK: - Search Sheet

private struct SearchSheetView: View {
    @State private var query = ""
    @State private var hasSearched = false
    @Environment(\.dismiss) private var dismiss

    private let fakeResults = [
        "Best Noise-Cancelling Headphones",
        "Best Wireless Earbuds",
        "Best Portable Bluetooth Speakers",
        "Best Soundbars",
        "Best Turntables for Beginners",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if hasSearched {
                    List(fakeResults.filter {
                        query.isEmpty ? true : $0.lowercased().contains(query.lowercased())
                    }, id: \.self) { result in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                            Text(result)
                                .font(.system(size: 15))
                        }
                    }
                    .listStyle(.plain)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("Search for products, reviews, and recommendations")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search Wirecutter")
            .onChange(of: query) {
                hasSearched = !query.isEmpty
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("Wirecutter Finder")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                        Text("BETA")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.darkGray))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 16)

                    if response == nil && !isLoading {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(suggestedPrompts, id: \.self) { prompt in
                                    Button {
                                        query = prompt
                                        performAsk()
                                    } label: {
                                        Text(prompt)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color(.label))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color(hex: 0xF0EEFF))
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color(hex: 0xDDD8FF), lineWidth: 1)
                                            )
                                    }
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

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    TextField("Show me the best…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .submitLabel(.send)
                        .onSubmit { performAsk() }

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
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
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
