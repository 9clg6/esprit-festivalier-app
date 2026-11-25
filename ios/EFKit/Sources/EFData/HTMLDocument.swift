import Foundation

/// A small tolerant HTML reader (ADR-007): one pass over the bytes builds a tree of elements and text.
/// Void elements, `p` and `li` closed implicitly, comments ignored, `svg` dropped, `script` and `style`
/// kept as raw text, orphan closing tags ignored, entities decoded, a truncated page read up to the cut.
/// Never throws: whatever the bytes, the result is a tree (possibly empty).
struct HTMLDocument: Sendable {
    enum Node: Sendable {
        case element(Int)
        case text(String)
    }

    struct Element: Sendable {
        let name: String
        let attributes: [(name: String, value: String)]
        let classes: [Substring]
        var children: [Node] = []

        init(name: String, attributes: [(name: String, value: String)]) {
            self.name = name
            self.attributes = attributes
            classes = attributes.first { $0.name == "class" }?.value.split(whereSeparator: \.isWhitespace) ?? []
        }

        func attribute(_ name: String) -> String? { attributes.first { $0.name == name }?.value }

        func hasClass(_ name: String) -> Bool { classes.contains { $0 == name } }
    }

    /// Index 0 is the document itself.
    private(set) var elements = [Element(name: "#document", attributes: [])]

    subscript(index: Int) -> Element { elements[index] }

    init(_ data: Data) {
        var builder = TreeBuilder()
        var tokenizer = Tokenizer(bytes: [UInt8](data))
        tokenizer.run(into: &builder)
        elements = builder.elements
    }

    /// The first element under `root` (depth first, root excluded) that matches.
    func first(in root: Int = 0, where match: (Element) -> Bool) -> Int? {
        for case let .element(child) in elements[root].children {
            if match(elements[child]) { return child }
            if let found = first(in: child, where: match) { return found }
        }
        return nil
    }

    /// Every element under `root` that matches, not looking inside a match.
    func all(in root: Int, where match: (Element) -> Bool) -> [Int] {
        elements[root].children.flatMap { node -> [Int] in
            guard case let .element(child) = node else { return [] }
            return match(elements[child]) ? [child] : all(in: child, where: match)
        }
    }

    /// The visible text under `root`, whitespace collapsed and trimmed.
    func text(of root: Int) -> String {
        var raw = ""
        appendText(of: root, to: &raw)
        return raw.split(whereSeparator: HTMLDocument.isSpace).joined(separator: " ")
    }

    private func appendText(of root: Int, to raw: inout String) {
        for node in elements[root].children {
            switch node {
            case let .text(text): raw += text
            case let .element(child) where !Self.rawText.contains(elements[child].name):
                raw += " "
                appendText(of: child, to: &raw)
                raw += " "
            case .element: break
            }
        }
    }

    /// HTML whitespace (not U+00A0).
    static func isSpace(_ character: Character) -> Bool {
        character == " " || character == "\n" || character == "\t" || character == "\r" || character == "\u{C}"
            || character == "\r\n"
    }

    static let void: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"
    ]
    static let rawText: Set<String> = ["script", "style"]
    /// Never part of the article text.
    static let skipped: Set<String> = [
        "button", "form", "input", "noscript", "object", "script", "select", "style", "template", "textarea"
    ]
    /// Elements that may sit inside a `p`: opening anything else closes the open `p`.
    static let inline: Set<String> = [
        "a", "abbr", "b", "bdi", "bdo", "br", "cite", "code", "data", "del", "dfn", "em", "font", "i", "img", "ins",
        "kbd", "label", "mark", "picture", "q", "s", "samp", "small", "span", "strong", "sub", "sup", "time", "u",
        "var", "wbr"
    ]
}

/// Holds the open elements while the tokenizer reads.
private struct TreeBuilder {
    var elements = [HTMLDocument.Element(name: "#document", attributes: [])]
    private var open = [0]

    mutating func text(_ text: String) {
        elements[open[open.count - 1]].children.append(.text(text))
    }

    mutating func start(_ name: String, attributes: [(name: String, value: String)], selfClosing: Bool) {
        if !HTMLDocument.inline.contains(name) { close("p", through: HTMLDocument.inline) }
        if name == "li" { close("li", through: HTMLDocument.inline.union(["p", "div", "span"])) }
        let index = elements.count
        elements.append(HTMLDocument.Element(name: name, attributes: attributes))
        elements[open[open.count - 1]].children.append(.element(index))
        if !selfClosing && !HTMLDocument.void.contains(name) { open.append(index) }
    }

    /// A closing tag closes the nearest open element of that name; an orphan is ignored.
    mutating func end(_ name: String) {
        guard let position = open.lastIndex(where: { elements[$0].name == name }), position > 0 else { return }
        open.removeSubrange(position...)
    }

    /// Implicit end: closes an open `name` when only `through` elements are open above it.
    private mutating func close(_ name: String, through allowed: Set<String>) {
        var position = open.count - 1
        while position > 0 {
            let open = elements[self.open[position]].name
            if open == name {
                self.open.removeSubrange(position...)
                return
            }
            guard allowed.contains(open) else { return }
            position -= 1
        }
    }
}

private struct TagEnd {
    let attributes: [(name: String, value: String)]
    let selfClosing: Bool
    /// Just after `>`.
    let end: Int
}

private struct Tokenizer {
    let bytes: [UInt8]
    private var position = 0
    private var textStart = 0

    init(bytes: [UInt8]) { self.bytes = bytes }

    private static let lessThan = UInt8(ascii: "<"), greaterThan = UInt8(ascii: ">"), slash = UInt8(ascii: "/")
    private static let bang = UInt8(ascii: "!"), question = UInt8(ascii: "?"), equals = UInt8(ascii: "=")
    private static let quote = UInt8(ascii: "\""), apostrophe = UInt8(ascii: "'"), dash = UInt8(ascii: "-")

    mutating func run(into builder: inout TreeBuilder) {
        while let open = nextLessThan() {
            let next = byte(at: open + 1)
            if next == Self.bang || next == Self.question {
                flushText(upTo: open, into: &builder)
                skipMarkup(at: open)
            } else if next == Self.slash, isLetter(byte(at: open + 2)) {
                flushText(upTo: open, into: &builder)
                guard let (name, after) = readName(at: open + 2), let close = find(Self.greaterThan, from: after)
                else {
                    stop()
                    return
                }
                builder.end(name)
                resume(at: close + 1)
            } else if isLetter(next) {
                flushText(upTo: open, into: &builder)
                guard readStartTag(at: open + 1, into: &builder) else {
                    stop()
                    return
                }
            } else {
                position = open + 1  // a lone "<" is text
            }
        }
        flushText(upTo: bytes.count, into: &builder)
    }

    // MARK: - Tags

    /// False when the page ends inside the tag (the cut tag is dropped).
    private mutating func readStartTag(at start: Int, into builder: inout TreeBuilder) -> Bool {
        guard let (name, afterName) = readName(at: start), let tag = readAttributes(from: afterName) else {
            return false
        }
        let (attributes, selfClosing, afterTag) = (tag.attributes, tag.selfClosing, tag.end)
        switch name {
        case "svg":  // drawings carry no text of the article
            guard !selfClosing else { return resume(at: afterTag) }
            guard let end = findClosing("svg", from: afterTag) else { return false }
            return resume(at: end)
        case _ where HTMLDocument.rawText.contains(name):
            builder.start(name, attributes: attributes, selfClosing: false)
            let closing = findClosingStart(name, from: afterTag)
            builder.text(string(afterTag..<(closing ?? bytes.count)))
            builder.end(name)
            guard let closing, let end = find(Self.greaterThan, from: closing) else { return false }
            return resume(at: end + 1)
        default:
            builder.start(name, attributes: attributes, selfClosing: selfClosing)
            return resume(at: afterTag)
        }
    }

    /// The attributes up to `>`; nil when the page ends first.
    private func readAttributes(from start: Int) -> TagEnd? {
        var attributes: [(name: String, value: String)] = []
        var index = start
        var selfClosing = false
        while true {
            index = skipSpaces(from: index)
            guard index < bytes.count else { return nil }
            if bytes[index] == Self.greaterThan {
                return TagEnd(attributes: attributes, selfClosing: selfClosing, end: index + 1)
            }
            if bytes[index] == Self.slash {
                selfClosing = byte(at: index + 1) == Self.greaterThan
                index += 1
                continue
            }
            guard let (attribute, next) = readAttribute(at: index) else { return nil }
            attributes.append(attribute)
            index = next
        }
    }

    private func readAttribute(at start: Int) -> ((name: String, value: String), Int)? {
        var index = start
        while index < bytes.count, !isSpace(bytes[index]), bytes[index] != Self.equals,
              bytes[index] != Self.greaterThan, bytes[index] != Self.slash {
            index += 1
        }
        let name = lowercased(start..<index)
        index = skipSpaces(from: index)
        guard index < bytes.count else { return nil }
        guard bytes[index] == Self.equals else { return ((name, ""), index) }
        index = skipSpaces(from: index + 1)
        guard index < bytes.count else { return nil }
        let delimiter = bytes[index]
        if delimiter == Self.quote || delimiter == Self.apostrophe {
            guard let close = find(delimiter, from: index + 1) else { return nil }
            return ((name, decoded(index + 1..<close)), close + 1)
        }
        let valueStart = index
        while index < bytes.count, !isSpace(bytes[index]), bytes[index] != Self.greaterThan { index += 1 }
        return ((name, decoded(valueStart..<index)), index)
    }

    private func readName(at start: Int) -> (String, Int)? {
        var index = start
        while index < bytes.count, !isSpace(bytes[index]), bytes[index] != Self.greaterThan,
              bytes[index] != Self.slash {
            index += 1
        }
        return index < bytes.count ? (lowercased(start..<index), index) : nil
    }

    /// Comments, doctype, processing instructions.
    private mutating func skipMarkup(at open: Int) {
        let isComment = byte(at: open + 2) == Self.dash && byte(at: open + 3) == Self.dash
        if isComment {
            var index = open + 4
            while index + 2 < bytes.count {
                if bytes[index] == Self.dash, bytes[index + 1] == Self.dash, bytes[index + 2] == Self.greaterThan {
                    resume(at: index + 3)
                    return
                }
                index += 1
            }
            stop()
        } else if let close = find(Self.greaterThan, from: open + 2) {
            resume(at: close + 1)
        } else {
            stop()
        }
    }

    /// The index of `</name` (any case) at or after `start`.
    private func findClosingStart(_ name: String, from start: Int) -> Int? {
        let wanted = Array(name.utf8)
        var index = start
        while let open = find(Self.lessThan, from: index) {
            if byte(at: open + 1) == Self.slash,
               open + 2 + wanted.count <= bytes.count,
               zip(bytes[(open + 2)...], wanted).allSatisfy({ lower($0) == $1 }) {
                return open
            }
            index = open + 1
        }
        return nil
    }

    /// Just after `</name…>`.
    private func findClosing(_ name: String, from start: Int) -> Int? {
        findClosingStart(name, from: start).flatMap { find(Self.greaterThan, from: $0) }.map { $0 + 1 }
    }

    // MARK: - Bytes

    private mutating func nextLessThan() -> Int? {
        guard let found = find(Self.lessThan, from: position) else { return nil }
        position = found
        return found
    }

    private mutating func flushText(upTo end: Int, into builder: inout TreeBuilder) {
        if textStart < end { builder.text(decoded(textStart..<end)) }
        textStart = end
    }

    @discardableResult
    private mutating func resume(at index: Int) -> Bool {
        position = index
        textStart = index
        return true
    }

    /// The page ends inside markup: what follows the last complete token is dropped.
    @discardableResult
    private mutating func stop() -> Bool {
        position = bytes.count
        textStart = bytes.count
        return false
    }

    private func find(_ byte: UInt8, from start: Int) -> Int? {
        guard start < bytes.count else { return nil }
        return bytes[start...].firstIndex(of: byte)
    }

    private func byte(at index: Int) -> UInt8 { index < bytes.count ? bytes[index] : 0 }

    private func skipSpaces(from start: Int) -> Int {
        var index = start
        while index < bytes.count, isSpace(bytes[index]) { index += 1 }
        return index
    }

    /// Invalid UTF-8 is repaired, not refused: a page cut inside a character still reads up to the cut.
    private func string(_ range: Range<Int>, lowercased: Bool = false) -> String {
        String(unsafeUninitializedCapacity: range.count) { buffer in
            for (offset, index) in range.enumerated() {
                buffer[offset] = lowercased ? lower(bytes[index]) : bytes[index]
            }
            return range.count
        }
    }

    private func lowercased(_ range: Range<Int>) -> String { string(range, lowercased: true) }

    private func decoded(_ range: Range<Int>) -> String {
        bytes[range].contains(UInt8(ascii: "&")) ? HTMLEntity.decode(string(range)) : string(range)
    }

    private func lower(_ byte: UInt8) -> UInt8 { byte >= 65 && byte <= 90 ? byte + 32 : byte }
    private func isLetter(_ byte: UInt8) -> Bool { (byte | 0x20) >= 97 && (byte | 0x20) <= 122 }
    private func isSpace(_ byte: UInt8) -> Bool { byte == 32 || (byte >= 9 && byte <= 13) }
}
