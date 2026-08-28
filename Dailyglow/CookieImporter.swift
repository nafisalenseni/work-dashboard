import Foundation

enum CookieImporter {
    private static let defaultDomain = "github.com"

    static func cookies(from input: String) throws -> [HTTPCookie] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CookieImportError.emptyInput
        }

        if trimmed.first == "[" || trimmed.first == "{" {
            return try cookiesFromJSON(trimmed)
        }

        if BrowserCookieTableParser.looksLikeTable(trimmed) {
            return try cookiesFromTable(trimmed)
        }

        return try cookiesFromHeader(trimmed)
    }

    private static func cookiesFromTable(_ input: String) throws -> [HTTPCookie] {
        let rows: [BrowserCookieTableParser.Row]
        do {
            rows = try BrowserCookieTableParser.parse(input)
        } catch BrowserCookieTableParser.ParseError.invalidLine(let line) {
            throw CookieImportError.invalidTableLine(line)
        }

        let cookies = try rows.map { row in
            try makeCookie(
                name: row.name,
                value: row.value,
                domain: row.domain,
                path: row.path,
                secure: row.secure,
                httpOnly: row.httpOnly,
                hostOnly: row.hostOnly,
                sameSite: row.sameSite,
                expirationDate: expirationDate(
                    from: ["expires": row.expiration]
                )
            )
        }

        guard !cookies.isEmpty else {
            throw CookieImportError.noCookies
        }

        return cookies
    }

    private static func cookiesFromJSON(_ input: String) throws -> [HTTPCookie] {
        guard let data = input.data(using: .utf8) else {
            throw CookieImportError.invalidJSON
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CookieImportError.invalidJSON
        }

        let entries: [[String: Any]]
        if let array = object as? [[String: Any]] {
            entries = array
        } else if let dictionary = object as? [String: Any],
                  let array = dictionary["cookies"] as? [[String: Any]] {
            entries = array
        } else if let dictionary = object as? [String: Any],
                  dictionary["name"] != nil {
            entries = [dictionary]
        } else {
            throw CookieImportError.unsupportedJSON
        }

        let cookies = try entries.enumerated().map { index, entry in
            guard let name = entry["name"] as? String,
                  let value = entry["value"] as? String
            else {
                throw CookieImportError.missingFields(index: index + 1)
            }

            let domain = (entry["domain"] as? String) ?? defaultDomain
            let path = (entry["path"] as? String) ?? "/"
            let secure = (entry["secure"] as? Bool) ?? true
            let httpOnly = (entry["httpOnly"] as? Bool) ?? false
            let hostOnly = (entry["hostOnly"] as? Bool) ?? false
            let sameSite = entry["sameSite"] as? String
            let expirationDate = expirationDate(from: entry)

            return try makeCookie(
                name: name,
                value: value,
                domain: domain,
                path: path,
                secure: secure,
                httpOnly: httpOnly,
                hostOnly: hostOnly,
                sameSite: sameSite,
                expirationDate: expirationDate
            )
        }

        guard !cookies.isEmpty else {
            throw CookieImportError.noCookies
        }

        return cookies
    }

    private static func cookiesFromHeader(_ input: String) throws -> [HTTPCookie] {
        let header = input.replacingOccurrences(
            of: #"^Cookie:\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        let cookies = try header.split(separator: ";").map { pair in
            let pieces = pair.split(separator: "=", maxSplits: 1)
            guard pieces.count == 2 else {
                throw CookieImportError.invalidHeader
            }

            return try makeCookie(
                name: String(pieces[0]).trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                value: String(pieces[1]).trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                domain: defaultDomain,
                path: "/",
                secure: true,
                httpOnly: false,
                hostOnly: true,
                sameSite: nil,
                expirationDate: nil
            )
        }

        guard !cookies.isEmpty else {
            throw CookieImportError.noCookies
        }

        return cookies
    }

    private static func makeCookie(
        name: String,
        value: String,
        domain: String,
        path: String,
        secure: Bool,
        httpOnly: Bool,
        hostOnly: Bool,
        sameSite: String?,
        expirationDate: Date?
    ) throws -> HTTPCookie {
        let normalizedDomain = domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        guard normalizedDomain == "github.com"
                || normalizedDomain.hasSuffix(".github.com")
        else {
            throw CookieImportError.unsupportedDomain(domain)
        }

        guard !name.isEmpty,
              !name.contains(";"),
              !name.contains("\r"),
              !name.contains("\n"),
              !value.contains("\r"),
              !value.contains("\n")
        else {
            throw CookieImportError.invalidCookie(name)
        }

        let cookiePath = path.hasPrefix("/") ? path : "/"
        let requiresHostOnly = hostOnly || name.hasPrefix("__Host-")
        let requiresSecure = secure
            || name.hasPrefix("__Host-")
            || name.hasPrefix("__Secure-")
        var attributes = ["\(name)=\(value)", "Path=\(cookiePath)"]

        if !requiresHostOnly {
            attributes.append("Domain=\(domain)")
        }

        if requiresSecure {
            attributes.append("Secure")
        }

        if httpOnly {
            attributes.append("HttpOnly")
        }

        if let sameSite = normalizedSameSite(sameSite) {
            attributes.append("SameSite=\(sameSite)")
        }

        if let expirationDate {
            attributes.append("Expires=\(httpDateString(from: expirationDate))")
        }

        guard let originURL = URL(string: "https://\(normalizedDomain)"),
              let cookie = HTTPCookie.cookies(
                withResponseHeaderFields: [
                    "Set-Cookie": attributes.joined(separator: "; ")
                ],
                for: originURL
              ).first
        else {
            throw CookieImportError.invalidCookie(name)
        }

        return cookie
    }

    private static func expirationDate(from entry: [String: Any]) -> Date? {
        guard let value = entry["expirationDate"] ?? entry["expires"] else {
            return nil
        }

        if let number = value as? NSNumber {
            return date(fromTimestamp: number.doubleValue)
        }

        if let string = value as? String {
            if let timestamp = TimeInterval(string) {
                return date(fromTimestamp: timestamp)
            }

            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = fractionalFormatter.date(from: string) {
                return date
            }

            return ISO8601DateFormatter().date(from: string)
        }

        return nil
    }

    private static func date(fromTimestamp timestamp: TimeInterval) -> Date? {
        guard timestamp > 0 else { return nil }

        // Browser exports normally use Unix seconds. Some exporters use
        // milliseconds, so normalize those before creating the cookie.
        let seconds = timestamp > 10_000_000_000
            ? timestamp / 1_000
            : timestamp

        return Date(timeIntervalSince1970: seconds)
    }

    private static func httpDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: date)
    }

    private static func normalizedSameSite(_ value: String?) -> String? {
        switch value?.lowercased() {
        case "lax":
            return "Lax"
        case "strict":
            return "Strict"
        case "none", "no_restriction":
            return "None"
        default:
            return nil
        }
    }
}

private enum CookieImportError: LocalizedError {
    case emptyInput
    case invalidJSON
    case unsupportedJSON
    case missingFields(index: Int)
    case invalidTableLine(Int)
    case invalidHeader
    case noCookies
    case unsupportedDomain(String)
    case invalidCookie(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Paste at least one cookie."
        case .invalidJSON:
            return "The pasted JSON is not valid."
        case .unsupportedJSON:
            return "Expected a cookie array, a {\"cookies\": [...]} object, or one cookie object."
        case .missingFields(let index):
            return "Cookie \(index) needs both a name and a value."
        case .invalidTableLine(let line):
            return "Cookie table line \(line) does not have the expected browser table columns. Copy the rows directly from the browser and try again."
        case .invalidHeader:
            return "Expected a Cookie header containing name=value pairs separated by semicolons."
        case .noCookies:
            return "No cookies were found."
        case .unsupportedDomain(let domain):
            return "The cookie domain \(domain) is not a GitHub domain."
        case .invalidCookie(let name):
            return "The cookie named \(name.isEmpty ? "(empty)" : name) could not be imported."
        }
    }
}
