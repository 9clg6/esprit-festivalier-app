import Foundation
import Testing
import EFDomain

// STORY-027 / FR-012 "Notifications d'articles", mock-first: no server push. A background refresh
// on the device fetches the RSS feed and compares it with the article ids already seen (a persisted set).
// Need:
// - notify the new articles in the categories the user follows (NotificationPreferences.articleCategories;
//   "Programmation" followed by default, nothing else), newest first;
// - at most 3 notifications per refresh: more than 3 new articles give one summary notification
//   "N nouveaux articles" instead (N = every new followed article);
// - first run (no seen set yet): nothing is notified, every article of the feed is recorded as seen;
// - every article of the feed is recorded as seen, followed category or not, so following a category
//   later does not notify old articles;
// - an empty feed keeps the seen set (a refresh with no article must not make old ones new again);
// - tapping an article notification opens that article (FR-012): the notification carries it.
//
// Assumed API (EFDomain):
//   enum ArticleNotification: Sendable, Hashable {
//     case article(Article)
//     case summary(count: Int)
//     var body: String   // .summary(count: 5) -> "5 nouveaux articles"
//   }
//   struct ArticleCheck: Sendable, Hashable {
//     let notifications: [ArticleNotification]
//     let seen: Set<Article.ID>   // to persist for the next refresh
//   }
//   enum NewArticles {
//     static let maxNotifications: Int  (3)
//     static func check(feed: [Article], seen: Set<Article.ID>?, preferences: NotificationPreferences)
//       -> ArticleCheck
//   }

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

private func article(
    _ id: String, _ category: Article.Category = .programmation, published: String = "2026-11-25T08:00:00+01:00"
) -> Article {
    Article(
        id: id, title: "Titre \(id)", link: URL(string: "https://esprit-festivalier.fr/\(id)/")!,
        category: category, author: "La rédaction", publishedAt: date(published), imageURL: nil
    )
}

private func check(
    _ feed: [Article], seen: Set<Article.ID>?, preferences: NotificationPreferences = NotificationPreferences()
) -> ArticleCheck {
    NewArticles.check(feed: feed, seen: seen, preferences: preferences)
}

private func notifiedIds(_ result: ArticleCheck) -> [Article.ID] {
    result.notifications.compactMap { notification -> Article.ID? in
        if case let .article(article) = notification { article.id } else { nil }
    }
}

@Suite struct NewArticlesFirstRunTests {
    @Test func theFirstRunNotifiesNothing() {
        let result = check([article("a"), article("b")], seen: nil)

        #expect(result.notifications.isEmpty)
    }

    @Test func theFirstRunRecordsEveryArticleAsSeen() {
        let result = check([article("a"), article("b", .actu)], seen: nil)

        #expect(result.seen == ["a", "b"])
    }

    @Test func anEmptySeenSetIsNotAFirstRun() {
        let result = check([article("a")], seen: [])

        #expect(notifiedIds(result) == ["a"])
    }
}

@Suite struct NewArticlesDetectionTests {
    @Test func nothingNewNotifiesNothing() {
        let result = check([article("a"), article("b")], seen: ["a", "b"])

        #expect(result.notifications.isEmpty)
        #expect(result.seen == ["a", "b"])
    }

    @Test func aNewArticleInAFollowedCategoryIsNotified() {
        let result = check([article("new"), article("old")], seen: ["old"])

        #expect(notifiedIds(result) == ["new"])
    }

    @Test func theNotificationCarriesTheArticleToOpen() {
        let new = article("new")

        let result = check([new], seen: ["old"])

        #expect(result.notifications == [.article(new)])
    }

    @Test func aNewArticleInAnUnfollowedCategoryIsNotNotified() {
        let result = check([article("live", .liveReport)], seen: ["old"])

        #expect(result.notifications.isEmpty)
    }

    @Test func anUnfollowedNewArticleIsStillRecordedAsSeen() {
        let result = check([article("live", .liveReport)], seen: ["old"])

        #expect(result.seen.contains("live"))
    }

    @Test func followingACategoryLaterDoesNotNotifyItsOldArticles() {
        let feed = [article("live", .liveReport)]
        let first = check(feed, seen: ["old"])

        let later = check(feed, seen: first.seen, preferences: NotificationPreferences(articleCategories: [.liveReport]))

        #expect(later.notifications.isEmpty)
    }

    @Test func everyFollowedCategoryIsNotified() {
        let preferences = NotificationPreferences(articleCategories: [.interview, .liveReport])
        let feed = [article("itw", .interview), article("live", .liveReport), article("prog", .programmation)]

        let result = check(feed, seen: ["old"], preferences: preferences)

        #expect(Set(notifiedIds(result)) == ["itw", "live"])
    }

    @Test func noFollowedCategoryNotifiesNothing() {
        let result = check([article("a")], seen: ["old"], preferences: NotificationPreferences(articleCategories: []))

        #expect(result.notifications.isEmpty)
        #expect(result.seen.contains("a"))
    }

    @Test func newArticlesComeNewestFirst() {
        let feed = [
            article("middle", published: "2026-11-25T09:00:00+01:00"),
            article("oldest", published: "2026-11-25T08:00:00+01:00"),
            article("newest", published: "2026-11-25T10:00:00+01:00")
        ]

        let result = check(feed, seen: ["old"])

        #expect(notifiedIds(result) == ["newest", "middle", "oldest"])
    }

    @Test func theNewSeenSetHoldsTheWholeFeed() {
        let result = check([article("a"), article("b", .actu)], seen: ["old"])

        #expect(result.seen.isSuperset(of: ["a", "b"]))
    }

    @Test func anEmptyFeedKeepsTheSeenSet() {
        let result = check([], seen: ["a", "b"])

        #expect(result.notifications.isEmpty)
        #expect(result.seen == ["a", "b"])
    }

    @Test func aSecondRefreshDoesNotNotifyTheSameArticleAgain() {
        let feed = [article("new")]
        let first = check(feed, seen: ["old"])

        let second = check(feed, seen: first.seen)

        #expect(second.notifications.isEmpty)
    }
}

@Suite struct NewArticlesCapTests {
    private func newArticles(_ count: Int) -> [Article] {
        (1...count).map { article("a\($0)", published: "2026-11-25T\(String(format: "%02d", $0)):00:00+01:00") }
    }

    @Test func atMostThreeNotificationsPerRefresh() {
        #expect(NewArticles.maxNotifications == 3)
    }

    @Test func threeNewArticlesGiveThreeNotifications() {
        let result = check(newArticles(3), seen: ["old"])

        #expect(notifiedIds(result) == ["a3", "a2", "a1"])
    }

    @Test func fourNewArticlesGiveOneSummary() {
        let result = check(newArticles(4), seen: ["old"])

        #expect(result.notifications == [.summary(count: 4)])
    }

    @Test func theSummaryCountsEveryNewFollowedArticle() {
        let feed = newArticles(7) + [article("live", .liveReport)]

        let result = check(feed, seen: ["old"])

        #expect(result.notifications == [.summary(count: 7)])
    }

    @Test func unfollowedArticlesDoNotTipIntoASummary() {
        let feed = newArticles(3) + [article("live", .liveReport), article("actu", .actu)]

        let result = check(feed, seen: ["old"])

        #expect(notifiedIds(result) == ["a3", "a2", "a1"])
    }

    @Test func aSummaryStillRecordsEveryArticleAsSeen() {
        let result = check(newArticles(5), seen: ["old"])

        #expect(result.seen.isSuperset(of: Set((1...5).map { "a\($0)" })))
    }

    @Test func theSummaryBodySaysHowMany() {
        #expect(ArticleNotification.summary(count: 5).body == "5 nouveaux articles")
    }
}
