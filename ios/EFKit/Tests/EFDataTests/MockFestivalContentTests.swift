import Foundation
import Testing
import EFDomain
import EFData

// Clément's need (2026-11-25): every festival shows its image in the list and opens a detail page.
// Images and descriptions come from the association's own festival pages on esprit-festivalier.fr
// (content of the association, credited). Rule: a festival with an image always names its credit.

private let source: any FestivalSource = MockFestivalSource()

// The association's page of each demo festival (from the need, sprint-1 dev notes).
private let expectedPages: [Festival.ID: String] = [
    "hellfest": "https://esprit-festivalier.fr/festival/hellfest/",
    "vieilles-charrues": "https://esprit-festivalier.fr/festival/les-vieilles-charrues/",
    "eurockeennes": "https://esprit-festivalier.fr/festival/les-eurockeennes-de-belfort/",
    "francofolies": "https://esprit-festivalier.fr/festival/francofolies/",
    "trans-musicales": "https://esprit-festivalier.fr/festival/trans-musicales/"
]

private func demoFestivals() async throws -> [Festival] {
    let festivals = try await source.festivals(updatedSince: nil)
    try #require(festivals.count == 5, "the demo should hold 5 festivals")
    return festivals
}

private func isBlank(_ text: String?) -> Bool {
    (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

@Suite struct MockFestivalContentTests {
    @Test func everyDemoFestivalHasAnHttpsImageFromTheAssociationSite() async throws {
        for festival in try await demoFestivals() {
            let url = try #require(festival.imageURL, "\(festival.id) has no image")
            #expect(url.scheme == "https", "\(festival.id) \(url)")
            #expect(url.host() == "esprit-festivalier.fr", "\(festival.id) \(url)")
        }
    }

    @Test func everyDemoFestivalShowsItsOwnImage() async throws {
        let images = try await demoFestivals().compactMap(\.imageURL)

        #expect(Set(images).count == 5)
    }

    @Test func aFestivalWithAnImageNamesItsCredit() async throws {
        for festival in try await demoFestivals() where festival.imageURL != nil {
            #expect(!isBlank(festival.imageCredit), "\(festival.id) image has no credit")
        }
    }

    @Test func everyDemoFestivalLinksToItsPageOnTheAssociationSite() async throws {
        for festival in try await demoFestivals() {
            #expect(festival.pageURL?.absoluteString == expectedPages[festival.id], "\(festival.id)")
        }
    }

    @Test func everyDemoFestivalHasAtLeastOneNonBlankGenre() async throws {
        for festival in try await demoFestivals() {
            #expect(!festival.genres.isEmpty, "\(festival.id) has no genre")
            #expect(festival.genres.allSatisfy { !isBlank($0) }, "\(festival.id) has a blank genre")
        }
    }

    @Test func aDemoTicketLinkIsHttps() async throws {
        for festival in try await demoFestivals() {
            if let ticket = festival.ticketURL {
                #expect(ticket.scheme == "https", "\(festival.id) \(ticket)")
            }
        }
    }

    @Test func everyDemoDetailHasASummary() async throws {
        for festival in try await demoFestivals() {
            let detail = try await source.festival(id: festival.id)
            #expect(!isBlank(detail.summary), "\(festival.id) has no summary")
        }
    }

    @Test func theDetailShowsTheSameImageAsTheList() async throws {
        for festival in try await demoFestivals() {
            let detail = try await source.festival(id: festival.id)
            #expect(detail.festival.imageURL == festival.imageURL, "\(festival.id)")
            #expect(detail.festival.imageCredit == festival.imageCredit, "\(festival.id)")
        }
    }

    @Test func practicalInfoHasNoBlankEntry() async throws {
        for festival in try await demoFestivals() {
            let detail = try await source.festival(id: festival.id)
            for info in detail.practicalInfo {
                #expect(!isBlank(info.title) && !isBlank(info.text), "\(festival.id) \(info)")
            }
        }
    }
}
