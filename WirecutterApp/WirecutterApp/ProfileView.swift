import SwiftUI
import UIKit

/// Profile page for a person: preference hero + recommendation feed.
struct ProfileView: View {
    let profile: PersonProfile
    var onBack: () -> Void
    var onSearch: () -> Void
    /// Opens this profile’s save list (same destination as Saves → Gift Profiles).
    var onOpenSaved: () -> Void = {}

    @State private var items: [CommerceItem] = []
    @State private var shopifyProducts: [CommerceItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?
    @State private var quickViewItem: CommerceItem?
    @State private var showHeroDetails = true
    @State private var headerHeight: CGFloat = 56
    @State private var detailsHeight: CGFloat = 0
    @ObservedObject private var recentlyViewedStore = RecentlyViewedStore.shared
    @ObservedObject private var savedStore = SavedStore.shared

    private let tabBarContentInset: CGFloat = 100
    private var avatarColor: Color { AvatarStyle.backgroundColor(for: profile.name) }

    /// Visible (possibly collapsed) chrome height — drives the overlay clip only.
    private var chromeHeight: CGFloat {
        showHeroDetails ? expandedChromeHeight : collapsedChromeHeight
    }

    private var collapsedChromeHeight: CGFloat { max(headerHeight, 1) }

    /// Full chrome height used for feed top padding. Stays constant during snap so the
    /// feed only moves from user scrolling, not from the nav collapse animation.
    private var expandedChromeHeight: CGFloat {
        collapsedChromeHeight + max(detailsHeight, 0)
    }

    private var shuffledProducts: [CommerceItem] {
        var all = items + shopifyProducts
        // hashValue can be negative — never cast Int → UInt64 directly.
        let seed = UInt64(bitPattern: Int64(profile.id.hashValue)) &+ UInt64(all.count)
        var rng = SeededRandomNumberGenerator(seed: seed == 0 ? 1 : seed)
        all.shuffle(using: &rng)
        return all
    }

    private var recentlyViewedProducts: [CommerceItem] {
        recentlyViewedStore.items(for: profile.id)
    }

    private var savedProducts: [CommerceItem] {
        savedStore.items(for: profile.id)
    }

    private var upcomingEventBannerText: String? {
        profile.upcomingEventBannerMessage(within: 21)
    }

    /// Hide Saved entirely when empty (e.g. Frodo’s demo default). Show a loading
    /// placeholder only for profiles that are expected to have demo saves.
    private var shouldShowSavedSection: Bool {
        if isLoading {
            return SavedStore.demoSeedCount(for: profile.id) > 0
        }
        return !savedProducts.isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            feed
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PageChrome.feedBackground)

            // Search + profile details overlay the feed; collapse clips details away.
            profileChrome
                .frame(height: chromeHeight, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .clipped()
                .background(avatarColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PageChrome.feedBackground)
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Navigation chrome (search + details as one unit)

    private var profileChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ProfileHeaderHeightKey.self,
                            value: geo.size.height
                        )
                    }
                }

            heroDetails
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ProfileHeroDetailsHeightKey.self,
                            value: geo.size.height
                        )
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onPreferenceChange(ProfileHeaderHeightKey.self) { height in
            if height > 0 { headerHeight = height }
        }
        .onPreferenceChange(ProfileHeroDetailsHeightKey.self) { height in
            if height > 0 { detailsHeight = height }
        }
    }

    private var heroDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(profile.name)
                .font(.nytFranklin(.medium, size: 28))
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 32)
                .padding(.horizontal, PageChrome.horizontalMargin)

            VStack(spacing: 16) {
                preferenceRow(label: "Birthday", value: profile.birthdayDisplay, icon: "PrefGift")
                preferenceRow(label: "Holidays", value: profile.holidaysDisplay, icon: "PrefCalendar")
            }
            .padding(.top, 24)
            .padding(.horizontal, PageChrome.horizontalMargin)
            .padding(.bottom, 28)
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: onBack) {
                Image("NavArrow")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.black)
                    .rotationEffect(.degrees(180))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Button(action: onSearch) {
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

            HStack(spacing: 16) {
                headerActionButton(icon: "bell")
                headerActionButton(icon: "cart")
            }
        }
        .padding(.horizontal, PageChrome.horizontalMargin)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func preferenceRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 6) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color(.label))

                Text(label)
                    .font(.nytFranklin(size: 14, weight: .medium))
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 16)

            Text(value)
                .font(.nytFranklin(size: 14, weight: .semibold))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.trailing)
        }
    }

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

    // MARK: - Feed

    private var feed: some View {
        Group {
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.nytFranklin(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .padding(.top, expandedChromeHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                profileScroll {
                    specialtyEntrance {
                        upcomingEventBannerIfNeeded()
                        productStripSection(
                            title: "Recently Viewed",
                            isLoading: true,
                            products: [],
                            topPadding: upcomingEventBannerText == nil ? 8 : 0
                        )
                        if shouldShowSavedSection {
                            productStripSection(
                                title: "Saved",
                                isLoading: true,
                                products: [],
                                onHeaderTap: onOpenSaved
                            )
                        }
                    }

                    ForEach(0..<4, id: \.self) { index in
                        GhostProductCard()
                            .padding(.horizontal, PageChrome.horizontalMargin)
                            .opacity(1.0 - Double(index) * 0.12)
                    }
                }
            } else if shuffledProducts.isEmpty {
                profileScroll {
                    specialtyEntrance {
                        upcomingEventBannerIfNeeded()
                        productStripSection(
                            title: "Recently Viewed",
                            isLoading: false,
                            products: recentlyViewedProducts,
                            topPadding: upcomingEventBannerText == nil ? 8 : 0
                        )
                        if shouldShowSavedSection {
                            productStripSection(
                                title: "Saved",
                                isLoading: false,
                                products: savedProducts,
                                onHeaderTap: onOpenSaved
                            )
                        }
                    }

                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No products found")
                            .font(.nytFranklin(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            } else {
                profileScroll {
                    specialtyEntrance {
                        upcomingEventBannerIfNeeded()
                        productStripSection(
                            title: "Recently Viewed",
                            isLoading: false,
                            products: recentlyViewedProducts,
                            topPadding: upcomingEventBannerText == nil ? 8 : 0
                        )
                        if shouldShowSavedSection {
                            productStripSection(
                                title: "Saved",
                                isLoading: false,
                                products: savedProducts,
                                onHeaderTap: onOpenSaved
                            )
                        }
                    }

                    ForEach(shuffledProducts) { item in
                        ProductCardView(
                            item: item,
                            onTap: { openProduct(item) },
                            isSaved: savedStore.contains(item, for: profile.id),
                            onBookmarkTap: { savedStore.toggle(item, for: profile.id) }
                        )
                        .padding(.horizontal, PageChrome.horizontalMargin)
                    }
                }
            }
        }
    }

    // MARK: - Upcoming event banner

    @ViewBuilder
    private func upcomingEventBannerIfNeeded() -> some View {
        if let message = upcomingEventBannerText {
            Text(message)
                .font(.nytFranklin(.medium, size: 12))
                .foregroundStyle(Color(hex: 0xAE0115))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Color(hex: 0xFFECEC))
                .padding(.horizontal, PageChrome.horizontalMargin)
                .accessibilityLabel(message)
        }
    }

    // MARK: - Product strips (Recently Viewed / Saved)

    private func productStripSection(
        title: String,
        isLoading: Bool,
        products: [CommerceItem],
        topPadding: CGFloat = 8,
        onHeaderTap: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let onHeaderTap {
                    Button(action: onHeaderTap) {
                        productStripHeader(title: title)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isButton)
                } else {
                    productStripHeader(title: title)
                }
            }
            .padding(.horizontal, PageChrome.horizontalMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if isLoading {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(.systemGray6))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Color(hex: 0xCCCCCC), lineWidth: 1)
                                }
                        }
                    } else {
                        ForEach(products) { item in
                            productStripThumbnail(item)
                        }
                    }
                }
                .padding(.horizontal, PageChrome.horizontalMargin)
                .padding(.top, 2)
                .padding(.bottom, 10)
            }
        }
        .padding(.top, topPadding)
        .padding(.bottom, 4)
    }

    private func productStripHeader(title: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.nytFranklin(.bold, size: 18))
                .foregroundStyle(Color(.label))

            Spacer(minLength: 8)

            Image("NavArrow")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(Color(hex: 0x979797))
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private func productStripThumbnail(_ item: CommerceItem) -> some View {
        Button {
            openProduct(item)
        } label: {
            Group {
                if let imageUrl = item.displayImageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Color(.systemGray5)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                        default:
                            Color(.systemGray6)
                        }
                    }
                } else {
                    Color(.systemGray6)
                }
            }
            .frame(width: 80, height: 80)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color(hex: 0xCCCCCC), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.productTitle)
    }

    /// Specialty rows sit in the white → feed-gray fade. The under-chrome spacer is
    /// solid start-color so the gradient isn't diluted behind the overlay.
    private func specialtyEntrance<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PageChrome.feedEntranceStart
                .frame(height: expandedChromeHeight + 16)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { FeedEntranceGradient() }
        }
    }

    private func profileScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                content()
            }
            .padding(.bottom, tabBarContentInset)
        }
        .modifier(ProfileHeroScrollModifier(showHeroDetails: $showHeroDetails))
    }

    private func openProduct(_ item: CommerceItem) {
        recentlyViewedStore.record(item, for: profile.id)
        quickViewItem = item
    }

    private func loadFeed() async {
        do {
            let result = try await APIClient.shared.fetchCommerceFeed()
            withAnimation(.easeOut(duration: 0.35)) {
                items = result.products
                shopifyProducts = result.shopifyProducts
                isLoading = false
            }
            let candidates = result.products + result.shopifyProducts
            // Demo seed only — real views / saves replace or reorder these per profile.
            recentlyViewedStore.seedDemoIfNeeded(profileID: profile.id, from: candidates)
            savedStore.seedDemoIfNeeded(profileID: profile.id, from: candidates)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Chrome measurement

private struct ProfileHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ProfileHeroDetailsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Collapses profile chrome details while scrolling down; restores on scroll up.
private struct ProfileHeroScrollModifier: ViewModifier {
    @Binding var showHeroDetails: Bool
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

        if offsetY < topRevealThreshold {
            accumulatedDelta = 0
            setHeroDetailsVisible(true)
            return
        }

        guard Date() >= lockScrollHandlingUntil else { return }
        guard abs(delta) > 0.5 else { return }

        if accumulatedDelta == 0 || (accumulatedDelta > 0) == (delta > 0) {
            accumulatedDelta += delta
        } else {
            accumulatedDelta = delta
        }

        if accumulatedDelta >= hideAfterScrollDown {
            accumulatedDelta = 0
            setHeroDetailsVisible(false)
        } else if accumulatedDelta <= -showAfterScrollUp {
            accumulatedDelta = 0
            setHeroDetailsVisible(true)
        }
    }

    private func setHeroDetailsVisible(_ visible: Bool) {
        guard showHeroDetails != visible else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.66, blendDuration: 0.1)) {
            showHeroDetails = visible
        }
        lockScrollHandlingUntil = Date().addingTimeInterval(lockDuration)
    }
}
