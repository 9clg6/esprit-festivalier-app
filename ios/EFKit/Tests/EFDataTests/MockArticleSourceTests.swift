import Testing
import EFDomain
import EFData

@Suite struct MockArticleSourceTests {
    private let articleSource: any ArticleSource = MockArticleSource()

    @Test func withoutACategoryEveryDemoArticleIsReturned() async throws {
        let articles = try await articleSource.articles(category: nil)

        #expect(!articles.isEmpty)
    }

    @Test func theDemoArticlesCoverSeveralCategories() async throws {
        // Otherwise filtering by category could not be told apart from no filter.
        let categories = Set(try await articleSource.articles(category: nil).map(\.category))

        #expect(categories.count >= 2)
    }

    @Test func filteringByACategoryReturnsAllTheArticlesOfThatCategoryAndNoOther() async throws {
        let all = try await articleSource.articles(category: nil)
        try #require(!all.isEmpty, "the demo has no article")

        for category in Set(all.map(\.category)) {
            let filtered = try await articleSource.articles(category: category)

            #expect(!filtered.isEmpty, "\(category)")
            #expect(filtered.allSatisfy { $0.category == category }, "\(category)")
            #expect(filtered.count == all.filter { $0.category == category }.count, "\(category)")
        }
    }
}
