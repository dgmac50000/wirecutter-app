import SwiftUI

@main
struct WirecutterAppApp: App {
    @StateObject private var prefsStore = PreferencesStore()

    var body: some Scene {
        WindowGroup {
            if prefsStore.hasCompletedOnboarding {
                CommerceListView()
            } else {
                OnboardingView(store: prefsStore) {
                    // Onboarding complete — main feed will appear
                }
            }
        }
    }
}
