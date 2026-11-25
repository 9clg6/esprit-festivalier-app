import Foundation
import Testing
import EFDomain

// STORY-015 (E5 "Fiche festival", FR-004) and Clément's need (2026-11-25):
// every festival shows its image in the list and opens a detail page; images and
// descriptions come from the association's festival pages on esprit-festivalier.fr, credited.
// - Festival carries: imageURL, imageCredit, genres, pageURL (its page on the site), ticketURL.
// - FestivalDetail carries: summary (the "À propos" text) and practical info ("Infos pratiques").
// - Data published before these fields still decodes: missing keys give nil or an empty list.
// The existing `website` stays the festival's own site (no second `websiteURL` field).

private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder.decode(type, from: Data(json.utf8))
}

private let legacyFestivalJSON = """
{
  "id": "hellfest", "name": "Hellfest", "city": "Clisson",
  "latitude": 47.09583, "longitude": -1.26806,
  "startDate": "2027-06-17T00:00:00+02:00", "endDate": "2027-06-20T23:59:00+02:00",
  "website": "https://www.hellfest.fr/", "description": "Metal festival."
}
"""

private let fullFestivalJSON = """
{
  "id": "hellfest", "name": "Hellfest", "city": "Clisson",
  "latitude": 47.09583, "longitude": -1.26806,
  "startDate": "2027-06-17T00:00:00+02:00", "endDate": "2027-06-20T23:59:00+02:00",
  "website": "https://www.hellfest.fr/", "description": "Metal festival.",
  "imageURL": "https://esprit-festivalier.fr/wp-content/uploads/hellfest.jpg",
  "imageCredit": "Esprit Festivalier",
  "genres": ["Metal", "Rock"],
  "pageURL": "https://esprit-festivalier.fr/festival/hellfest/",
  "ticketURL": "https://tickets.hellfest.fr/"
}
"""

@Suite struct FestivalContentModelTests {
    @Test func aFestivalPublishedBeforeTheNewFieldsStillDecodes() throws {
        let festival = try decode(Festival.self, legacyFestivalJSON)

        #expect(festival.id == "hellfest")
        #expect(festival.imageURL == nil)
        #expect(festival.imageCredit == nil)
        #expect(festival.genres.isEmpty)
        #expect(festival.pageURL == nil)
        #expect(festival.ticketURL == nil)
    }

    @Test func aFestivalWithImageGenresAndLinksDecodesThem() throws {
        let festival = try decode(Festival.self, fullFestivalJSON)

        #expect(festival.imageURL == URL(string: "https://esprit-festivalier.fr/wp-content/uploads/hellfest.jpg"))
        #expect(festival.imageCredit == "Esprit Festivalier")
        #expect(festival.genres == ["Metal", "Rock"])
        #expect(festival.pageURL == URL(string: "https://esprit-festivalier.fr/festival/hellfest/"))
        #expect(festival.ticketURL == URL(string: "https://tickets.hellfest.fr/"))
        #expect(festival.website == URL(string: "https://www.hellfest.fr/"))
    }

    @Test func anExplicitNullImageDecodesAsNoImage() throws {
        let json = legacyFestivalJSON.replacingOccurrences(
            of: "\"description\": \"Metal festival.\"",
            with: "\"description\": \"Metal festival.\", \"imageURL\": null, \"imageCredit\": null, \"ticketURL\": null"
        )

        let festival = try decode(Festival.self, json)

        #expect(festival.imageURL == nil)
        #expect(festival.imageCredit == nil)
        #expect(festival.ticketURL == nil)
    }

    @Test func aFestivalSurvivesAnEncodeDecodeRoundTrip() throws {
        let festival = try decode(Festival.self, fullFestivalJSON)

        let again = try decoder.decode(Festival.self, from: encoder.encode(festival))

        #expect(again == festival)
    }

    @Test func aFestivalBuiltWithoutTheNewFieldsHasNoImageNoGenreNoLink() {
        let festival = Festival(
            id: "f", name: "F", city: "Rennes", latitude: 48.11, longitude: -1.68,
            startDate: .now, endDate: .now, website: URL(string: "https://example.org")!, description: ""
        )

        #expect(festival.imageURL == nil)
        #expect(festival.imageCredit == nil)
        #expect(festival.genres.isEmpty)
        #expect(festival.pageURL == nil)
        #expect(festival.ticketURL == nil)
    }

    @Test func aDetailPublishedBeforeSummaryAndPracticalInfoStillDecodes() throws {
        let json = """
        { "festival": \(legacyFestivalJSON), "stages": [], "performances": [] }
        """

        let detail = try decode(FestivalDetail.self, json)

        #expect(detail.summary == nil)
        #expect(detail.practicalInfo.isEmpty)
    }

    @Test func aDetailDecodesItsSummaryAndPracticalInfoInOrder() throws {
        let json = """
        {
          "festival": \(fullFestivalJSON), "stages": [], "performances": [],
          "summary": "Le rendez-vous metal de Clisson.",
          "practicalInfo": [
            { "title": "Navettes", "text": "Depuis la gare de Clisson." },
            { "title": "Objets interdits", "text": "Bouteilles en verre." }
          ]
        }
        """

        let detail = try decode(FestivalDetail.self, json)

        #expect(detail.summary == "Le rendez-vous metal de Clisson.")
        #expect(detail.practicalInfo == [
            PracticalInfo(title: "Navettes", text: "Depuis la gare de Clisson."),
            PracticalInfo(title: "Objets interdits", text: "Bouteilles en verre.")
        ])
    }

    @Test func aDetailBuiltWithoutSummaryHasNoSummaryAndNoPracticalInfo() throws {
        let festival = try decode(Festival.self, legacyFestivalJSON)

        let detail = FestivalDetail(festival: festival, stages: [], performances: [])

        #expect(detail.summary == nil)
        #expect(detail.practicalInfo.isEmpty)
    }
}
