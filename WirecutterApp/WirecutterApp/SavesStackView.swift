import SwiftUI

/// A profile or custom list that appears as a folder on the Saves tab.
struct SavesFolder: Identifiable, Hashable {
    let id: String
    let name: String
}

enum SavesFolderStore {
    /// Personal / custom save lists shown under “My Saves”.
    static let mySaves: [SavesFolder] = [
        SavesFolder(id: "list-gifts", name: "Gifts"),
        SavesFolder(id: "list-kitchen", name: "Kitchen"),
        SavesFolder(id: "list-travel", name: "Travel"),
    ]

    /// Gift-recipient profiles shown under “Gift Profiles”.
    static let giftProfiles: [SavesFolder] = PersonProfileStore.prototypes.map {
        SavesFolder(id: $0.id, name: $0.name)
    }

    static var all: [SavesFolder] { mySaves + giftProfiles }
}

/// Saves tab root: folder index → per-folder list of saved products.
struct SavesStackView: View {
    @Binding var selectedTab: AppTab
    @State private var path = NavigationPath()
    @State private var showAsk = false
    @ObservedObject private var savedStore = SavedStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            SavesFoldersView(
                mySaves: SavesFolderStore.mySaves,
                giftProfiles: SavesFolderStore.giftProfiles,
                onSelect: { folder in path.append(folder) },
                onSearch: { showAsk = true }
            )
            .navigationDestination(for: SavesFolder.self) { folder in
                SavesListView(folder: folder)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showAsk) {
            AskSheetView()
                .presentationDetents([.large])
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .saves {
                path = NavigationPath()
            }
        }
        .task {
            await seedDemoSavesIfNeeded()
        }
    }

    private func seedDemoSavesIfNeeded() async {
        do {
            let result = try await APIClient.shared.fetchCommerceFeed()
            let candidates = result.products + result.shopifyProducts
            for folder in SavesFolderStore.all {
                savedStore.seedDemoIfNeeded(profileID: folder.id, from: candidates)
            }
        } catch {
            // Demo seeds are best-effort; list views still work with empty state.
        }
    }
}

// MARK: - Folder index (My Saves + Gift Profiles)

struct SavesFoldersView: View {
    let mySaves: [SavesFolder]
    let giftProfiles: [SavesFolder]
    var onSelect: (SavesFolder) -> Void
    var onSearch: () -> Void = {}
    /// Placeholder for the future create-list / setup flow.
    var onAddMySave: () -> Void = {}
    var onAddGiftProfile: () -> Void = {}

    private let grayBackground = Color(hex: 0xEEEEEE)

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Paint gray into the status-bar region as real scroll content.
                    // ignoresSafeArea alone is unreliable inside NavigationStack + TabView.
                    grayBackground
                        .frame(height: geo.safeAreaInsets.top)
                        .frame(maxWidth: .infinity)

                    mySavesSection

                    // Natural-height white block; page background carries white to the bottom.
                    VStack(alignment: .leading, spacing: 0) {
                        // 44pt white gap after the gray block ends.
                        Color.clear
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)

                        giftProfilesSection
                    }
                    .padding(.bottom, 120)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // White fills the screen (and bottom bounce). Gray only for top intro / top bounce.
        .background {
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()
                grayBackground
                    .frame(height: 320)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: My Saves (gray)

    private var mySavesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            savesHeader

            sectionLabel("My Saves")
                .padding(.top, 24)
                .padding(.horizontal, PageChrome.horizontalMargin)

            savesNameList(folders: mySaves, onAdd: onAddMySave)
                .padding(.top, 32)
                .padding(.horizontal, PageChrome.horizontalMargin)
                // Gray extends 44pt beyond the final list item.
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(grayBackground)
    }

    // MARK: Gift Profiles (white)

    private var giftProfilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Gift Profiles")
                .padding(.horizontal, PageChrome.horizontalMargin)

            savesNameList(folders: giftProfiles, onAdd: onAddGiftProfile)
                .padding(.top, 32)
                .padding(.horizontal, PageChrome.horizontalMargin)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.nytFranklin(.medium, size: 16))
            .foregroundStyle(Color(hex: 0x666666))
    }

    private func savesNameList(folders: [SavesFolder], onAdd: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: onAdd) {
                Text("+ New")
                    .font(.nytFranklin(size: 24, weight: .medium))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create new list")

            ForEach(folders) { folder in
                Button {
                    onSelect(folder)
                } label: {
                    Text(folder.name)
                        .font(.nytFranklin(.light, size: 24))
                        .foregroundStyle(Color(.label))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(folder.name) saves")
            }
        }
    }

    // MARK: Top chrome (search + actions)

    private var savesHeader: some View {
        HStack(alignment: .center, spacing: 16) {
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
                .background(Color.white)
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
}

// MARK: - Pocketed: rounded-square folder grid
// Swap `SavesFoldersView` body to use this if we want the avatar-tile layout back.

struct SavesFoldersSquareGridView: View {
    let folders: [SavesFolder]
    var onSelect: (SavesFolder) -> Void
    var onAdd: () -> Void = {}

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 20),
        count: 3
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Saves")
                    .font(.nytFranklin(.medium, size: 28))
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 32)
                    .padding(.horizontal, PageChrome.horizontalMargin)

                LazyVGrid(columns: columns, spacing: 28) {
                    Button(action: onAdd) {
                        addFolderCell
                    }
                    .buttonStyle(.plain)

                    ForEach(folders) { folder in
                        Button {
                            onSelect(folder)
                        } label: {
                            folderCell(folder)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PageChrome.horizontalMargin)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
    }

    private var addFolderCell: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: 0xEEEEEE))
                    .frame(width: 96, height: 96)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(hex: 0xCCCCCC), lineWidth: 1)
                    }

                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.black)
            }

            Text("New")
                .font(.nytFranklin(.medium, size: 15))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel("Create new list")
        .accessibilityAddTraits(.isButton)
    }

    private func folderCell(_ folder: SavesFolder) -> some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AvatarStyle.backgroundColor(for: folder.name))
                    .frame(width: 96, height: 96)

                Image(AvatarStyle.assetName(for: folder.name))
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 96, height: 96)
                    .scaleEffect(0.65)
                    .frame(width: 96, height: 96)
                    .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(folder.name)
                .font(.nytFranklin(.medium, size: 15))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.name) saves")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Folder list

struct SavesListView: View {
    let folder: SavesFolder

    @ObservedObject private var savedStore = SavedStore.shared
    @State private var safariItem: IdentifiableURL?
    @State private var quickViewItem: CommerceItem?

    private var products: [CommerceItem] {
        savedStore.items(for: folder.id)
    }

    var body: some View {
        Group {
            if products.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(products) { item in
                            ProductCardView(
                                item: item,
                                onTap: { quickViewItem = item },
                                isSaved: true,
                                onBookmarkTap: {
                                    savedStore.toggle(item, for: folder.id)
                                }
                            )
                            .padding(.horizontal, PageChrome.horizontalMargin)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color(hex: 0x121212).opacity(0.35))
            Text("No saves yet")
                .font(.nytFranklin(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: 0x121212))
            Text("Items you save for \(folder.name) will show up here.")
                .font(.nytFranklin(size: 15))
                .foregroundStyle(Color(hex: 0x666666))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
