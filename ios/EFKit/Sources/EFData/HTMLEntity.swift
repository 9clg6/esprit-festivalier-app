/// Decodes HTML character references; an unknown one stays as written. Shared by the feed and page readers.
enum HTMLEntity {
    /// Latin-1 (U+00A0…U+00FF) in order, then the typography of French articles; not the full HTML5 table.
    private static let named: [String: String] = {
        var table = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "rsquo": "’", "lsquo": "‘", "rdquo": "”",
            "ldquo": "“", "sbquo": "‚", "bdquo": "„", "hellip": "…", "ndash": "–", "mdash": "—", "euro": "€",
            "oelig": "œ", "OElig": "Œ", "Yuml": "Ÿ", "bull": "•", "trade": "™", "thinsp": "\u{2009}"
        ]
        let latin1 = """
            nbsp iexcl cent pound curren yen brvbar sect uml copy ordf laquo not shy reg macr deg plusmn sup2 sup3 \
            acute micro para middot cedil sup1 ordm raquo frac14 frac12 frac34 iquest Agrave Aacute Acirc Atilde \
            Auml Aring AElig Ccedil Egrave Eacute Ecirc Euml Igrave Iacute Icirc Iuml ETH Ntilde Ograve Oacute \
            Ocirc Otilde Ouml times Oslash Ugrave Uacute Ucirc Uuml Yacute THORN szlig agrave aacute acirc atilde \
            auml aring aelig ccedil egrave eacute ecirc euml igrave iacute icirc iuml eth ntilde ograve oacute \
            ocirc otilde ouml divide oslash ugrave uacute ucirc uuml yacute thorn yuml
            """.split(separator: " ")
        for (offset, name) in latin1.enumerated() {
            table[String(name)] = String(Character(Unicode.Scalar(UInt8(0xA0 + offset))))
        }
        return table
    }()

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

    /// A number reference is digits only (no sign); one to no character (0, a surrogate, past U+10FFFF)
    /// reads as U+FFFD.
    private static func entity(_ name: String) -> String? {
        guard name.hasPrefix("#") else { return named[name] }
        let hex = name.dropFirst().first == "x" || name.dropFirst().first == "X"
        let digits = name.dropFirst(hex ? 2 : 1)
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && (hex ? $0.isHexDigit : $0.isNumber) }) else {
            return nil
        }
        let scalar = Int(digits, radix: hex ? 16 : 10).flatMap { $0 == 0 ? nil : Unicode.Scalar($0) }
        return String(Character(scalar ?? "\u{FFFD}"))
    }
}
