import Foundation
import Testing
import EFDomain

// STORY-016 / FR-005 "Lien billetterie suivi": the "Billets" button opens the official
// ticket office with tracking parameters; without a known link there is no button.
//   utm_source=esprit-festivalier-app, utm_medium=app, utm_campaign=festival-<id>
// Query items already in the link are kept; our utm_* replace any existing ones (never duplicated).
//
// STORY-015 / FR-004 "Itinéraire ouvre Plans": Apple Maps URL from the festival's coordinates and name:
//   https://maps.apple.com/?ll=<lat>,<lon>&q=<name, percent-encoded>

private func festival(
    id: String = "hellfest", name: String = "Hellfest",
    latitude: Double = 47.09583, longitude: Double = -1.26806,
    ticketURL: String? = nil
) -> Festival {
    Festival(
        id: id, name: name, city: "Clisson", latitude: latitude, longitude: longitude,
        startDate: .now, endDate: .now, website: URL(string: "https://www.hellfest.fr/")!, description: "",
        ticketURL: ticketURL.map { URL(string: $0)! }
    )
}

private func queryItems(_ url: URL?) -> [URLQueryItem] {
    url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
}

/// Every value of the query item `name` in `url`, in order.
private func values(_ name: String, in url: URL?) -> [String?] {
    queryItems(url).filter { $0.name == name }.map { $0.value }
}

@Suite struct TicketLinkTests {
    @Test func withoutATicketLinkThereIsNoLink() {
        #expect(TicketLink.url(for: festival(ticketURL: nil)) == nil)
    }

    @Test func theTicketLinkGetsTheThreeTrackingParameters() {
        let url = TicketLink.url(for: festival(ticketURL: "https://tickets.hellfest.fr/2027"))

        #expect(url?.absoluteString ==
            "https://tickets.hellfest.fr/2027?utm_source=esprit-festivalier-app&utm_medium=app&utm_campaign=festival-hellfest")
    }

    @Test func theCampaignNamesTheFestivalId() {
        let url = TicketLink.url(for: festival(id: "vieilles-charrues", ticketURL: "https://billetterie.example.org/"))

        #expect(values("utm_campaign", in: url) == ["festival-vieilles-charrues"])
    }

    @Test func existingQueryItemsAreKeptBeforeTheTrackingParameters() {
        let url = TicketLink.url(for: festival(ticketURL: "https://shop.example.org/event?id=42&lang=fr"))

        #expect(url?.absoluteString ==
            "https://shop.example.org/event?id=42&lang=fr&utm_source=esprit-festivalier-app&utm_medium=app&utm_campaign=festival-hellfest")
    }

    @Test func anExistingUtmSourceIsReplacedNotDuplicated() {
        let url = TicketLink.url(for: festival(ticketURL: "https://shop.example.org/event?utm_source=newsletter&lang=fr"))

        #expect(values("utm_source", in: url) == ["esprit-festivalier-app"])
        #expect(values("lang", in: url) == ["fr"])
    }

    @Test func existingUtmMediumAndCampaignAreReplacedToo() {
        let url = TicketLink.url(for: festival(
            ticketURL: "https://shop.example.org/event?utm_medium=email&utm_campaign=spring"
        ))

        #expect(values("utm_medium", in: url) == ["app"])
        #expect(values("utm_campaign", in: url) == ["festival-hellfest"])
        #expect(queryItems(url).count == 3)
    }

    @Test func theFragmentOfTheTicketLinkIsKept() {
        let url = TicketLink.url(for: festival(ticketURL: "https://shop.example.org/event#pass-3-jours"))

        #expect(url?.fragment == "pass-3-jours")
        #expect(url?.path == "/event")
    }
}

@Suite struct DirectionsLinkTests {
    @Test func directionsOpenAppleMapsOnTheFestivalCoordinates() {
        let url = Directions.appleMapsURL(for: festival())

        #expect(url.absoluteString == "https://maps.apple.com/?ll=47.09583,-1.26806&q=Hellfest")
    }

    @Test func spacesAndAccentsInTheNameArePercentEncoded() {
        let url = Directions.appleMapsURL(for: festival(
            name: "Les Eurockéennes", latitude: 47.686167, longitude: 6.8081694
        ))

        #expect(url.absoluteString == "https://maps.apple.com/?ll=47.686167,6.8081694&q=Les%20Eurock%C3%A9ennes")
    }

    @Test func anAmpersandInTheNameDoesNotBreakTheQuery() {
        let url = Directions.appleMapsURL(for: festival(name: "Rock & Folk"))

        #expect(values("q", in: url) == ["Rock & Folk"])
        #expect(queryItems(url).map { $0.name } == ["ll", "q"])
    }
}
