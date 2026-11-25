/// Decodes HTML character references; an unknown one stays as written. Shared by the feed and page readers.
enum HTMLEntity {
    private static let named = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{A0}", "rsquo": "’",
        "lsquo": "‘", "rdquo": "”", "ldquo": "“", "hellip": "…", "ndash": "–", "mdash": "—",
        "laquo": "«", "raquo": "»"
    ]

    static func decode(_ text: String) -> String {
        var result = ""
        var rest = text[...]
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            rest = rest[amp...]
            guard let semi = rest.prefix(11).firstIndex(of: ";"),  // bounded: no rescan to the end per "&"
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
