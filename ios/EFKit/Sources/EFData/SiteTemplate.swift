/// Every marker of the site's article page, in one place (ADR-007). A template change on the site =
/// a new version here and new fixtures, nothing elsewhere.
public struct SiteTemplate: Sendable {
    /// Carried by every `ArticleContent` read with this template.
    public var parserVersion: Int
    /// `id` of the only region read (`main#contenu`).
    public var mainID: String
    // Classes.
    public var title: String
    public var chapo: String
    public var category: String
    public var festival: String
    public var byline: String
    public var avatar: String
    public var cover: String
    public var body: String
    public var bodyEnd: String
    public var readAlso: String
    public var tags: String
    public var authorBox: String
    public var related: String
    public var card: String
    public var sponsored: String
    /// Text after the number of minutes in the byline.
    public var readingTime: String
    /// A bold-only paragraph shorter than this is a level 3 heading.
    public var boldHeadingMaxLength: Int

    // swiftlint:disable:next identifier_name
    public static let v1 = SiteTemplate(
        parserVersion: 1, mainID: "contenu", title: "article-title", chapo: "article-chapo", category: "cat",
        festival: "festival-tag", byline: "byline", avatar: "avatar", cover: "article-cover", body: "article-body",
        bodyEnd: "read-end", readAlso: "read-also", tags: "tags", authorBox: "author-box", related: "related",
        card: "card", sponsored: "sponsored-tag", readingTime: "min de lecture", boldHeadingMaxLength: 120
    )
}
