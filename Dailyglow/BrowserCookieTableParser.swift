import Foundation
import Playgrounds

enum BrowserCookieTableParser {
    struct Row {
        let name: String
        let value: String
        let domain: String
        let path: String
        let expiration: String
        let secure: Bool
        let httpOnly: Bool
        let hostOnly: Bool
        let sameSite: String?
    }

    enum ParseError: Error {
        case invalidLine(Int)
    }

    static func looksLikeTable(_ input: String) -> Bool {
        guard let firstLine = normalizedLines(input).first else {
            return false
        }

        let columns = columns(in: firstLine)
        if isHeader(columns) {
            return true
        }

        guard columns.count >= 8 else { return false }

        let domain = columns[2]
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        return (domain == "github.com" || domain.hasSuffix(".github.com"))
            && columns[3].hasPrefix("/")
            && Int(columns[5]) != nil
    }

    static func parse(_ input: String) throws -> [Row] {
        try normalizedLines(input)
            .enumerated()
            .compactMap { offset, line in
                try row(from: line, lineNumber: offset + 1)
            }
    }

    private static func row(from line: String, lineNumber: Int) throws -> Row? {
        let columns = columns(in: line)
        if isHeader(columns) {
            return nil
        }

        guard columns.count >= 8 else {
            throw ParseError.invalidLine(lineNumber)
        }

        let name = normalizedName(columns[0])
        let value = columns[1]
        let domain = columns[2]
        let path = columns[3]
        let expiration = columns[4]
        let size = columns[5]
        let httpOnly: Bool
        let secure: Bool
        let sameSite: String?

        if line.contains("\t") {
            guard columns.count >= 10 else {
                throw ParseError.invalidLine(lineNumber)
            }

            httpOnly = isChecked(columns[6])
            secure = isChecked(columns[7])
            sameSite = columns[8].isEmpty ? nil : columns[8]
        } else {
            let checkboxCells = Array(columns[6..<(columns.count - 2)])
            guard checkboxCells.count <= 2,
                  checkboxCells.allSatisfy(isChecked)
            else {
                throw ParseError.invalidLine(lineNumber)
            }

            // Rich-text paste can collapse empty checkbox columns. For GitHub,
            // a lone checkmark is the Secure column on the right.
            httpOnly = checkboxCells.count == 2
            secure = !checkboxCells.isEmpty
            sameSite = columns[columns.count - 2]
        }

        guard !name.isEmpty,
              !domain.isEmpty,
              !path.isEmpty,
              !expiration.isEmpty,
              Int(size) != nil
        else {
            throw ParseError.invalidLine(lineNumber)
        }

        return Row(
            name: name,
            value: value,
            domain: domain,
            path: path,
            expiration: expiration,
            secure: secure,
            httpOnly: httpOnly,
            hostOnly: !domain.hasPrefix("."),
            sameSite: sameSite
        )
    }

    private static func normalizedLines(_ input: String) -> [String] {
        input
            .split(whereSeparator: \.isNewline)
            .map { removingLeadingEncodedSpaces(from: String($0)) }
            .filter { !$0.isEmpty }
    }

    private static func removingLeadingEncodedSpaces(from line: String) -> String {
        let encodedSpaces = ["&#x20;", "&#32;", "&nbsp;"]
        var result = line.trimmingCharacters(in: .whitespacesAndNewlines)

        while let prefix = encodedSpaces.first(where: {
            result.lowercased().hasPrefix($0)
        }) {
            result.removeFirst(prefix.count)
            result = String(result.drop(while: \.isWhitespace))
        }

        return result
    }

    private static func columns(in line: String) -> [String] {
        let columns: [String]
        if line.contains("\t") {
            columns = line.components(separatedBy: "\t")
        } else {
            let separated = line.replacingOccurrences(
                of: "[ \u{00A0}\u{2007}\u{202F}]{2,}",
                with: "\t",
                options: .regularExpression
            )
            columns = separated.components(separatedBy: "\t")
        }

        var trimmed = columns

        while trimmed.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            trimmed.removeFirst()
        }
        while trimmed.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            trimmed.removeLast()
        }

        return trimmed.enumerated().map { index, column in
            // Cookie values are opaque. Do not decode entities, unescape text,
            // or trim content from the Value column.
            index == 1
                ? column
                : column.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func normalizedName(_ value: String) -> String {
        // A backslash before an underscore can be introduced when a copied
        // cookie name passes through Markdown. Backslashes are not valid in a
        // standard cookie name, so this is safe to limit to the Name column.
        value.replacingOccurrences(of: "\\_", with: "_")
    }

    private static func isHeader(_ columns: [String]) -> Bool {
        columns.first?.caseInsensitiveCompare("Name") == .orderedSame
            && columns.contains {
                $0.caseInsensitiveCompare("Domain") == .orderedSame
            }
    }

    private static func isChecked(_ value: String) -> Bool {
        ["✓", "✔", "true", "yes"].contains(value.lowercased())
    }
}

#Playground("Cookie table parser") {
    let copiedCookieRow = """
    preview_cookie\texample-value\tgithub.com\t/\tSession\t27\t\t✓\tLax\tMedium
    """

    let parsedRows = try? BrowserCookieTableParser.parse(copiedCookieRow)
    let summaries = parsedRows?.map { row in
        (name: row.name, domain: row.domain, secure: row.secure)
    }

    print(summaries ?? [])
}
