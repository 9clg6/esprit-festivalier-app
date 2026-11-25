import Foundation
import Testing
import EFDomain

// STORY-012: the region filter needs `Festival.region` (optional; data published without it still decodes).
// Assumed API: Festival(id:name:city:region:latitude:...) with `region: String? = nil`.

@Suite struct FestivalRegionTests {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func json(region: String?) -> Data {
        let regionField = region.map { #", "region": "\#($0)""# } ?? ""
        return Data("""
        {
          "id": "hellfest", "name": "Hellfest", "city": "Clisson"\(regionField),
          "latitude": 47.09583, "longitude": -1.26806,
          "startDate": "2027-06-17T00:00:00+02:00", "endDate": "2027-06-20T23:59:00+02:00",
          "website": "https://www.hellfest.fr/", "description": "Metal festival."
        }
        """.utf8)
    }

    @Test func aFestivalDecodesItsRegion() throws {
        let festival = try decoder.decode(Festival.self, from: json(region: "Pays de la Loire"))

        #expect(festival.region == "Pays de la Loire")
    }

    @Test func aFestivalPublishedWithoutRegionStillDecodes() throws {
        let festival = try decoder.decode(Festival.self, from: json(region: nil))

        #expect(festival.region == nil)
    }

    @Test func theRegionSurvivesARoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let festival = try decoder.decode(Festival.self, from: json(region: "Bretagne"))

        let again = try decoder.decode(Festival.self, from: encoder.encode(festival))

        #expect(again == festival)
        #expect(again.region == "Bretagne")
    }

    @Test func aFestivalBuiltWithoutRegionHasNone() {
        let festival = Festival(
            id: "x", name: "X", city: "Lyon", latitude: 45.76, longitude: 4.83,
            startDate: .now, endDate: .now, website: URL(string: "https://example.org")!, description: ""
        )

        #expect(festival.region == nil)
    }
}
