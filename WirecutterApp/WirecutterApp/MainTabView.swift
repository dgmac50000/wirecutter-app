import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case browse
    case saves
    case account

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browse: return "Browse"
        case .saves: return "Saves"
        case .account: return "Account"
        }
    }

    /// Asset catalog template images (from Temporary Icons SVGs).
    var imageName: String {
        switch self {
        case .browse: return "TabBrowse"
        case .saves: return "TabSaves"
        case .account: return "TabAccount"
        }
    }
}

/// Matches Browse feed content insets (`CommerceListView` horizontal padding).
enum PageChrome {
    static let horizontalMargin: CGFloat = 20
    static let selectedTabColor = Color.black

    /// Background behind the traditional product-card feed.
    /// Feed-entrance gradients end on this color so they stay in sync if it changes.
    static let feedBackground = Color(hex: 0xEEEEEE)

    /// Top stop of the nav → feed fade (white in light mode).
    static let feedEntranceStart = Color(.systemBackground)
}

/// White → feed-gray fade from collapsing nav through specialty rows, ending where
/// the traditional product-card feed begins.
struct FeedEntranceGradient: View {
    var body: some View {
        LinearGradient(
            colors: [PageChrome.feedEntranceStart, PageChrome.feedBackground],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// App shell using system `TabView` so iOS 26 Liquid Glass press / drag
/// morphing between tabs comes for free.
struct MainTabView: View {
    @State private var selectedTab: AppTab = .browse

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                legacyTabView
            }
        }
        .tint(PageChrome.selectedTabColor)
        .modifier(TabBarLiquidGlassBehavior())
        .background {
            TabBarContentWidthEnforcer(horizontalMargin: PageChrome.horizontalMargin)
                .allowsHitTesting(false)
        }
    }

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.browse.title, image: AppTab.browse.imageName, value: .browse) {
                BrowseStackView(selectedTab: $selectedTab)
            }

            Tab(AppTab.saves.title, image: AppTab.saves.imageName, value: .saves) {
                SavesStackView(selectedTab: $selectedTab)
            }

            Tab(AppTab.account.title, image: AppTab.account.imageName, value: .account) {
                PlaceholderTabView(
                    title: "Account",
                    imageName: AppTab.account.imageName,
                    message: "Sign in and manage your Wirecutter account."
                )
            }
        }
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            BrowseStackView(selectedTab: $selectedTab)
                .tabItem {
                    Label(AppTab.browse.title, image: AppTab.browse.imageName)
                }
                .tag(AppTab.browse)

            SavesStackView(selectedTab: $selectedTab)
                .tabItem {
                    Label(AppTab.saves.title, image: AppTab.saves.imageName)
                }
                .tag(AppTab.saves)

            PlaceholderTabView(
                title: "Account",
                imageName: AppTab.account.imageName,
                message: "Sign in and manage your Wirecutter account."
            )
            .tabItem {
                Label(AppTab.account.title, image: AppTab.account.imageName)
            }
            .tag(AppTab.account)
        }
    }
}

private struct TabBarLiquidGlassBehavior: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .tabBarMinimizeBehavior(.never)
        } else {
            content
        }
    }
}

/// Stretches the system floating tab capsule to page content width (20pt side margins).
private struct TabBarContentWidthEnforcer: UIViewControllerRepresentable {
    var horizontalMargin: CGFloat

    func makeUIViewController(context: Context) -> TabBarMarginController {
        TabBarMarginController(horizontalMargin: horizontalMargin)
    }

    func updateUIViewController(_ controller: TabBarMarginController, context: Context) {
        controller.horizontalMargin = horizontalMargin
        controller.applyMarginsIfNeeded()
    }
}

private final class TabBarMarginController: UIViewController {
    var horizontalMargin: CGFloat

    init(horizontalMargin: CGFloat) {
        self.horizontalMargin = horizontalMargin
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyMarginsIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyMarginsIfNeeded()
    }

    func applyMarginsIfNeeded() {
        guard let window = view.window ?? keyWindow else { return }
        guard let tabBar = Self.findTabBar(in: window) else { return }
        guard let chrome = tabBar.superview else { return }

        let targetWidth = chrome.bounds.width - (horizontalMargin * 2)
        guard targetWidth > 0 else { return }

        var frame = tabBar.frame
        let currentInset = (chrome.bounds.width - frame.width) / 2
        if abs(currentInset - horizontalMargin) < 0.5,
           abs(frame.width - targetWidth) < 0.5 {
            return
        }

        frame.origin.x = horizontalMargin
        frame.size.width = targetWidth
        tabBar.frame = frame

        for sibling in chrome.subviews where sibling !== tabBar {
            let looksLikeChrome =
                abs(sibling.frame.midY - tabBar.frame.midY) < 40
                && sibling.frame.width > chrome.bounds.width * 0.3
            guard looksLikeChrome else { continue }
            var siblingFrame = sibling.frame
            siblingFrame.origin.x = horizontalMargin
            siblingFrame.size.width = targetWidth
            sibling.frame = siblingFrame
        }
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func findTabBar(in root: UIView) -> UITabBar? {
        if let tabBar = root as? UITabBar { return tabBar }
        for subview in root.subviews {
            if let tabBar = findTabBar(in: subview) { return tabBar }
        }
        return nil
    }
}

struct PlaceholderTabView: View {
    let title: String
    let imageName: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Color(hex: 0x121212).opacity(0.35))
                Text(title)
                    .font(.nytFranklin(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x121212))
                Text(message)
                    .font(.nytFranklin(size: 15))
                    .foregroundStyle(Color(hex: 0x666666))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MainTabView()
}
