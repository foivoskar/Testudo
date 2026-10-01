import Foundation
import Security


// ============================================================
// MARK: - Secret URL Keychain storage
// ============================================================

enum CalendarSecretStore {
    private static let service =
        "DReport.iCalSubscriptions"


    static func save(
        secret: String,
        account: String
    ) throws {
        let data =
            Data(secret.utf8)

        let baseQuery:
            [String: Any] =
        [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account
        ]

        SecItemDelete(
            baseQuery as CFDictionary
        )

        var insert =
            baseQuery

        insert[
            kSecValueData as String
        ] = data

        let status =
            SecItemAdd(
                insert as CFDictionary,
                nil
            )

        guard status == errSecSuccess
        else {
            throw NSError(
                domain:
                    NSOSStatusErrorDomain,
                code:
                    Int(status)
            )
        }
    }


    static func read(
        account: String
    ) -> String? {
        let query:
            [String: Any] =
        [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account,
            kSecReturnData as String:
                true,
            kSecMatchLimit as String:
                kSecMatchLimitOne
        ]

        var result:
            CFTypeRef?

        let status =
            SecItemCopyMatching(
                query as CFDictionary,
                &result
            )

        guard
            status == errSecSuccess,
            let data =
                result as? Data
        else {
            return nil
        }

        return String(
            data: data,
            encoding: .utf8
        )
    }


    static func delete(
        account: String
    ) {
        let query:
            [String: Any] =
        [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account
        ]

        SecItemDelete(
            query as CFDictionary
        )
    }
}


// ============================================================
// MARK: - Parsed iCalendar representation
// ============================================================

struct ParsedICalendar {
    var calendarName:
        String?

    var events:
        [ParsedICalendarEvent]
}


struct ParsedICalendarEvent {
    var uid:
        String

    var recurrenceID:
        String?

    var title:
        String

    var notes:
        String

    var location:
        String?

    var startAt:
        Date

    var endAt:
        Date

    var isAllDay:
        Bool

    var startTimeZoneID:
        String?

    var endTimeZoneID:
        String?

    var status:
        CalendarEventStatus

    var recurrenceRules:
        [String]

    var externalURL:
        String?

    var createdAt:
        Date?

    var updatedAt:
        Date?

    var externalIdentity:
        String
    {
        if
            let recurrenceID,
            !recurrenceID.isEmpty
        {
            return
                "\(uid)|\(recurrenceID)"
        }

        return uid
    }
}


// ============================================================
// MARK: - Lightweight iCalendar parser
// ============================================================

enum ICalendarParser {

    private struct Property {
        let name:
            String

        let parameters:
            [String: String]

        let value:
            String
    }


    static func parse(
        data: Data
    ) throws -> ParsedICalendar {
        guard
            let raw =
                String(
                    data: data,
                    encoding: .utf8
                )
                ?? String(
                    data: data,
                    encoding: .isoLatin1
                )
        else {
            throw parserError(
                "The iCal feed could not be decoded."
            )
        }

        let lines =
            unfold(raw)

        guard
            lines.contains(
                where: {
                    $0.uppercased()
                        == "BEGIN:VCALENDAR"
                }
            )
        else {
            throw parserError(
                "The supplied address did not return an iCalendar feed."
            )
        }

        var calendarName:
            String?

        var events:
            [ParsedICalendarEvent] = []

        var insideEvent =
            false

        var properties:
            [String: [Property]] = [:]

        for line in lines {
            let upper =
                line.uppercased()

            if upper == "BEGIN:VEVENT" {
                insideEvent =
                    true

                properties =
                    [:]

                continue
            }

            if upper == "END:VEVENT" {
                if
                    let event =
                        makeEvent(
                            properties
                        )
                {
                    events.append(
                        event
                    )
                }

                insideEvent =
                    false

                properties =
                    [:]

                continue
            }

            guard
                let property =
                    parseProperty(
                        line
                    )
            else {
                continue
            }

            if insideEvent {
                properties[
                    property.name,
                    default: []
                ]
                .append(
                    property
                )

            } else if
                property.name
                    == "X-WR-CALNAME"
            {
                calendarName =
                    decodeText(
                        property.value
                    )
            }
        }

        return ParsedICalendar(
            calendarName:
                calendarName,
            events:
                events
        )
    }


    private static func unfold(
        _ raw: String
    ) -> [String] {
        let normalized =
            raw
                .replacingOccurrences(
                    of: "\r\n",
                    with: "\n"
                )
                .replacingOccurrences(
                    of: "\r",
                    with: "\n"
                )

        var result:
            [String] = []

        for physicalLine in
            normalized
                .components(
                    separatedBy: "\n"
                )
        {
            if
                (
                    physicalLine
                        .hasPrefix(" ")
                    || physicalLine
                        .hasPrefix("\t")
                ),
                !result.isEmpty
            {
                result[
                    result.count - 1
                ]
                += String(
                    physicalLine
                        .dropFirst()
                )

            } else {
                result.append(
                    physicalLine
                )
            }
        }

        return result
    }


    private static func parseProperty(
        _ line: String
    ) -> Property? {
        guard
            let colon =
                line.firstIndex(
                    of: ":"
                )
        else {
            return nil
        }

        let head =
            String(
                line[..<colon]
            )

        let value =
            String(
                line[
                    line.index(
                        after: colon
                    )...
                ]
            )

        let components =
            head
                .split(
                    separator: ";",
                    omittingEmptySubsequences:
                        false
                )
                .map(String.init)

        guard
            let first =
                components.first
        else {
            return nil
        }

        var parameters:
            [String: String] = [:]

        for part in
            components.dropFirst()
        {
            guard
                let equal =
                    part.firstIndex(
                        of: "="
                    )
            else {
                continue
            }

            let key =
                String(
                    part[..<equal]
                )
                .uppercased()

            var parameterValue =
                String(
                    part[
                        part.index(
                            after: equal
                        )...
                    ]
                )

            if
                parameterValue
                    .hasPrefix("\""),
                parameterValue
                    .hasSuffix("\""),
                parameterValue.count >= 2
            {
                parameterValue =
                    String(
                        parameterValue
                            .dropFirst()
                            .dropLast()
                    )
            }

            parameters[key] =
                parameterValue
        }

        return Property(
            name:
                first.uppercased(),
            parameters:
                parameters,
            value:
                value
        )
    }


    private static func makeEvent(
        _ properties:
            [String: [Property]]
    ) -> ParsedICalendarEvent? {
        guard
            let uid =
                first(
                    "UID",
                    in: properties
                )?
                .value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
            !uid.isEmpty,
            let startProperty =
                first(
                    "DTSTART",
                    in: properties
                ),
            let parsedStart =
                parseDate(
                    startProperty
                )
        else {
            return nil
        }

        let endProperty =
            first(
                "DTEND",
                in: properties
            )

        let parsedEnd =
            endProperty
                .flatMap(
                    parseDate
                )

        let endAt:
            Date

        if let parsedEnd {
            endAt =
                parsedEnd.date

        } else {
            endAt =
                Calendar.autoupdatingCurrent
                    .date(
                        byAdding:
                            parsedStart.isAllDay
                            ? .day
                            : .hour,
                        value:
                            1,
                        to:
                            parsedStart.date
                    )
                ?? parsedStart.date
        }

        let title =
            first(
                "SUMMARY",
                in: properties
            )
            .map {
                decodeText(
                    $0.value
                )
            }
            ?? "(Untitled event)"

        let notes =
            first(
                "DESCRIPTION",
                in: properties
            )
            .map {
                decodeText(
                    $0.value
                )
            }
            ?? ""

        let location =
            first(
                "LOCATION",
                in: properties
            )
            .map {
                decodeText(
                    $0.value
                )
            }

        let statusRaw =
            first(
                "STATUS",
                in: properties
            )?
            .value
            .uppercased()

        let status:
            CalendarEventStatus

        switch statusRaw {
        case "CANCELLED":
            status =
                .cancelled

        case "TENTATIVE":
            status =
                .tentative

        default:
            status =
                .confirmed
        }

        let recurrenceID =
            first(
                "RECURRENCE-ID",
                in: properties
            )?
            .value

        let recurrenceRules =
            properties[
                "RRULE",
                default: []
            ]
            .map(\.value)

        return ParsedICalendarEvent(
            uid:
                uid,
            recurrenceID:
                recurrenceID,
            title:
                title,
            notes:
                notes,
            location:
                location,
            startAt:
                parsedStart.date,
            endAt:
                endAt,
            isAllDay:
                parsedStart.isAllDay,
            startTimeZoneID:
                parsedStart.timeZoneID,
            endTimeZoneID:
                parsedEnd?.timeZoneID,
            status:
                status,
            recurrenceRules:
                recurrenceRules,
            externalURL:
                first(
                    "URL",
                    in: properties
                )?
                .value,
            createdAt:
                first(
                    "CREATED",
                    in: properties
                )
                .flatMap(
                    parseDate
                )?
                .date,
            updatedAt:
                first(
                    "LAST-MODIFIED",
                    in: properties
                )
                .flatMap(
                    parseDate
                )?
                .date
        )
    }


    private struct ParsedDate {
        let date:
            Date

        let isAllDay:
            Bool

        let timeZoneID:
            String?
    }


    private static func parseDate(
        _ property: Property
    ) -> ParsedDate? {
        let value =
            property.value

        let valueType =
            property.parameters[
                "VALUE"
            ]?
            .uppercased()

        let allDay =
            valueType == "DATE"
            || (
                value.count == 8
                && !value.contains("T")
            )

        let explicitTZID =
            property.parameters[
                "TZID"
            ]

        let timezone:
            TimeZone

        if value.hasSuffix("Z") {
            timezone =
                TimeZone(
                    secondsFromGMT: 0
                )!

        } else if
            let explicitTZID,
            let zone =
                TimeZone(
                    identifier:
                        explicitTZID
                )
        {
            timezone =
                zone

        } else {
            timezone =
                .autoupdatingCurrent
        }

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        formatter.timeZone =
            timezone

        if allDay {
            formatter.dateFormat =
                "yyyyMMdd"

        } else if value.hasSuffix("Z") {
            formatter.dateFormat =
                value.containsSeconds
                ? "yyyyMMdd'T'HHmmss'Z'"
                : "yyyyMMdd'T'HHmm'Z'"

        } else {
            formatter.dateFormat =
                value.containsSeconds
                ? "yyyyMMdd'T'HHmmss"
                : "yyyyMMdd'T'HHmm"
        }

        guard
            let date =
                formatter.date(
                    from: value
                )
        else {
            return nil
        }

        return ParsedDate(
            date:
                date,
            isAllDay:
                allDay,
            timeZoneID:
                explicitTZID
                ?? (
                    value.hasSuffix("Z")
                    ? "UTC"
                    : nil
                )
        )
    }


    private static func first(
        _ key: String,
        in properties:
            [String: [Property]]
    ) -> Property? {
        properties[
            key
        ]?
        .first
    }


    private static func decodeText(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: "\\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\\N",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\\,",
                with: ","
            )
            .replacingOccurrences(
                of: "\\;",
                with: ";"
            )
            .replacingOccurrences(
                of: "\\\\",
                with: "\\"
            )
    }


    private static func parserError(
        _ message: String
    ) -> Error {
        NSError(
            domain:
                "DReport.iCal",
            code:
                1,
            userInfo:
                [
                    NSLocalizedDescriptionKey:
                        message
                ]
        )
    }
}


extension String {
    var containsSeconds:
        Bool
    {
        let core =
            hasSuffix("Z")
            ? String(dropLast())
            : self

        guard
            let t =
                core.firstIndex(
                    of: "T"
                )
        else {
            return false
        }

        let time =
            core[
                core.index(
                    after: t
                )...
            ]

        return time.count >= 6
    }
}


// ============================================================
// MARK: - Store subscription API
// ============================================================


extension String {
    var nonEmpty:
        String?
    {
        isEmpty
        ? nil
        : self
    }
}
