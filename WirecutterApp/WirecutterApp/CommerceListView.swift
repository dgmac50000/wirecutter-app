import SwiftUI
import UIKit

/// Equal-width price filters for the home feed.
enum FeedPriceFilter: String, CaseIterable, Identifiable {
    case under50
    case fiftyToHundred
    case overHundred

    var id: String { rawValue }

    var title: String {
        switch self {
        case .under50: return "Under $50"
        case .fiftyToHundred: return "$50 - $100"
        case .overHundred: return "$100+"
        }
    }
}

struct CommerceListView: View {
    var people: [PersonProfile] = PersonProfileStore.prototypes
    var onSelectPerson: (PersonProfile) -> Void = { _ in }
    var onSelectEditorial: (WatchlistEditorialMoment) -> Void = { _ in }
    var onViewAllWatchlist: () -> Void = {}
    var onSearch: () -> Void = {}

    @State private var items: [CommerceItem] = []
    @State private var shopifyProducts: [CommerceItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?
    @State private var quickViewItem: CommerceItem?
    @State private var plusVisible = false
    @State private var separatorVisible = false
    @State private var visibleWatchlistIDs: Set<String> = []
    /// Watchlist items opened this session — shown at 70% opacity.
    @State private var visitedWatchlistIDs: Set<String> = WatchlistInteractionStore.sessionVisitedIDs
    @State private var didPlayPeopleEntrance = false
    @State private var showPeopleRow = true
    @State private var headerHeight: CGFloat = 56
    @State private var peopleRowMeasuredHeight: CGFloat = 78
    @State private var selectedFeedFilter: FeedPriceFilter? = nil
    @State private var buyNowOnly = false
    @State private var buyNowClusterWidth: CGFloat = 130
    /// UIKit bridge so filter swaps can restore contentOffset after LazyVStack relayout.
    @State private var feedScrollBridge = FeedScrollViewBridge()
    /// Suppresses avatar-row show/hide while filter restores are bouncing the offset.
    @State private var feedChromeScrollLocked = false
    @State private var scrollOffsetY: CGFloat = 0
    @State private var upcomingSectionHeight: CGFloat = 180
    /// Cached Upcoming cards — rebuilt when the feed loads (not on every scroll frame).
    @State private var upcomingEventCards: [UpcomingEventCard] = []
    /// Sequenced home entrance after the people-row animation.
    @State private var upcomingRevealed = false
    @State private var filtersRevealed = false
    @State private var visibleFeedProductIDs: Set<Int> = []
    @State private var feedRevealComplete = false
    @State private var didStartContentEntrance = false
    /// True while feed + gift-guide heroes + first images are loading.
    @State private var isPreparingHome = true
    /// Multi-profile Upcoming card → choose who you're shopping for.
    @State private var profilePickerCard: UpcomingEventCard?
    /// Dynamically ordered watchlist (editorial + gift profiles + View all).
    @State private var watchlistEntries: [WatchlistEntry] = WatchlistStore.placeholderEntries
    /// Cached editorials so in-session reordering does not require a network round-trip.
    @State private var watchlistEditorials: [WatchlistEditorialMoment] = []
    @Environment(\.scenePhase) private var scenePhase

    /// Matches the plus↔avatars hairline in the watchlist row.
    private let homeChromeBorderColor = Color(hex: 0xEEEEEE)

    private let feedFilters = FeedPriceFilter.allCases
    private let feedFilterLazySpacing: CGFloat = 16
    private let feedFilterPillSpacing: CGFloat = 8
    /// Fade after the Buy-from-NYT separator; pills begin at the end of this zone.
    private let buyFromNYTFadeWidth: CGFloat = 12
    /// Minimum distance from the top of the screen to the sticky filter bar.
    private let stickyFilterMinTopInset: CGFloat = 16
    /// Stick slightly before the row reaches its resting pin position.
    private let stickyFilterLeadDistance: CGFloat = 48

    private var shuffledProducts: [CommerceItem] {
        var all = items + shopifyProducts
        var rng = SeededRandomNumberGenerator(seed: UInt64(all.count))
        all.shuffle(using: &rng)
        return all
    }

    private var filteredProducts: [CommerceItem] {
        var products = shuffledProducts
        if buyNowOnly {
            products = products.filter(\.isWirecutterStoreProduct)
        }
        if let selectedFeedFilter {
            products = products.filter { matchesFeedFilter($0, selectedFeedFilter) }
        }
        return products
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

    /// Pin under the live chrome (search + profiles when visible) so the sticky
    /// pills travel with the profiles row as it expands and collapses.
    private var stickyFilterTopInset: CGFloat {
        max(homeChromeHeight, stickyFilterMinTopInset)
    }

    /// Content Y where the inline filter row begins.
    private var filterRowContentTop: CGFloat {
        expandedHomeChromeHeight + upcomingSectionHeight + feedFilterLazySpacing
    }

    private var areFiltersStuck: Bool {
        // Compare against the stable pin (search bar), and trip a bit early.
        scrollOffsetY >= filterRowContentTop - stickyFilterTopInset - stickyFilterLeadDistance
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
                        LazyVStack(spacing: feedFilterLazySpacing) {
                            // Under-chrome spacer stays solid white (matches nav). The
                            // white → feed-gray fade runs only across the visible specialty
                            // row so it isn't diluted under the overlay.
                            VStack(alignment: .leading, spacing: 0) {
                                PageChrome.feedEntranceStart
                                    .frame(height: expandedHomeChromeHeight)
                                    .frame(maxWidth: .infinity)

                                upcomingRow
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .opacity(upcomingRevealed ? 1 : 0)
                                    .offset(y: upcomingRevealed ? 0 : 10)
                                    .allowsHitTesting(upcomingRevealed)
                                    .accessibilityHidden(!upcomingRevealed)
                                    .background { FeedEntranceGradient() }
                                    .background {
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: UpcomingSectionHeightKey.self,
                                                value: geo.size.height
                                            )
                                        }
                                    }
                            }

                            feedFilterRow
                                .opacity(filtersRevealed && !areFiltersStuck ? 1 : 0)
                                .offset(y: filtersRevealed ? 0 : 10)
                                .allowsHitTesting(filtersRevealed && !areFiltersStuck)
                                .accessibilityHidden(!filtersRevealed || areFiltersStuck)

                            if isLoading {
                                ghostFeedContent
                                    .opacity(0)
                                    .accessibilityHidden(true)
                            } else if filteredProducts.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tray")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text(
                                        selectedFeedFilter.map { "No products in \($0.title)" }
                                            ?? "No products found"
                                    )
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                                .opacity(feedRevealComplete ? 1 : 0)
                            } else {
                                ForEach(filteredProducts) { item in
                                    let revealed = feedRevealComplete || visibleFeedProductIDs.contains(item.id)
                                    ProductCardView(item: item, onTap: { quickViewItem = item })
                                        .padding(.horizontal, 20)
                                        .opacity(revealed ? 1 : 0)
                                        .offset(y: revealed ? 0 : 10)
                                        .allowsHitTesting(revealed)
                                }
                            }
                        }
                        .padding(.bottom, tabBarContentInset)
                        .onPreferenceChange(UpcomingSectionHeightKey.self) { height in
                            if height > 0 { upcomingSectionHeight = height }
                        }
                        .background {
                            FeedScrollViewBinder(bridge: feedScrollBridge)
                        }
                    }
                    .modifier(
                        FeedScrollPeopleChromeModifier(
                            showPeopleRow: $showPeopleRow,
                            scrollOffsetY: $scrollOffsetY,
                            isLocked: feedChromeScrollLocked
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PageChrome.feedBackground)

            // Feed-layer sticky filters. When stuck, sit above chrome so pills receive
            // taps; the clear spacer passes hits through to the search bar.
            stickyFeedFilters
                .zIndex(areFiltersStuck ? 3 : 1)

            // Search + watchlist overlay the feed; height collapse clips the watchlist.
            homeChrome
                .frame(height: homeChromeHeight, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .clipped()
                // Keep hit-testing within the visible chrome bounds (not clipped children).
                .contentShape(Rectangle())
                .background(Color(.systemBackground))
                .overlay(alignment: .bottom) {
                    // Tracks the expanding/collapsing nav unit (same color as plus↔avatar rule).
                    homeChromeBorderColor
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }
                .zIndex(2)

            if isPreparingHome {
                homePreparingOverlay
                    .zIndex(4)
                    .transition(.opacity)
            }
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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $profilePickerCard) { card in
            UpcomingProfilePickerSheet(
                card: card,
                onSelect: { profile in
                    profilePickerCard = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onSelectPerson(profile)
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await prepareHomeAndAnimate()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                WatchlistInteractionStore.markAppBackgrounded()
            case .active:
                guard WatchlistInteractionStore.consumePendingSessionRefresh() else { return }
                Task { await refreshWatchlistForNewSession() }
            default:
                break
            }
        }
    }

    /// Collective loader while feed data + hero/product images warm up.
    private var homePreparingOverlay: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: expandedHomeChromeHeight)

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color(hex: 0x333333))
                Text("Loading picks…")
                    .font(.nytFranklin(.medium, size: 14))
                    .foregroundStyle(Color(hex: 0x666666))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PageChrome.feedBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading picks")
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
                // Collapsed avatars stay in the layout for measurement/clipping, but must
                // not intercept taps while invisible.
                .allowsHitTesting(showPeopleRow)
                .accessibilityHidden(!showPeopleRow)
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

    // MARK: - Watchlist (editorial moments + gift profiles)

    private var peopleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                addPersonButton
                    .opacity(plusVisible ? 1 : 0)

                homeChromeBorderColor
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, 12)
                    .opacity(separatorVisible ? 1 : 0)

                HStack(alignment: .top, spacing: 6) {
                    ForEach(watchlistEntries) { entry in
                        watchlistItem(entry)
                            .opacity(watchlistItemOpacity(for: entry))
                            .offset(y: visibleWatchlistIDs.contains(entry.id) ? 0 : 10)
                            .onTapGesture {
                                handleWatchlistTap(entry)
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
    }

    @ViewBuilder
    private func watchlistItem(_ entry: WatchlistEntry) -> some View {
        switch entry {
        case .editorial(let moment):
            watchlistEditorialItem(moment)
        case .person(let person):
            personAvatar(
                person,
                showAlertDot: shouldShowWatchlistAlertDot(for: person, entryID: entry.id)
            )
        case .viewAll:
            watchlistViewAllItem
        }
    }

    private func watchlistItemOpacity(for entry: WatchlistEntry) -> Double {
        guard visibleWatchlistIDs.contains(entry.id) else { return 0 }
        if case .viewAll = entry { return 1 }
        // Prefer the in-memory session store so dims survive view recreation.
        if WatchlistInteractionStore.hasVisitedThisSession(entry.id)
            || visitedWatchlistIDs.contains(entry.id) {
            return 0.7
        }
        return 1
    }

    private func shouldShowWatchlistAlertDot(for person: PersonProfile, entryID: String) -> Bool {
        if WatchlistInteractionStore.hasVisitedThisSession(entryID)
            || visitedWatchlistIDs.contains(entryID) {
            return false
        }
        return WatchlistEventCompletionStore.hasActiveUrgentEvent(person)
    }

    private func handleWatchlistTap(_ entry: WatchlistEntry) {
        WatchlistInteractionStore.recordInteraction()
        switch entry {
        case .editorial(let moment):
            markWatchlistVisited(entry)
            onSelectEditorial(moment)
        case .person(let person):
            WatchlistInteractionStore.recordPersonOpen(person)
            markWatchlistVisited(entry)
            onSelectPerson(person)
        case .viewAll:
            onViewAllWatchlist()
        }
    }

    private func markWatchlistVisited(_ entry: WatchlistEntry) {
        WatchlistInteractionStore.recordSessionVisit(entry.id)
        withAnimation(.easeOut(duration: 0.25)) {
            // Accumulate — never replace with a fresh set (that can drop prior visits).
            visitedWatchlistIDs.insert(entry.id)
            visitedWatchlistIDs.formUnion(WatchlistInteractionStore.sessionVisitedIDs)
            rebuildWatchlistOrderPreservingVisibility()
        }
    }

    /// Re-applies session visit pinning without a network fetch.
    private func rebuildWatchlistOrderPreservingVisibility() {
        let next = WatchlistBuilder.build(
            people: people,
            editorials: watchlistEditorials,
            sessionVisitOrder: WatchlistInteractionStore.sessionVisitOrder,
            seed: UInt64(people.count &* 31 &+ watchlistEditorials.count)
        )
        watchlistEntries = next
        visibleWatchlistIDs.formUnion(next.map(\.id))
    }

    /// Cold return from background: clear in-session dims, restore red dots, refresh editorials.
    private func refreshWatchlistForNewSession() async {
        WatchlistInteractionStore.beginSession()
        visitedWatchlistIDs = []
        let loaded = await WatchlistStore.loadEntries(people: people)
        watchlistEditorials = loaded.editorials
        watchlistEntries = loaded.entries
        visibleWatchlistIDs = Set(loaded.entries.map(\.id))

        var urls: [URL] = []
        for entry in loaded.entries {
            if case .editorial(let moment) = entry, let thumb = moment.thumbnailURL {
                urls.append(thumb)
            }
        }
        await prefetchImages(urls)
    }

    private func watchlistEditorialItem(_ moment: WatchlistEditorialMoment) -> some View {
        VStack(spacing: 6) {
            Group {
                if let url = moment.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure, .empty:
                            Color(hex: 0xEEEEEE)
                        @unknown default:
                            Color(hex: 0xEEEEEE)
                        }
                    }
                } else {
                    Color(hex: 0xEEEEEE)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color(hex: 0xEEEEEE), lineWidth: 1)
            }
            .accessibilityLabel("\(moment.label) editorial highlight")

            Text(moment.label)
                .font(.nytFranklin(.medium, size: 12))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 52)
        .contentShape(Rectangle())
    }

    private var watchlistViewAllItem: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0xEEEEEE))
                    .frame(width: 40, height: 40)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.label))
            }
            .overlay {
                Circle()
                    .stroke(Color(hex: 0xEEEEEE), lineWidth: 1)
            }
            .accessibilityLabel("View all watchlist")

            Text("View all")
                .font(.nytFranklin(.medium, size: 12))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 52)
        .contentShape(Rectangle())
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

        // Wait for the separator fade to finish, then pause before watchlist items.
        try? await Task.sleep(for: .seconds(duration + pauseBeforeAvatars))

        for entry in watchlistEntries {
            withAnimation(.easeOut(duration: duration)) {
                visibleWatchlistIDs.insert(entry.id)
            }
            try? await Task.sleep(for: .seconds(stagger))
        }

        // Let the last avatar finish rising before the next section fades in.
        try? await Task.sleep(for: .seconds(duration * 0.5))
    }

    /// Upcoming → filter pills → feed, only after the people row has finished.
    private func playHomeContentEntrance() async {
        guard !didStartContentEntrance else { return }
        didStartContentEntrance = true

        let duration: TimeInterval = 0.4
        let pauseBetweenSections: TimeInterval = 0.06

        withAnimation(.easeOut(duration: duration)) {
            upcomingRevealed = true
        }
        try? await Task.sleep(for: .seconds(duration * 0.5 + pauseBetweenSections))

        withAnimation(.easeOut(duration: duration)) {
            filtersRevealed = true
        }
        try? await Task.sleep(for: .seconds(duration * 0.5 + pauseBetweenSections))

        await playFeedEntrance()
    }

    private func playFeedEntrance() async {
        let duration: TimeInterval = 0.4
        let stagger: TimeInterval = 0.08
        let staggeredCount = 8
        let products = filteredProducts

        for item in products.prefix(staggeredCount) {
            withAnimation(.easeOut(duration: duration)) {
                visibleFeedProductIDs.insert(item.id)
            }
            try? await Task.sleep(for: .seconds(stagger))
        }

        withAnimation(.easeOut(duration: duration)) {
            for item in products.dropFirst(staggeredCount) {
                visibleFeedProductIDs.insert(item.id)
            }
            feedRevealComplete = true
        }
    }

    // MARK: - Home prepare (data + imagery, then staged entrance)

    /// Load feed + gift-guide heroes, prefetch images into URLCache, then run the
    /// people → upcoming → pills → feed entrance sequence.
    private func prepareHomeAndAnimate() async {
        // Keep local dims aligned with the process-wide session store (survives view churn).
        visitedWatchlistIDs.formUnion(WatchlistInteractionStore.sessionVisitedIDs)

        if didPlayPeopleEntrance {
            if !watchlistEditorials.isEmpty {
                rebuildWatchlistOrderPreservingVisibility()
            }
            return
        }

        await loadFeed()

        var urls: [URL] = upcomingEventCards.compactMap(\.heroImageURL)
        for entry in watchlistEntries {
            if case .editorial(let moment) = entry, let thumb = moment.thumbnailURL {
                urls.append(thumb)
            }
        }
        for item in shuffledProducts.prefix(8) {
            if let url = item.displayImageUrl {
                urls.append(url)
            }
        }
        await prefetchImages(urls)

        withAnimation(.easeOut(duration: 0.3)) {
            isPreparingHome = false
        }
        // Brief beat after the loader fades before the people row starts.
        try? await Task.sleep(for: .seconds(0.1))

        guard !didPlayPeopleEntrance else { return }
        didPlayPeopleEntrance = true
        await playPeopleEntrance()
        await playHomeContentEntrance()
    }

    /// Warm URLCache (and decode) so AsyncImage paints immediately on reveal.
    private func prefetchImages(_ urls: [URL]) async {
        let unique = Array(Set(urls))
        guard !unique.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for url in unique {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .returnCacheDataElseLoad
                    request.timeoutInterval = 12
                    guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
                    // Force decode so the first paint isn’t stalled on the main thread.
                    _ = UIImage(data: data)
                }
            }
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

    private func personAvatar(_ person: PersonProfile, showAlertDot: Bool = true) -> some View {
        VStack(spacing: 6) {
            Image(AvatarStyle.assetName(for: person.name))
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if showAlertDot, person.hasUpcomingEvent(within: 21) {
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

    // MARK: - Feed filters

    private var stickyFeedFilters: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: stickyFilterTopInset)
                // Don't block the search bar when this layer sits above chrome.
                .allowsHitTesting(false)

            feedFilterRow
                .padding(.top, 10)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .background {
                    GeometryReader { geo in
                        // Solid through the pill row, then fade from the bottom edge
                        // of the pills to the bottom of this sticky feed layer.
                        let fadeStart = max(geo.size.height - 28, 1) / max(geo.size.height, 1)
                        LinearGradient(
                            stops: [
                                .init(color: PageChrome.feedBackground.opacity(1), location: 0),
                                .init(color: PageChrome.feedBackground.opacity(1), location: fadeStart),
                                .init(color: PageChrome.feedBackground.opacity(0), location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
        }
        // Keep intrinsic height — this overlay lives in a full-screen ZStack, and
        // expanding children would paint the feed-gray background over the whole UI.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .top)
        .opacity(areFiltersStuck && filtersRevealed ? 1 : 0)
        .offset(y: filtersRevealed ? 0 : 10)
        .allowsHitTesting(areFiltersStuck && filtersRevealed)
        .accessibilityHidden(!(areFiltersStuck && filtersRevealed))
    }

    private var feedFilterRow: some View {
        ZStack(alignment: .leading) {
            // Price pills scroll underneath the fixed Buy Now cluster.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: feedFilterPillSpacing) {
                    Color.clear
                        .frame(width: max(buyNowClusterWidth, 1))

                    ForEach(feedFilters) { filter in
                        priceFilterPill(filter)
                    }
                }
                .padding(.trailing, PageChrome.horizontalMargin)
                .padding(.vertical, 4)
            }
            .fixedSize(horizontal: false, vertical: true)

            // Fixed leading chrome: solid feed gray through the separator, then
            // a 100% → 0% fade so pills ease out underneath.
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    buyNowSwitch
                        .padding(.leading, PageChrome.horizontalMargin)
                        .padding(.trailing, 12)

                    Color(hex: 0xD6D6D6)
                        .frame(width: 1, height: 40)
                }
                .background(PageChrome.feedBackground)

                LinearGradient(
                    colors: [
                        PageChrome.feedBackground.opacity(1),
                        PageChrome.feedBackground.opacity(0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: buyFromNYTFadeWidth)
                .allowsHitTesting(false)
            }
            .zIndex(1)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: BuyNowClusterWidthKey.self,
                        value: geo.size.width
                    )
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onPreferenceChange(BuyNowClusterWidthKey.self) { width in
            if width > 0 { buyNowClusterWidth = width }
        }
    }

    private func priceFilterPill(_ filter: FeedPriceFilter) -> some View {
        let isSelected = selectedFeedFilter == filter
        return Button {
            preserveFeedChromeAcrossFilterChange {
                selectedFeedFilter = isSelected ? nil : filter
            }
        } label: {
            Text(filter.title)
                .font(.nytFranklin(.medium, size: 13))
                .foregroundStyle(isSelected ? Color.white : Color(.label))
                .lineLimit(1)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.black : Color.white)
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.black : Color(hex: 0xCCCCCC),
                            lineWidth: 1
                        )
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var buyNowSwitch: some View {
        HStack(spacing: 0) {
            Toggle("", isOn: buyNowOnlyBinding)
                .labelsHidden()
                .tint(Color.black)
                .controlSize(.mini)

            Text("Buy from NYT")
                .font(.nytFranklin(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0x333333))
                .fixedSize()
                .padding(.leading, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Buy from NYT")
        .accessibilityValue(buyNowOnly ? "On" : "Off")
    }

    /// Keeps feed scroll offset + avatar-row visibility stable across LazyVStack swaps.
    private var buyNowOnlyBinding: Binding<Bool> {
        Binding(
            get: { buyNowOnly },
            set: { newValue in
                preserveFeedChromeAcrossFilterChange {
                    buyNowOnly = newValue
                }
            }
        )
    }

    private func preserveFeedChromeAcrossFilterChange(_ updates: () -> Void) {
        // Near the top, UIKit offset restores fight SwiftUI layout and snap the feed
        // ~32pt. Only preserve when stuck (where LazyVStack jump-to-top actually hurts).
        guard areFiltersStuck else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, updates)
            return
        }

        let peopleVisible = showPeopleRow
        let peopleBinding = $showPeopleRow
        let lockBinding = $feedChromeScrollLocked

        lockBinding.wrappedValue = true
        feedScrollBridge.preserveOffsetAcross(updates)

        let reassertPeople = {
            if peopleBinding.wrappedValue != peopleVisible {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    peopleBinding.wrappedValue = peopleVisible
                }
            }
        }
        reassertPeople()
        DispatchQueue.main.async(execute: reassertPeople)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            reassertPeople()
            lockBinding.wrappedValue = false
        }
    }

    private func matchesFeedFilter(_ item: CommerceItem, _ filter: FeedPriceFilter) -> Bool {
        guard let dollars = item.priceInDollars else { return false }
        switch filter {
        case .under50:
            return dollars < 50
        case .fiftyToHundred:
            return dollars >= 50 && dollars <= 100
        case .overHundred:
            return dollars > 100
        }
    }

    // MARK: - Upcoming Row

    private var upcomingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.nytFranklin(.bold, size: 18))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(upcomingEventCards) { card in
                        upcomingEventCard(card)
                            // Force a fresh AsyncImage when the hero URL arrives.
                            .id("\(card.id)-\(card.heroImageURL?.absoluteString ?? "none")")
                    }
                }
                // Top padding clears the avatar tag; bottom padding clears card shadows.
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 10)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func upcomingEventCard(_ card: UpcomingEventCard) -> some View {
        Button {
            handleUpcomingCardTap(card)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Specialty cards keep an empty tag-sized row so heroes share a baseline
                // with personalized cards that show profile tags.
                if card.isSpecialty {
                    upcomingEventTagPlaceholder
                } else {
                    upcomingEventTag(card)
                }

                upcomingEventHero(card)
                    .frame(width: 250, height: 144)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .background {
                        // Approximates box-shadow: 0 2px 5px 4px rgba(36,50,66,0.1)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(red: 36 / 255, green: 50 / 255, blue: 66 / 255).opacity(0.1))
                            .blur(radius: 5)
                            .padding(-4)
                            .offset(y: 2)
                    }
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    if !card.isSpecialty {
                        Text(card.countdownLabel())
                            .font(.nytFranklin(.medium, size: 11))
                            .tracking(1.1) // 10% of 11px
                            .foregroundStyle(Color(hex: 0x333333))
                            .textCase(.uppercase)
                            .lineLimit(1)
                    }

                    Text(card.eventTitle)
                        .font(.nytFranklin(size: card.isSpecialty ? 20 : 16, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 250, alignment: .leading)
                .padding(.top, 12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityHint(upcomingAccessibilityHint(card))
    }

    private func upcomingAccessibilityHint(_ card: UpcomingEventCard) -> String {
        if card.isSpecialty {
            return "Opens \(card.eventTitle) coverage"
        }
        if card.profiles.count > 1 {
            return "Opens a list of people to shop for"
        }
        return "Opens \(card.profiles.first?.name ?? "profile")"
    }

    private func handleUpcomingCardTap(_ card: UpcomingEventCard) {
        if card.isSpecialty, let articleURL = card.articleURL {
            onSelectEditorial(
                WatchlistEditorialMoment(
                    id: card.id,
                    label: card.eventTitle,
                    articleURL: articleURL,
                    thumbnailURL: card.heroImageURL
                )
            )
            return
        }
        if card.profiles.count == 1, let profile = card.profiles.first {
            onSelectPerson(profile)
        } else if card.profiles.count > 1 {
            profilePickerCard = card
        }
    }

    private func upcomingEventTag(_ card: UpcomingEventCard) -> some View {
        HStack(spacing: 6) {
            overlappingProfileAvatars(Array(card.profiles.prefix(3)))

            Text(card.tagLabel)
                .font(.nytFranklin(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0x333333))
                .lineLimit(1)
        }
    }

    /// Invisible stand-in matching profile-tag height so specialty heroes align.
    private var upcomingEventTagPlaceholder: some View {
        HStack(spacing: 6) {
            Color.clear
                .frame(width: 16, height: 16)

            Text(" ")
                .font(.nytFranklin(size: 16, weight: .semibold))
                .hidden()
        }
        .accessibilityHidden(true)
    }

    private func overlappingProfileAvatars(_ profiles: [PersonProfile]) -> some View {
        HStack(spacing: -6) {
            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                Image(AvatarStyle.assetName(for: profile.name))
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 16, height: 16)
                    .background(AvatarStyle.backgroundColor(for: profile.name))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    }
                    .zIndex(Double(profiles.count - index))
            }
        }
    }

    @ViewBuilder
    private func upcomingEventHero(_ card: UpcomingEventCard) -> some View {
        if let url = card.heroImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    upcomingHeroPlaceholder
                case .empty:
                    upcomingHeroPlaceholder
                        .overlay { ProgressView().scaleEffect(0.8) }
                @unknown default:
                    upcomingHeroPlaceholder
                }
            }
            .frame(width: 250, height: 144)
            .clipped()
        } else {
            upcomingHeroPlaceholder
                .frame(width: 250, height: 144)
        }
    }

    private var upcomingHeroPlaceholder: some View {
        Color(hex: 0xEEEEEE)
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
            async let feedTask = APIClient.shared.fetchCommerceFeed()
            async let heroesTask = GiftGuideHeroCatalog.loadHeroes()
            async let watchlistTask = WatchlistStore.loadEntries(people: people)
            async let specialtyTask = UpcomingSpecialtyCatalog.loadLeadCard()

            let result = try await feedTask
            let heroes = await heroesTask
            let watchlist = await watchlistTask
            let specialty = await specialtyTask
            let peopleSnapshot = people
            let cards = UpcomingEventsBuilder.cards(
                from: peopleSnapshot,
                giftGuideHeroes: heroes,
                limit: 4,
                specialtyLead: specialty
            )
            items = result.products
            shopifyProducts = result.shopifyProducts
            upcomingEventCards = cards
            watchlistEditorials = watchlist.editorials
            watchlistEntries = watchlist.entries
            visitedWatchlistIDs.formUnion(WatchlistInteractionStore.sessionVisitedIDs)
            isLoading = false
        } catch {
            // Still try to show Upcoming heroes / watchlist if the commerce feed fails.
            async let heroesTask = GiftGuideHeroCatalog.loadHeroes()
            async let watchlistTask = WatchlistStore.loadEntries(people: people)
            async let specialtyTask = UpcomingSpecialtyCatalog.loadLeadCard()
            let heroes = await heroesTask
            let specialty = await specialtyTask
            let watchlist = await watchlistTask
            watchlistEditorials = watchlist.editorials
            watchlistEntries = watchlist.entries
            visitedWatchlistIDs.formUnion(WatchlistInteractionStore.sessionVisitedIDs)
            upcomingEventCards = UpcomingEventsBuilder.cards(
                from: people,
                giftGuideHeroes: heroes,
                limit: 4,
                specialtyLead: specialty
            )
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
            .padding(.bottom, 12)
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
                        .font(.nytFranklin(size: 14, weight: .medium))
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

private struct BuyNowClusterWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct UpcomingSectionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Feed scroll ↔ people chrome

/// Holds a weak reference to the feed's UIScrollView so filter changes can restore offset.
private final class FeedScrollViewBridge {
    weak var scrollView: UIScrollView?

    func preserveOffsetAcross(_ updates: () -> Void) {
        let y = scrollView?.contentOffset.y ?? 0
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
        restoreOffset(y)
        // LazyVStack often finishes laying out one run-loop later and zeroes offset again.
        DispatchQueue.main.async { [weak self] in
            self?.restoreOffset(y)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.restoreOffset(y)
        }
    }

    private func restoreOffset(_ y: CGFloat) {
        guard let scrollView else { return }
        let maxY = max(scrollView.contentSize.height - scrollView.bounds.height, 0)
        let clamped = min(max(y, 0), maxY)
        guard abs(scrollView.contentOffset.y - clamped) > 0.5 else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: clamped), animated: false)
    }
}

/// Walks up from a content-hosted UIView to bind the enclosing UIScrollView.
private struct FeedScrollViewBinder: UIViewRepresentable {
    let bridge: FeedScrollViewBridge

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            bridge.scrollView = uiView.enclosingScrollView()
        }
    }
}

private extension UIView {
    func enclosingScrollView() -> UIScrollView? {
        var current: UIView? = self
        while let view = current {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }
}

/// Collapses the avatar extension of home chrome while scrolling down; restores on scroll up.
private struct FeedScrollPeopleChromeModifier: ViewModifier {
    @Binding var showPeopleRow: Bool
    @Binding var scrollOffsetY: CGFloat
    /// When true (e.g. mid filter restore), ignore offset teleports that would expand the row.
    var isLocked: Bool
    @State private var lastOffsetY: CGFloat = 0
    @State private var accumulatedDelta: CGFloat = 0
    @State private var lockScrollHandlingUntil: Date = .distantPast

    private let topRevealThreshold: CGFloat = 20
    private let hideAfterScrollDown: CGFloat = 36
    private let showAfterScrollUp: CGFloat = 24
    private let lockDuration: TimeInterval = 0.5
    /// Deltas larger than this are treated as programmatic jumps, not finger scrolls.
    private let teleportThreshold: CGFloat = 80

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newOffsetY in
                    scrollOffsetY = newOffsetY
                    handleScroll(offsetY: newOffsetY)
                }
                .onChange(of: isLocked) { _, locked in
                    if !locked {
                        // Resync baseline so unlocking doesn't look like a fling.
                        lastOffsetY = scrollOffsetY
                        accumulatedDelta = 0
                    }
                }
        } else {
            content
        }
    }

    private func handleScroll(offsetY: CGFloat) {
        let delta = offsetY - lastOffsetY
        lastOffsetY = offsetY

        if isLocked {
            accumulatedDelta = 0
            return
        }

        // Ignore programmatic offset restores (filter swaps) that jump by hundreds of points.
        if abs(delta) >= teleportThreshold {
            accumulatedDelta = 0
            return
        }

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

// MARK: - Upcoming multi-profile picker

/// Bottom sheet listing gift profiles for a shared Upcoming event (e.g. Christmas).
private struct UpcomingProfilePickerSheet: View {
    let card: UpcomingEventCard
    var onSelect: (PersonProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Who are you shopping for?")
                .font(.nytFranklin(size: 18, weight: .semibold))
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text(card.eventTitle)
                .font(.nytFranklin(.medium, size: 14))
                .foregroundStyle(Color(hex: 0x666666))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(card.profiles) { profile in
                        Button {
                            onSelect(profile)
                        } label: {
                            HStack(spacing: 14) {
                                Image(AvatarStyle.assetName(for: profile.name))
                                    .resizable()
                                    .renderingMode(.original)
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())

                                Text(profile.name)
                                    .font(.nytFranklin(size: 16, weight: .medium))
                                    .foregroundStyle(Color(.label))

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(hex: 0x999999))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if profile.id != card.profiles.last?.id {
                            Divider()
                                .padding(.leading, 78)
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
        .background(Color(.systemBackground))
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
