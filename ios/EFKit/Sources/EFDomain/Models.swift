import Foundation

public struct Festival: Sendable, Codable, Hashable, Identifiable {
    public typealias ID = String

    public let id: ID
    public let name: String
    public let city: String
    public let latitude: Double
    public let longitude: Double
    public let startDate: Date
    public let endDate: Date
    public let website: URL
    public let description: String

    public init(
        id: ID, name: String, city: String, latitude: Double, longitude: Double,
        startDate: Date, endDate: Date, website: URL, description: String
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.startDate = startDate
        self.endDate = endDate
        self.website = website
        self.description = description
    }
}

public struct Stage: Sendable, Codable, Hashable, Identifiable {
    public typealias ID = String

    public let id: ID
    public let festivalId: Festival.ID
    public let name: String

    public init(id: ID, festivalId: Festival.ID, name: String) {
        self.id = id
        self.festivalId = festivalId
        self.name = name
    }
}

public struct Artist: Sendable, Codable, Hashable, Identifiable {
    public typealias ID = String

    public let id: ID
    public let name: String

    public init(id: ID, name: String) {
        self.id = id
        self.name = name
    }
}

public struct Performance: Sendable, Codable, Hashable, Identifiable {
    public typealias ID = String

    public let id: ID
    public let festivalId: Festival.ID
    public let stageId: Stage.ID
    public let artistId: Artist.ID
    public let start: Date
    public let end: Date

    public init(
        id: ID, festivalId: Festival.ID, stageId: Stage.ID, artistId: Artist.ID, start: Date, end: Date
    ) {
        self.id = id
        self.festivalId = festivalId
        self.stageId = stageId
        self.artistId = artistId
        self.start = start
        self.end = end
    }
}

public struct FestivalDetail: Sendable, Codable, Hashable {
    public let festival: Festival
    public let stages: [Stage]
    public let performances: [Performance]

    public init(festival: Festival, stages: [Stage], performances: [Performance]) {
        self.festival = festival
        self.stages = stages
        self.performances = performances
    }
}

public struct Lineup: Sendable, Codable, Hashable {
    public let festivalId: Festival.ID
    public let announcedOn: Date
    public let artistIds: [Artist.ID]

    public init(festivalId: Festival.ID, announcedOn: Date, artistIds: [Artist.ID]) {
        self.festivalId = festivalId
        self.announcedOn = announcedOn
        self.artistIds = artistIds
    }
}

public struct Article: Sendable, Codable, Hashable, Identifiable {
    public typealias ID = String

    /// An editorial section of the site ("Actu", "Live report"...). Open set: the site adds sections.
    public struct Category: Sendable, Hashable, RawRepresentable, Codable {
        public let rawValue: String

        public init(rawValue: String) { self.rawValue = rawValue }

        public init(from decoder: any Decoder) throws {
            rawValue = try decoder.singleValueContainer().decode(String.self)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    public let id: ID
    public let title: String
    public let link: URL
    public let category: Category
    public let author: String
    public let publishedAt: Date
    public let imageURL: URL

    public init(
        id: ID, title: String, link: URL, category: Category, author: String, publishedAt: Date, imageURL: URL
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.category = category
        self.author = author
        self.publishedAt = publishedAt
        self.imageURL = imageURL
    }
}
