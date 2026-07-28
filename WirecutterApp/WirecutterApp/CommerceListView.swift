import SwiftUI

struct CommerceListView: View {
    var people: [PersonProfile] = PersonProfileStore.prototypes
    var onSelectPerson: (PersonProfile) -> Void = { _ in }
    var onSearch: () -> Void = {}

    @State private var items: [CommerceItem] = []
    @State private var shopifyProducts: [CommerceItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?
    @State private var quickViewItem: CommerceItem?
    @State private var plusVisible = false
    @State private var separatorVisible = false
    @State private var visibleAvatarNames: Set<String> = []
    @State private var didPlayPeopleEntrance = false
    @State private var showPeopleRow = true
    @State private var headerHeight: CGFloat = 56
    @State private var peopleRowMeasuredHeight: CGFloat = 78

    private var shuffledProducts: [CommerceItem] {
        var all = items + shopifyProducts
        var rng = SeededRandomNumberGenerator(seed: UInt64(all.count))
        all.shuffle(using: &rng)
        return all
    }

    /// Clears the floating tab capsule when scrolled to the end (safe area is ignored
    /// so the feed can pass underneath the bar).
    private let tabBarContentInset: CGFloat = 100

    /// Visible (possibly collapsed) chrome height — drives the overlay clip only.
    private var homeChromeHeight: CGFloat {
        showPeopleRow ? expandedHomeChromeHeight : collapsedHomeChromeHeight
    }

    private var collapsedHomeChromeHeight: CGFloat { max(headerHeight, 1) }

    /// Full chrome height used for feed top padding. Stays constant during snap so the
    /// feed only moves from user scrolling, not from the nav collapse animation.
    private var expandedHomeChromeHeight: CGFloat {
        collapsedHomeChromeHeight + max(peopleRowMeasuredHeight, 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .padding(.top, expandedHomeChromeHeight)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Under-chrome spacer stays solid white (matches nav). The
                            // white → feed-gray fade runs only across the visible specialty
                            // row so it isn't diluted under the overlay.
                            VStack(alignment: .leading, spacing: 0) {
                                PageChrome.feedEntranceStart
                                    .frame(height: expandedHomeChromeHeight)
                                    .frame(maxWidth: .infinity)

                                upcomingRow
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background { FeedEntranceGradient() }
                            }

                            if isLoading {
                                ghostFeedContent
                            } else if shuffledProducts.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tray")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("No products found")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                ForEach(Array(shuffledProducts.enumerated()), id: \.element.id) { index, item in
                                    ProductCardView(
                                        item: item,
                                        onTap: { quickViewItem = item },
                                        showAddToList: index % 5 == 4
                                    )
                                    .padding(.horizontal, 20)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                        }
                        .padding(.bottom, tabBarContentInset)
                    }
                    .modifier(FeedScrollPeopleChromeModifier(showPeopleRow: $showPeopleRow))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PageChrome.feedBackground)

            // Search + avatars overlay the feed; height collapse clips the avatar row.
            homeChrome
                .frame(height: homeChromeHeight, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .clipped()
                .background(Color(.systemBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PageChrome.feedBackground)
        // Let the feed extend under the floating tab bar; bottom inset keeps end content clear.
        .ignoresSafeArea(.container, edges: .bottom)
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
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .task {
            await loadFeed()
        }
    }

    // MARK: - Home chrome (search + avatars as one unit)

    private var homeChrome: some View {
        VStack(spacing: 0) {
            headerView
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: HomeHeaderHeightKey.self,
                            value: geo.size.height
                        )
                    }
                }

            peopleRow
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: HomePeopleRowHeightKey.self,
                            value: geo.size.height
                        )
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onPreferenceChange(HomeHeaderHeightKey.self) { height in
            if height > 0 { headerHeight = height }
        }
        .onPreferenceChange(HomePeopleRowHeightKey.self) { height in
            if height > 0 { peopleRowMeasuredHeight = height }
        }
    }

    // MARK: - Header (search + actions)

    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            persistentSearchBar

            HStack(spacing: 16) {
                headerActionButton(icon: "bell")
                headerActionButton(icon: "cart")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - People Row (avatar placeholders)

    private var peopleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                addPersonButton
                    .opacity(plusVisible ? 1 : 0)

                Color(hex: 0xEEEEEE)
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, 12)
                    .opacity(separatorVisible ? 1 : 0)

                HStack(alignment: .top, spacing: 6) {
                    ForEach(people) { person in
                        personAvatar(person)
                            .opacity(visibleAvatarNames.contains(person.name) ? 1 : 0)
                            .offset(y: visibleAvatarNames.contains(person.name) ? 0 : 10)
                            .onTapGesture {
                                onSelectPerson(person)
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            // Room for the upcoming-event badge (extends past the avatar bounds).
            .padding(.top, 6)
            .padding(.trailing, 4)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .onAppear {
            guard !didPlayPeopleEntrance else { return }
            didPlayPeopleEntrance = true
            Task { @MainActor in
                await playPeopleEntrance()
            }
        }
    }

    private func playPeopleEntrance() async {
        let duration: TimeInterval = 0.4
        let stagger: TimeInterval = 0.1
        let pauseBeforeAvatars: TimeInterval = 0.5

        withAnimation(.easeOut(duration: duration)) {
            plusVisible = true
        }

        try? await Task.sleep(for: .seconds(stagger))

        withAnimation(.easeOut(duration: duration)) {
            separatorVisible = true
        }

        // Wait for the separator fade to finish, then pause before avatars.
        try? await Task.sleep(for: .seconds(duration + pauseBeforeAvatars))

        for person in people {
            withAnimation(.easeOut(duration: duration)) {
                visibleAvatarNames.insert(person.name)
            }
            try? await Task.sleep(for: .seconds(stagger))
        }
    }

    private var addPersonButton: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Reserve label height so avatars align with the add control.
            Text(" ")
                .font(.nytFranklin(.medium, size: 12))
                .hidden()
        }
        .frame(width: 52)
    }

    private func personAvatar(_ person: PersonProfile) -> some View {
        VStack(spacing: 6) {
            Image(AvatarStyle.assetName(for: person.name))
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if person.hasUpcomingEvent(within: 21) {
                        Circle()
                            .fill(Color(hex: 0xAE0115))
                            .frame(width: 10, height: 10)
                            .overlay {
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 1)
                            }
                            .offset(x: 2, y: -2)
                            .accessibilityLabel("Upcoming event")
                    }
                }
                .accessibilityLabel("\(person.name) avatar")

            Text(person.name)
                .font(.nytFranklin(.medium, size: 12))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 52)
        .contentShape(Rectangle())
    }

    // MARK: - Upcoming Row

    private var upcomingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.nytFranklin(.bold, size: 18))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        upcomingCard
                    }
                }
                // Extra vertical padding so card shadows aren't clipped.
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 10)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var upcomingCard: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(.systemGray6))
            .frame(width: 250, height: 144)
            .background {
                // Approximates box-shadow: 0 2px 5px 4px rgba(36,50,66,0.1)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 36 / 255, green: 50 / 255, blue: 66 / 255).opacity(0.1))
                    .blur(radius: 5)
                    .padding(-4)
                    .offset(y: 2)
            }
    }

    /// Matches bottom tab icon size (24×24), outlined (~2pt stroke via weight).
    private func headerActionButton(icon: String) -> some View {
        Button { } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color(.label))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Persistent Search Bar

    private var persistentSearchBar: some View {
        Button {
            onSearch()
        } label: {
            HStack(spacing: 6) {
                Image("NYTAIIcon")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color(hex: 0x5B69EB))
                Text("Search Wirecutter")
                    .font(.nytFranklin(.medium, size: 14))
                    .foregroundStyle(Color(hex: 0x979797))
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color(.systemBackground))
            .overlay(
                Capsule()
                    .stroke(Color(hex: 0xCCCCCC), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ghost Feed

    private var ghostFeedContent: some View {
        Group {
            ForEach(0..<4, id: \.self) { index in
                GhostProductCard()
                    .padding(.horizontal, 20)
                    .opacity(1.0 - Double(index) * 0.12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading products")
    }

    // MARK: - Load Feed

    private func loadFeed() async {
        do {
            let result = try await APIClient.shared.fetchCommerceFeed()
            withAnimation(.easeOut(duration: 0.35)) {
                items = result.products
                shopifyProducts = result.shopifyProducts
                isLoading = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Ghost / skeleton card

struct GhostProductCard: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            // Image ghost
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(hex: 0xEEEEEE))
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color(hex: 0xE4E4E4))
                        .frame(width: 24, height: 24)
                        .padding(.top, 13)
                        .padding(.trailing, 12)
                }

            // Info ghost
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    ghostBar(width: 72, height: 10)
                    ghostBar(width: nil, height: 18)
                    ghostBar(width: 220, height: 18)
                    VStack(alignment: .leading, spacing: 8) {
                        ghostBar(width: nil, height: 12)
                        ghostBar(width: 180, height: 12)
                        ghostBar(width: 140, height: 12)
                    }
                    .padding(.top, 4)
                }

                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: 0xE6E6E6))
                        .frame(height: 39)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: 0xEDEDED))
                        .frame(height: 39)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .opacity(pulse ? 0.55 : 1.0)
        .animation(
            .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
            value: pulse
        )
        .onAppear { pulse = true }
        .allowsHitTesting(false)
    }

    private func ghostBar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: 0xE8E8E8))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

// MARK: - Product Card (unified full-width card)

struct ProductCardView: View {
    let item: CommerceItem
    let onTap: () -> Void
    var showAddToList: Bool = false
    var isSaved: Bool = false
    var onBookmarkTap: (() -> Void)? = nil

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
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(12)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(Color(.systemGray3))
                        case .empty:
                            Color(hex: 0xEEEEEE)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: 0xE4E4E4))
                                        .frame(width: 64, height: 64)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                bookmarkButton
                    .padding(.top, 13)
                    .padding(.trailing, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()
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
                        .font(.nytFranklin(.medium, size: 12))
                        .foregroundStyle(Color(hex: 0x666666))

                    Text(item.productTitle)
                        .font(.nytFranklin(.bold, size: 20))
                        .foregroundStyle(.black)
                        .lineSpacing(6)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if hasBullets {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(bulletPoints, id: \.self) { bullet in
                                Text("• \(bullet)")
                                    .font(.nytFranklin(.medium, size: 14))
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
                                .font(.nytFranklin(.bold, size: 14))
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

    @ViewBuilder
    private var bookmarkButton: some View {
        let icon = Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.black)

        let badge = Circle()
            .fill(.white)
            .frame(width: 24, height: 24)
            .overlay(icon)

        if let onBookmarkTap {
            Button {
                onBookmarkTap()
            } label: {
                badge
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Remove from saved" : "Save")
        } else {
            badge
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Ask AI Sheet

struct AskSheetView: View {
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
                .font(.nytFranklin(.bold, size: 32))
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
                                .font(.nytFranklin(.medium, size: 16))
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
                .font(.nytFranklin(size: 15))
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
                        .font(.nytFranklin(size: 14, weight: .semibold))
                }

                Text(text)
                    .font(.nytFranklin(size: 16, weight: .regular))
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
                .font(.nytFranklin(.medium, size: 14))
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



// MARK: - Home chrome measurement

private struct HomeHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HomePeopleRowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Feed scroll ↔ people chrome

/// Collapses the avatar extension of home chrome while scrolling down; restores on scroll up.
private struct FeedScrollPeopleChromeModifier: ViewModifier {
    @Binding var showPeopleRow: Bool
    @State private var lastOffsetY: CGFloat = 0
    @State private var accumulatedDelta: CGFloat = 0
    @State private var lockScrollHandlingUntil: Date = .distantPast

    private let topRevealThreshold: CGFloat = 20
    private let hideAfterScrollDown: CGFloat = 36
    private let showAfterScrollUp: CGFloat = 24
    private let lockDuration: TimeInterval = 0.5

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newOffsetY in
                    handleScroll(offsetY: newOffsetY)
                }
        } else {
            content
        }
    }

    private func handleScroll(offsetY: CGFloat) {
        let delta = offsetY - lastOffsetY
        lastOffsetY = offsetY

        // contentOffset.y is ~0 at top and increases as the user scrolls down.
        if offsetY < topRevealThreshold {
            accumulatedDelta = 0
            setPeopleRowVisible(true)
            return
        }

        guard Date() >= lockScrollHandlingUntil else { return }
        guard abs(delta) > 0.5 else { return }

        // Accumulate movement in the current direction; reset on reversal.
        if accumulatedDelta == 0 || (accumulatedDelta > 0) == (delta > 0) {
            accumulatedDelta += delta
        } else {
            accumulatedDelta = delta
        }

        if accumulatedDelta >= hideAfterScrollDown {
            accumulatedDelta = 0
            setPeopleRowVisible(false)
        } else if accumulatedDelta <= -showAfterScrollUp {
            accumulatedDelta = 0
            setPeopleRowVisible(true)
        }
    }

    private func setPeopleRowVisible(_ visible: Bool) {
        guard showPeopleRow != visible else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.66, blendDuration: 0.1)) {
            showPeopleRow = visible
        }
        lockScrollHandlingUntil = Date().addingTimeInterval(lockDuration)
    }
}

// MARK: - Identifiable URL wrapper for .sheet(item:)

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Seeded RNG for stable shuffle

struct SeededRandomNumberGenerator: RandomNumberGenerator {
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
