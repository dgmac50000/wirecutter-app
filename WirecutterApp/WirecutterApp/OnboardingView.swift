import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: PreferencesStore
    @State private var currentStep = 0
    @State private var selectedCategories: Set<String> = []
    @State private var selectedBudget: BudgetRange = .moderate
    @State private var selectedContexts: Set<String> = []

    let onComplete: () -> Void

    private let totalSteps = 4

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                if currentStep > 0 && currentStep < totalSteps - 1 {
                    progressBar
                        .padding(.top, 8)
                }

                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    categoriesStep.tag(1)
                    budgetStep.tag(2)
                    allSetStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(1..<totalSteps - 1, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.black : Color(.systemGray4))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image("WirecutterLogo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)

                Text("Find the best\nstuff, faster.")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Tell us what you\u{2019}re into and we\u{2019}ll\npersonalize your recommendations.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation { currentStep = 1 }
                } label: {
                    Text("Get started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    skipOnboarding()
                } label: {
                    Text("Skip for now")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 1: Categories

    private var categoriesStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you\nshopping for?")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .lineSpacing(2)
                Text("Pick as many as you like.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ForEach(OnboardingCategory.all) { category in
                        CategoryPill(
                            category: category,
                            isSelected: selectedCategories.contains(category.id),
                            onTap: {
                                if selectedCategories.contains(category.id) {
                                    selectedCategories.remove(category.id)
                                } else {
                                    selectedCategories.insert(category.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }

            Spacer(minLength: 0)

            bottomBar(
                canContinue: !selectedCategories.isEmpty,
                onNext: { withAnimation { currentStep = 2 } }
            )
        }
    }

    // MARK: - Step 2: Budget + Context

    private var budgetStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Budget section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What\u{2019}s your\nbudget style?")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .lineSpacing(2)
                        Text("We\u{2019}ll prioritize picks that match.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 10) {
                        ForEach(BudgetRange.allCases) { budget in
                            BudgetRow(
                                budget: budget,
                                isSelected: selectedBudget == budget,
                                onTap: { selectedBudget = budget }
                            )
                        }
                    }

                    // Context section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What brings you here?")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                        Text("Optional \u{2014} helps us make better picks.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        ForEach(ShoppingContext.all) { ctx in
                            ContextRow(
                                context: ctx,
                                isSelected: selectedContexts.contains(ctx.id),
                                onTap: {
                                    if selectedContexts.contains(ctx.id) {
                                        selectedContexts.remove(ctx.id)
                                    } else {
                                        selectedContexts.insert(ctx.id)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }

            Spacer(minLength: 0)

            bottomBar(
                canContinue: true,
                onNext: {
                    store.completeOnboarding(
                        categories: Array(selectedCategories),
                        budget: selectedBudget,
                        context: Array(selectedContexts)
                    )
                    withAnimation { currentStep = 3 }
                }
            )
        }
    }

    // MARK: - Step 3: All Set

    private var allSetStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xF0EEFF))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color(hex: 0x5B69EB))
                }

                Text("You\u{2019}re all set!")
                    .font(.system(size: 32, weight: .bold, design: .serif))

                Text("We\u{2019}ll show you personalized picks\nbased on your interests.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Show selected categories as pills
                if !selectedCategories.isEmpty {
                    WrappingHStack(items: selectedCategories.sorted()) { catId in
                        if let cat = OnboardingCategory.all.first(where: { $0.id == catId }) {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 11))
                                Text(cat.name)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onComplete()
                } label: {
                    Text("Start exploring")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Shared Components

    private func bottomBar(canContinue: Bool, onNext: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if currentStep > 0 {
                    Button {
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.label))
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }

                Spacer()

                Button {
                    onNext()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(canContinue ? Color.black : Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canContinue)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    private func skipOnboarding() {
        store.completeOnboarding(categories: [], budget: .noPreference, context: [])
        onComplete()
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let category: OnboardingCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .white : Color(hex: hexValue))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color(hex: hexValue) : Color(hex: hexValue).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(category.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(.label))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: hexValue))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: hexValue).opacity(0.08) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: hexValue) : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var hexValue: UInt {
        UInt(category.color, radix: 16) ?? 0x333333
    }
}

// MARK: - Budget Row

private struct BudgetRow: View {
    let budget: BudgetRange
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.black : Color(.systemGray4), lineWidth: isSelected ? 6 : 2)
                        .frame(width: 22, height: 22)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(.label))
                    Text(budget.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? Color(.systemGray6) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.black : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Context Row

private struct ContextRow: View {
    let context: ShoppingContext
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 12) {
                Image(systemName: context.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color(hex: 0x5B69EB) : .secondary)
                    .frame(width: 24)

                Text(context.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(.label))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0x5B69EB))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: 0x5B69EB).opacity(0.06) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: 0x5B69EB) : Color(.systemGray4), lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wrapping HStack (flow layout for pills)

private struct WrappingHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, 6)
                    .padding(.bottom, 6)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}
