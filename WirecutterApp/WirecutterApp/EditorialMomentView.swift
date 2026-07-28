import SwiftUI

/// Pushed editorial destination for a watchlist / specialty moment.
/// Same navigation chrome pattern as gift profiles; article body loads in-page.
struct EditorialMomentView: View {
    let moment: WatchlistEditorialMoment
    var onBack: () -> Void
    var onSearch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .background(Color(.systemBackground))

            Text(moment.label)
                .font(.nytFranklin(.medium, size: 28))
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PageChrome.horizontalMargin)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))

            ArticleWebView(url: moment.articleURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
