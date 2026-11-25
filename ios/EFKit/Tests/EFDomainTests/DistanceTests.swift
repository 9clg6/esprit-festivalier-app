import Testing
import EFDomain

// STORY-013 "Autour de moi": the radius filter uses the great-circle distance, in kilometers.
// Assumed API: Coordinate(latitude:longitude:).kilometers(to:) -> Double.

@Suite struct DistanceTests {
    let paris = Coordinate(latitude: 48.8566, longitude: 2.3522)
    let rennes = Coordinate(latitude: 48.1173, longitude: -1.6778)
    let clisson = Coordinate(latitude: 47.0868, longitude: -1.2803)
    let nantes = Coordinate(latitude: 47.2184, longitude: -1.5536)

    @Test func parisToRennesIsAbout308Kilometers() {
        #expect(abs(paris.kilometers(to: rennes) - 308) <= 3)
    }

    @Test func clissonToNantesIsAbout25Kilometers() {
        #expect(abs(clisson.kilometers(to: nantes) - 25) <= 2)
    }

    @Test func aPointIsZeroKilometersFromItself() {
        #expect(rennes.kilometers(to: rennes) == 0)
    }

    @Test func theDistanceIsTheSameBothWays() {
        #expect(abs(paris.kilometers(to: rennes) - rennes.kilometers(to: paris)) < 0.001)
    }

    @Test func oneDegreeOfLatitudeIsAbout111Kilometers() {
        let south = Coordinate(latitude: 47, longitude: -1.5)
        let north = Coordinate(latitude: 48, longitude: -1.5)
        #expect(abs(south.kilometers(to: north) - 111.2) <= 0.5)
    }
}
