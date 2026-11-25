import EFDomain
import Foundation

/// The bundled demo data, decoded once.
struct MockCatalog: Sendable {
    let festivals: [FestivalDetail]
    let lineups: [Lineup]
    let artists: [Artist]
    let articles: [Article]

    static let shared: MockCatalog = {
        do {
            return MockCatalog(
                festivals: try load("festivals"),
                lineups: try load("lineups"),
                artists: try load("artists"),
                articles: try load("articles")
            )
        } catch {
            // ponytail: a corrupt bundled resource is a build defect, not a runtime case to handle.
            fatalError("Invalid bundled demo data: \(error)")
        }
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func load<T: Decodable>(_ name: String) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
