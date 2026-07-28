import SwiftUI

/// Floating glass tab bar matching Rocky Road Figma (`29:19611` / `38:10270` / `38:10271`).
///
/// Interaction model (iOS 26 Liquid Glass):
/// - Outer capsule uses interactive glass (press / hold lighting + finger tracking)
/// - Selected tab uses a sliding / morphing glass pill (`glassEffectID`)
/// - Dragging horizontally across the bar scrubs selection under the finger
struct GlassTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var selectionNamespace

    @State private var barWidth: CGFloat = 0

    private let selectionFill = Color(hex: 0xEDEDED)
    private let labelColor = Color(hex: 0x121212)
    private let selectionInset: CGFloat = 4

    private var selectionAnimation: Animation {
        .spring(response: 0.32, dampingFraction: 0.88)
    }

    var body: some View {
        tabRow
            .padding(selectionInset)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { barWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, width in
                            barWidth = width
                        }
                }
            }
            .modifier(OuterGlassChrome())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.35),
                                Color.black.opacity(0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.12), radius: 40, x: 0, y: 8)
            // Scrub between tabs: selection follows the finger.
            .simultaneousGesture(tabScrubGesture)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Tab bar")
    }

    private var tabRow: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private var tabScrubGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard barWidth > 0 else { return }
                let tab = tab(atX: value.location.x, width: barWidth)
                guard tab != selection else { return }
                withAnimation(selectionAnimation) {
                    selection = tab
                }
            }
    }

    private func tab(atX x: CGFloat, width: CGFloat) -> AppTab {
        let tabs = AppTab.allCases
        let clamped = min(max(0, x), width - 0.001)
        let index = min(tabs.count - 1, Int((clamped / width) * CGFloat(tabs.count)))
        return tabs[index]
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(selectionAnimation) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(tab.imageName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)

                Text(tab.title)
                    .font(.nytFranklin(size: 10, weight: .semibold))
                    .tracking(-0.1)
                    .lineLimit(1)
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 7)
            .padding(.horizontal, 8)
            // Selection behind labels (background can't cover icon/text).
            .background {
                if selection == tab {
                    selectionIndicator
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    /// Gray selected pill. Uses matched geometry for the slide; Liquid Glass
    /// morph on the pill itself is avoided — it was blanking labels/selection.
    /// Press/drag liquid response comes from the outer interactive chrome + scrub.
    private var selectionIndicator: some View {
        Capsule()
            .fill(selectionFill)
            .matchedGeometryEffect(id: "tabSelection", in: selectionNamespace)
    }
}

// MARK: - Outer capsule chrome

private struct OuterGlassChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Interactive outer glass: press / hold / drag lighting on the bar.
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background {
                Capsule()
                    .fill(.regularMaterial)
            }
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(i.isMultiple(of: 2) ? Color.orange.opacity(0.5) : Color.blue.opacity(0.45))
                        .frame(height: 180)
                        .overlay(Text("Card \(i)").bold())
                }
            }
            .padding()
            .padding(.bottom, 100)
        }

        GlassTabBar(selection: .constant(.browse))
            .padding(25)
            .ignoresSafeArea(.container, edges: .bottom)
    }
}
