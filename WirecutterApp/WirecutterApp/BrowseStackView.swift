import SwiftUI

/// Browse tab root: home feed + pushed profile pages. Retapping Browse pops to home.
struct BrowseStackView: View {
    @Binding var selectedTab: AppTab
    @State private var path = NavigationPath()
    @State private var showAsk = false

    var body: some View {
        NavigationStack(path: $path) {
            CommerceListView(
                people: PersonProfileStore.prototypes,
                onSelectPerson: { profile in
                    path.append(profile)
                },
                onSelectEditorial: { moment in
                    path.append(moment)
                },
                onViewAllWatchlist: {
                    selectedTab = .account
                },
                onSearch: { showAsk = true }
            )
            .navigationDestination(for: PersonProfile.self) { profile in
                ProfileView(
                    profile: profile,
                    onBack: { path.removeLast() },
                    onSearch: { showAsk = true },
                    onOpenSaved: {
                        path.append(SavesFolder(id: profile.id, name: profile.name))
                    }
                )
            }
            .navigationDestination(for: WatchlistEditorialMoment.self) { moment in
                EditorialMomentView(
                    moment: moment,
                    onBack: { path.removeLast() },
                    onSearch: { showAsk = true }
                )
            }
            .navigationDestination(for: SavesFolder.self) { folder in
                SavesListView(folder: folder)
            }
        }
        .sheet(isPresented: $showAsk) {
            AskSheetView()
                .presentationDetents([.large])
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .browse {
                path = NavigationPath()
            }
        }
        .background {
            BrowseTabReselectObserver {
                path = NavigationPath()
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
    }
}

/// Fires when the already-selected Browse tab is tapped again.
private struct BrowseTabReselectObserver: UIViewControllerRepresentable {
    var onReselect: () -> Void

    func makeUIViewController(context: Context) -> ProbeController {
        ProbeController(onReselect: onReselect)
    }

    func updateUIViewController(_ controller: ProbeController, context: Context) {
        controller.onReselect = onReselect
    }

    final class ProbeController: UIViewController, UITabBarControllerDelegate {
        var onReselect: () -> Void
        private weak var observedTabBarController: UITabBarController?

        init(onReselect: @escaping () -> Void) {
            self.onReselect = onReselect
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachIfNeeded()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            attachIfNeeded()
        }

        private func attachIfNeeded() {
            guard let tabBarController = findTabBarController() else { return }
            guard observedTabBarController !== tabBarController else { return }
            observedTabBarController = tabBarController
            // Keep any existing delegate chain if present by only setting when nil,
            // otherwise wrap isn't available — for this app we own the tab controller.
            tabBarController.delegate = self
        }

        private func findTabBarController() -> UITabBarController? {
            var current: UIViewController? = parent ?? self
            while let c = current {
                if let tab = c as? UITabBarController { return tab }
                current = c.parent
            }
            var responder: UIResponder? = view
            while let r = responder {
                if let tab = r as? UITabBarController { return tab }
                responder = r.next
            }
            return nil
        }

        func tabBarController(
            _ tabBarController: UITabBarController,
            shouldSelect viewController: UIViewController
        ) -> Bool {
            if tabBarController.selectedViewController === viewController {
                // Reselect of current tab — pop Browse stack when Browse is selected.
                if tabBarController.selectedIndex == 0 {
                    onReselect()
                }
            }
            return true
        }
    }
}
