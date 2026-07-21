import SwiftUI

struct GenaiSearchView: View {
    @State private var query = ""
    @State private var response: GenaiSearchResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var safariItem: IdentifiableURL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    searchField
                    content
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
            .sheet(item: $safariItem) { item in
                SafariView(url: item.url)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Ask Wirecutter anything…", text: $query)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit { performSearch() }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button("Search") { performSearch() }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            HStack {
                Spacer()
                ProgressView("Searching…")
                Spacer()
            }
            .padding(.top, 40)
        } else if let error = errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if let response {
            answerSection(response.answer)
            articlesSection(response.articles)
            productsSection(response.products)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Ask about products, recommendations, or comparisons")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Answer Section

    private func answerSection(_ answer: SearchAnswer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Answer", systemImage: "sparkles")
                .font(.headline)
            Text(answer.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if !answer.citations.isEmpty {
                Text("Sources: \(answer.citations.map { String($0) }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Articles Section

    private func articlesSection(_ articles: [SearchArticle]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if articles.isEmpty { EmptyView() } else {
                Text("Articles")
                    .font(.headline)

                ForEach(articles) { article in
                    Button {
                        safariItem = IdentifiableURL(url: article.url)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            if let imageUrl = article.imageUrl {
                                AsyncImage(url: imageUrl) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Color(.systemGray5)
                                    }
                                }
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                if let summary = article.summary {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                if let date = article.publishedDate {
                                    Text(date)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Products Section

    private func productsSection(_ products: [SearchProduct]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if products.isEmpty { EmptyView() } else {
                Text("Products")
                    .font(.headline)

                ForEach(products) { product in
                    Button {
                        if let url = product.affiliateUrl {
                            safariItem = IdentifiableURL(url: url)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    if let price = product.priceFormatted {
                                        Text(price)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                    if let merchant = product.merchantName {
                                        Text("at \(merchant)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            if product.affiliateUrl != nil {
                                Image(systemName: "cart")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(product.affiliateUrl == nil)
                }
            }
        }
    }

    // MARK: - Actions

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        response = nil

        Task {
            do {
                let result = try await SearchAPIClient.shared.search(query: trimmed)
                response = result
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    GenaiSearchView()
}
