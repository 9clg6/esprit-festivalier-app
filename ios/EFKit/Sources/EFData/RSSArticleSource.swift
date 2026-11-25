import EFDomain
import Foundation

/// Articles from the site's RSS feed. `load` returns the raw feed bytes (see `SiteFeed`).
public struct RSSArticleSource: ArticleSource {
    private let load: @Sendable () async throws -> Data

    public init(load: @escaping @Sendable () async throws -> Data) { self.load = load }

    public func articles(category: Article.Category?) async throws -> [Article] {
        let all = try Self.parse(try await load())
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    /// Newest first. Items without title, link or readable date are left out.
    static func parse(_ data: Data) throws -> [Article] {
        let delegate = FeedDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), delegate.root == "rss" else { throw SourceError.malformedFeed }
        return delegate.articles.sorted { $0.publishedAt > $1.publishedAt }
    }
}

private final class FeedDelegate: NSObject, XMLParserDelegate {
    var root: String?
    var articles: [Article] = []
    private var item: [String: String]?
    private var categories: [String] = []
    private var enclosure: URL?
    private var text = ""

    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
        attributes: [String: String]
    ) {
        if root == nil { root = name }
        text = ""
        if name == "item" {
            item = [:]
            categories = []
            enclosure = nil
        } else if name == "enclosure", item != nil {
            enclosure = attributes["url"].flatMap(URL.init(string:))
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(bytes: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(
        _ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?
    ) {
        guard item != nil else { return }
        switch name {
        case "item":
            if let article = makeArticle() { articles.append(article) }
            item = nil
        case "category":
            categories.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
        case "title", "link", "guid", "pubDate", "dc:creator", "description", "content:encoded":
            item?[name] = text
        default:
            break
        }
    }

    private func makeArticle() -> Article? {
        guard let item,
              let title = item["title"].map(HTMLText.plain), !title.isEmpty,
              let link = item["link"].flatMap({ URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }),
              let date = item["pubDate"].flatMap(Self.date)
        else { return nil }
        let full = HTMLText.plain(item["description"] ?? "")
        var body = item["content:encoded"].map(HTMLText.paragraphs) ?? []
        if body.isEmpty, !full.isEmpty { body = [full] }
        let guid = item["guid"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Article(
            id: guid.isEmpty ? link.absoluteString : guid, title: title, link: link, category: category(),
            author: HTMLText.plain(item["dc:creator"] ?? ""), publishedAt: date, imageURL: enclosure,
            excerpt: HTMLText.excerpt(full, limit: 200), body: body
        )
    }

    /// A known section wins over any other label (WordPress lists tags as categories too).
    private func category() -> Article.Category {
        let labels = categories.filter { !$0.isEmpty }.map { Article.Category(rawValue: $0) }
        return labels.first(where: Article.Category.known.contains) ?? labels.first ?? .actu
    }

    private static func date(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}

/// Feed text is HTML inside XML: tags and entities are removed for display.
private enum HTMLText {
    static func plain(_ html: String) -> String {
        // Block ends become a space; inline tags vanish ("<strong>fête</strong>." stays "fête.").
        let withoutTags = html
            .replacingOccurrences(of: "</p>|<br ?/?>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        return decode(withoutTags).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func paragraphs(_ html: String) -> [String] {
        let regex = /<p[^>]*>(.*?)<\/p>/.dotMatchesNewlines()
        return html.matches(of: regex).map { plain(String($0.1)) }.filter { !$0.isEmpty }
    }

    /// At most `limit` characters; when cut, ends on a whole word followed by "…".
    static func excerpt(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        var kept = text.prefix(limit - 1)
        if let next = text.dropFirst(kept.count).first, !next.isWhitespace,
           let space = kept.lastIndex(where: \.isWhitespace) {
            kept = kept[..<space]
        }
        return kept.trimmingCharacters(in: .whitespaces) + "…"
    }

    private static let named = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{A0}", "rsquo": "’",
        "lsquo": "‘", "rdquo": "”", "ldquo": "“", "hellip": "…", "ndash": "–", "mdash": "—",
        "laquo": "«", "raquo": "»"
    ]

    private static func decode(_ text: String) -> String {
        var result = ""
        var rest = text[...]
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            rest = rest[amp...]
            guard let semi = rest.firstIndex(of: ";"), rest.distance(from: rest.startIndex, to: semi) <= 10,
                  let value = entity(String(rest[rest.index(after: rest.startIndex)..<semi]))
            else {
                result.append("&")
                rest = rest.dropFirst()
                continue
            }
            result += value
            rest = rest[rest.index(after: semi)...]
        }
        return result + rest
    }

    private static func entity(_ name: String) -> String? {
        if name.hasPrefix("#") {
            let hex = name.dropFirst().first == "x" || name.dropFirst().first == "X"
            let code = Int(name.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10)
            return code.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return named[name]
    }
}
