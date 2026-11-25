import Foundation
import Testing
import EFDomain
import EFData

// What E10 needs from any article source, mock or real feed (NFR-008: the
// screens only see `any ArticleSource`). The RSS source reads the trimmed copy
// of the site's real feed (Fixtures/feed.xml).

enum ArticleSourceUnderTest: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case mock
    case rss

    var testDescription: String { rawValue }

    func make() throws -> any ArticleSource {
        switch self {
        case .mock:
            return MockArticleSource()
        case .rss:
            let feed = try RSSFeedFixture.siteFeed()
            return RSSArticleSource(load: { feed })
        }
    }
}

@Suite struct ArticleSourceContractTests {
    @Test(arguments: ArticleSourceUnderTest.allCases)
    func withoutACategoryEveryArticleIsReturned(_ subject: ArticleSourceUnderTest) async throws {
        let articles = try await subject.make().articles(category: nil)

        #expect(!articles.isEmpty)
    }

    @Test(arguments: ArticleSourceUnderTest.allCases)
    func theSampleCoversSeveralCategories(_ subject: ArticleSourceUnderTest) async throws {
        // Otherwise filtering by category could not be told apart from no filter.
        let categories = Set(try await subject.make().articles(category: nil).map(\.category))

        #expect(categories.count >= 2)
    }

    @Test(arguments: ArticleSourceUnderTest.allCases)
    func filteringByACategoryReturnsAllTheArticlesOfThatCategoryAndNoOther(
        _ subject: ArticleSourceUnderTest
    ) async throws {
        let source = try subject.make()
        let all = try await source.articles(category: nil)
        try #require(!all.isEmpty, "the sample has no article")

        for category in Set(all.map(\.category)) {
            let filtered = try await source.articles(category: category)

            #expect(!filtered.isEmpty, "\(category)")
            #expect(filtered.allSatisfy { $0.category == category }, "\(category)")
            #expect(filtered.count == all.filter { $0.category == category }.count, "\(category)")
        }
    }

    @Test(arguments: ArticleSourceUnderTest.allCases)
    func theNewestArticleComesFirst(_ subject: ArticleSourceUnderTest) async throws {
        let dates = try await subject.make().articles(category: nil).map(\.publishedAt)

        #expect(dates == dates.sorted(by: >))
    }

    @Test(arguments: ArticleSourceUnderTest.allCases)
    func aCategoryWithNoArticleGivesAnEmptyList(_ subject: ArticleSourceUnderTest) async throws {
        let none = try await subject.make().articles(category: Article.Category(rawValue: "Rubrique inconnue"))

        #expect(none.isEmpty)
    }
}
