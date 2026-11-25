import Foundation
import Testing
import EFDomain

// STORY-024 / E12 Profil "notifications (par type)", FR-010 "Chaque type de notification se coupe dans
// les réglages", FR-012 "Aucune rubrique activée par défaut, sauf « Programmations »".
// Mock-first: the preferences stay on the device (no PUT /v1/devices yet), persisted as JSON.
//
// Assumed API (EFDomain):
//   struct NotificationPreferences: Sendable, Hashable, Codable {
//     var festivalJ7: Bool                          // default true
//     var festivalJ1: Bool                          // default true
//     var articleCategories: Set<Article.Category>  // default [.programmation]
//     init(festivalJ7: Bool = true, festivalJ1: Bool = true,
//          articleCategories: Set<Article.Category> = [.programmation])
//   }

@Suite struct NotificationPreferencesDefaultsTests {
    @Test func j7RemindersAreOnByDefault() {
        #expect(NotificationPreferences().festivalJ7)
    }

    @Test func j1RemindersAreOnByDefault() {
        #expect(NotificationPreferences().festivalJ1)
    }

    @Test func onlyProgrammationsAreFollowedByDefault() {
        #expect(NotificationPreferences().articleCategories == [.programmation])
    }

    @Test(arguments: Article.Category.known.filter { $0 != .programmation })
    func otherCategoriesAreOffByDefault(category: Article.Category) {
        #expect(!NotificationPreferences().articleCategories.contains(category))
    }
}

@Suite struct NotificationPreferencesCodingTests {
    @Test func theDefaultsRoundTrip() throws {
        let preferences = NotificationPreferences()

        let data = try JSONEncoder().encode(preferences)

        #expect(try JSONDecoder().decode(NotificationPreferences.self, from: data) == preferences)
    }

    @Test func changedPreferencesRoundTrip() throws {
        let preferences = NotificationPreferences(
            festivalJ7: false, festivalJ1: true, articleCategories: [.liveReport, .interview]
        )

        let data = try JSONEncoder().encode(preferences)

        #expect(try JSONDecoder().decode(NotificationPreferences.self, from: data) == preferences)
    }

    @Test func aCategoryUnknownToTheAppRoundTrips() throws {
        // The site adds sections (Article.Category is an open set).
        let preferences = NotificationPreferences(articleCategories: [Article.Category(rawValue: "Podcast")])

        let data = try JSONEncoder().encode(preferences)

        #expect(try JSONDecoder().decode(NotificationPreferences.self, from: data) == preferences)
    }

    @Test func savedPreferencesMissingAFieldGetItsDefault() throws {
        // Preferences saved by an older build, before a field existed.
        let data = Data(#"{"festivalJ7": false}"#.utf8)

        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        #expect(decoded == NotificationPreferences(festivalJ7: false))
    }
}
