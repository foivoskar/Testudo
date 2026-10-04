import Foundation
import Security


// ============================================================
// MARK: - Secret URL Keychain storage
// ============================================================

enum CalendarSecretStore {
    private static let service =
        "Testudo.iCalSubscriptions"


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

    // Parsed original occurrence represented by RECURRENCE-ID.
    //
    // This gives generated occurrences and explicit exception
    // VEVENTs the same stable identity.
    var recurrenceIDAt:
        Date?

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

    // RFC 5545 recurrence-set additions/removals.
    var recurrenceDates:
        [Date]

    var exclusionDates:
        [Date]

    var externalURL:
        String?

    var createdAt:
        Date?

    var updatedAt:
        Date?

    var externalIdentity:
        String
    {
        // iCalendar recurrence values have second-level
        // precision. Use the absolute recurrence timestamp so
        // generated occurrences and explicit RECURRENCE-ID
        // exception events receive the same identity even when
        // one representation uses TZID and another UTC.
        if
            let recurrenceIDAt
        {
            let seconds =
                Int64(
                    recurrenceIDAt
                        .timeIntervalSince1970
                        .rounded()
                )

            return
                "\(uid)|\(seconds)"
        }


        // Fallback for unusual feeds whose RECURRENCE-ID could
        // not be parsed as a date.
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
                ICalendarRecurrenceExpander
                    .expand(
                        events
                    )
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

        let recurrenceIDProperty =
            first(
                "RECURRENCE-ID",
                in:
                    properties
            )

        let recurrenceID =
            recurrenceIDProperty?
                .value

        let recurrenceIDAt =
            recurrenceIDProperty
                .flatMap(
                    parseDate
                )?
                .date


        let recurrenceRules =
            properties[
                "RRULE",
                default:
                    []
            ]
            .map(
                \.value
            )


        let recurrenceDates =
            properties[
                "RDATE",
                default:
                    []
            ]
            .flatMap {
                parseDateList(
                    $0
                )
            }
            .map(
                \.date
            )


        let exclusionDates =
            properties[
                "EXDATE",
                default:
                    []
            ]
            .flatMap {
                parseDateList(
                    $0
                )
            }
            .map(
                \.date
            )

        return ParsedICalendarEvent(
            uid:
                uid,
            recurrenceID:
                recurrenceID,
            recurrenceIDAt:
                recurrenceIDAt,
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
            recurrenceDates:
                recurrenceDates,
            exclusionDates:
                exclusionDates,
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


    private static func parseDateList(
        _ property:
            Property
    ) -> [ParsedDate] {

        property
            .value
            .split(
                separator:
                    ",",
                omittingEmptySubsequences:
                    true
            )
            .compactMap {
                component in

                parseDate(
                    Property(
                        name:
                            property.name,
                        parameters:
                            property.parameters,
                        value:
                            String(
                                component
                            )
                    )
                )
            }
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
                "Testudo.iCal",
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



// ============================================================
// MARK: - iCalendar recurrence expansion
//
// iCal feeds normally store recurring meetings as:
//
//     DTSTART + RRULE
//
// rather than one VEVENT per occurrence.
//
// Testudo stores concrete CalendarEvent rows, so the recurrence
// set is expanded during each subscription sync.
//
// The expansion window intentionally matches the Apple/EventKit
// integration:
//
//     one year in the past
//     two years in the future
//
// DTSTART itself is retained even when older than that window so
// the original imported event keeps its existing Testudo UUID and
// any Work/Theme relationships already attached to it.
//
// Supported recurrence components:
//
// • FREQ=DAILY / WEEKLY / MONTHLY / YEARLY
// • INTERVAL
// • COUNT
// • UNTIL
// • BYDAY, including ordinal weekdays
// • BYMONTHDAY, including negative values
// • BYMONTH
// • BYSETPOS
// • WKST
// • RDATE
// • EXDATE
// • explicit RECURRENCE-ID exception/cancellation VEVENTs
//
// Unsupported exotic RRULE components are ignored rather than
// causing the complete calendar sync to fail.
// ============================================================

enum ICalendarRecurrenceExpander {

    private struct WeekdayRule {
        let weekday:
            Int

        let ordinal:
            Int?
    }


    private struct Rule {
        let frequency:
            String

        let interval:
            Int

        let count:
            Int?

        let until:
            Date?

        let byDays:
            [WeekdayRule]

        let byMonthDays:
            [Int]

        let byMonths:
            [Int]

        let bySetPositions:
            [Int]

        let weekStart:
            Int
    }


    static func expand(
        _ events:
            [ParsedICalendarEvent],
        now:
            Date = Date()
    ) -> [ParsedICalendarEvent] {

        let systemCalendar =
            Calendar
                .autoupdatingCurrent

        let windowStart =
            systemCalendar
                .date(
                    byAdding:
                        .year,
                    value:
                        -1,
                    to:
                        now
                )
            ?? now
                .addingTimeInterval(
                    -365 * 24 * 3600
                )

        let windowEnd =
            systemCalendar
                .date(
                    byAdding:
                        .year,
                    value:
                        2,
                    to:
                        now
                )
            ?? now
                .addingTimeInterval(
                    2 * 365 * 24 * 3600
                )


        let masters =
            events.filter {
                $0.recurrenceID
                    == nil
            }

        let exceptions =
            events.filter {
                $0.recurrenceID
                    != nil
            }


        var expanded:
            [ParsedICalendarEvent] = []


        for master in masters {

            guard
                !master
                    .recurrenceRules
                    .isEmpty
                || !master
                    .recurrenceDates
                    .isEmpty
            else {
                expanded.append(
                    master
                )

                continue
            }


            expanded
                .append(
                    contentsOf:
                        expandMaster(
                            master,
                            windowStart:
                                windowStart,
                            windowEnd:
                                windowEnd
                        )
                )
        }


        // ----------------------------------------------------
        // Apply explicit RECURRENCE-ID exception VEVENTs.
        //
        // They may move, modify or cancel one generated
        // occurrence.
        // ----------------------------------------------------

        for exception in exceptions {

            guard
                let recurrenceIDAt =
                    exception
                        .recurrenceIDAt
            else {
                // Unparseable RECURRENCE-ID: preserve the event
                // rather than silently dropping feed content.
                replaceOrAppend(
                    exception,
                    in:
                        &expanded
                )

                continue
            }


            // Exception targeting DTSTART should replace the
            // stable master identity rather than create a second
            // copy of the first occurrence.
            if
                let master =
                    masters.first(
                        where: {
                            $0.uid
                                == exception.uid
                            && sameMoment(
                                $0.startAt,
                                recurrenceIDAt
                            )
                        }
                    )
            {
                var normalized =
                    exception

                normalized.recurrenceID =
                    nil

                normalized.recurrenceIDAt =
                    nil

                normalized.recurrenceRules =
                    master
                        .recurrenceRules

                normalized.recurrenceDates =
                    master
                        .recurrenceDates

                normalized.exclusionDates =
                    master
                        .exclusionDates


                replaceOrAppend(
                    normalized,
                    in:
                        &expanded
                )

                continue
            }


            replaceOrAppend(
                exception,
                in:
                    &expanded
            )
        }


        // Stable de-duplication after RRULE/RDATE/exception union.
        var unique:
            [String: ParsedICalendarEvent] =
            [:]

        for event in expanded {
            unique[
                event.externalIdentity
            ] =
                event
        }


        return
            unique
                .values
                .sorted {
                    lhs,
                    rhs in

                    if
                        lhs.startAt
                            != rhs.startAt
                    {
                        return
                            lhs.startAt
                            < rhs.startAt
                    }

                    return
                        lhs.title
                            .localizedCaseInsensitiveCompare(
                                rhs.title
                            )
                            == .orderedAscending
                }
    }


    // ========================================================
    // MARK: One recurring master
    // ========================================================

    private static func expandMaster(
        _ master:
            ParsedICalendarEvent,
        windowStart:
            Date,
        windowEnd:
            Date
    ) -> [ParsedICalendarEvent] {

        let duration =
            max(
                0,
                master.endAt
                    .timeIntervalSince(
                        master.startAt
                    )
            )


        var occurrenceDates:
            [Int64: Date] =
            [:]


        // DTSTART is part of the recurrence set and is retained
        // even if it predates the rolling expansion window.
        occurrenceDates[
            momentKey(
                master.startAt
            )
        ] =
            master.startAt


        for rawRule in
            master.recurrenceRules
        {
            guard
                let rule =
                    parseRule(
                        rawRule,
                        master:
                            master
                    )
            else {
                continue
            }


            for date in
                dates(
                    matching:
                        rule,
                    master:
                        master,
                    windowStart:
                        windowStart,
                    windowEnd:
                        windowEnd
                )
            {
                occurrenceDates[
                    momentKey(
                        date
                    )
                ] =
                    date
            }
        }


        // RFC RDATE contributes additional occurrences.
        for date in
            master.recurrenceDates
        {
            occurrenceDates[
                momentKey(
                    date
                )
            ] =
                date
        }


        // RFC EXDATE wins over DTSTART, RRULE and RDATE.
        for date in
            master.exclusionDates
        {
            occurrenceDates
                .removeValue(
                    forKey:
                        momentKey(
                            date
                        )
                )
        }


        return
            occurrenceDates
                .values
                .sorted()
                .compactMap {
                    date in

                    // Keep the original master event exactly as
                    // it was so its external identity remains UID.
                    if
                        sameMoment(
                            date,
                            master.startAt
                        )
                    {
                        return master
                    }


                    // Generated occurrences are bounded. Explicit
                    // RDATEs are also accepted when inside the
                    // same rolling window.
                    guard
                        date >= windowStart,
                        date < windowEnd
                    else {
                        return nil
                    }


                    var occurrence =
                        master

                    occurrence.startAt =
                        date

                    occurrence.endAt =
                        date
                            .addingTimeInterval(
                                duration
                            )

                    occurrence.recurrenceID =
                        String(
                            momentKey(
                                date
                            )
                        )

                    occurrence.recurrenceIDAt =
                        date

                    // These belong to the master recurrence set;
                    // an individual concrete occurrence does not
                    // need to recursively carry them for expansion.
                    occurrence.recurrenceDates =
                        []

                    occurrence.exclusionDates =
                        []


                    return occurrence
                }
    }


    // ========================================================
    // MARK: Rule generation
    // ========================================================

    private static func dates(
        matching rule:
            Rule,
        master:
            ParsedICalendarEvent,
        windowStart:
            Date,
        windowEnd:
            Date
    ) -> [Date] {

        var calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        calendar.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        calendar.timeZone =
            TimeZone(
                identifier:
                    master
                        .startTimeZoneID
                ?? ""
            )
            ?? .autoupdatingCurrent


        let startDay =
            calendar
                .startOfDay(
                    for:
                        master.startAt
                )

        let endDay =
            calendar
                .startOfDay(
                    for:
                        windowEnd
                )


        var day =
            startDay

        var result:
            [Date] = []

        var recurrenceCount =
            0

        var iterations =
            0


        // Defensive cap for malformed/unbounded feeds.
        let maximumIterations =
            200_000


        while
            day <= endDay,
            iterations < maximumIterations
        {
            iterations += 1


            guard
                let candidate =
                    occurrenceDate(
                        on:
                            day,
                        master:
                            master,
                        calendar:
                            calendar
                    )
            else {
                day =
                    calendar
                        .date(
                            byAdding:
                                .day,
                            value:
                                1,
                            to:
                                day
                        )
                    ?? day
                        .addingTimeInterval(
                            86400
                        )

                continue
            }


            if
                candidate
                    >= master.startAt
                && matches(
                    candidate,
                    master:
                        master,
                    rule:
                        rule,
                    calendar:
                        calendar
                )
            {
                if
                    let until =
                        rule.until,
                    candidate > until
                {
                    break
                }


                recurrenceCount += 1


                if
                    let count =
                        rule.count,
                    recurrenceCount > count
                {
                    break
                }


                if
                    candidate >= windowStart,
                    candidate < windowEnd
                {
                    result.append(
                        candidate
                    )
                }


                if
                    let count =
                        rule.count,
                    recurrenceCount >= count
                {
                    break
                }
            }


            guard
                let next =
                    calendar
                        .date(
                            byAdding:
                                .day,
                            value:
                                1,
                            to:
                                day
                        )
            else {
                break
            }

            day =
                next
        }


        return result
    }


    private static func matches(
        _ candidate:
            Date,
        master:
            ParsedICalendarEvent,
        rule:
            Rule,
        calendar:
            Calendar
    ) -> Bool {

        let startDay =
            calendar
                .startOfDay(
                    for:
                        master.startAt
                )

        let candidateDay =
            calendar
                .startOfDay(
                    for:
                        candidate
                )


        guard
            candidateDay >= startDay
        else {
            return false
        }


        let candidateComponents =
            calendar
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day,
                        .weekday
                    ],
                    from:
                        candidate
                )

        let masterComponents =
            calendar
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day,
                        .weekday
                    ],
                    from:
                        master.startAt
                )


        guard
            let candidateYear =
                candidateComponents.year,
            let candidateMonth =
                candidateComponents.month,
            let candidateDayNumber =
                candidateComponents.day,
            let candidateWeekday =
                candidateComponents.weekday,
            let masterYear =
                masterComponents.year,
            let masterMonth =
                masterComponents.month,
            let masterDayNumber =
                masterComponents.day,
            let masterWeekday =
                masterComponents.weekday
        else {
            return false
        }


        if
            !rule
                .byMonths
                .isEmpty,
            !rule
                .byMonths
                .contains(
                    candidateMonth
                )
        {
            return false
        }


        switch
            rule.frequency
        {

        case "DAILY":

            let dayDifference =
                calendar
                    .dateComponents(
                        [
                            .day
                        ],
                        from:
                            startDay,
                        to:
                            candidateDay
                    )
                    .day
                ?? -1


            guard
                dayDifference >= 0,
                dayDifference
                    % rule.interval
                    == 0
            else {
                return false
            }


            if
                !rule.byDays.isEmpty,
                !rule.byDays.contains(
                    where: {
                        $0.weekday
                            == candidateWeekday
                    }
                )
            {
                return false
            }


            return
                matchesMonthDayConstraint(
                    candidateDayNumber,
                    year:
                        candidateYear,
                    month:
                        candidateMonth,
                    values:
                        rule.byMonthDays,
                    calendar:
                        calendar
                )


        case "WEEKLY":

            let masterWeekStart =
                startOfWeek(
                    startDay,
                    firstWeekday:
                        rule.weekStart,
                    calendar:
                        calendar
                )

            let candidateWeekStart =
                startOfWeek(
                    candidateDay,
                    firstWeekday:
                        rule.weekStart,
                    calendar:
                        calendar
                )

            let days =
                calendar
                    .dateComponents(
                        [
                            .day
                        ],
                        from:
                            masterWeekStart,
                        to:
                            candidateWeekStart
                    )
                    .day
                ?? -1


            guard
                days >= 0,
                (days / 7)
                    % rule.interval
                    == 0
            else {
                return false
            }


            let allowedWeekdays =
                rule.byDays.isEmpty
                ? [
                    masterWeekday
                ]
                : rule.byDays
                    .map(
                        \.weekday
                    )


            guard
                allowedWeekdays
                    .contains(
                        candidateWeekday
                    )
            else {
                return false
            }


            return
                matchesMonthDayConstraint(
                    candidateDayNumber,
                    year:
                        candidateYear,
                    month:
                        candidateMonth,
                    values:
                        rule.byMonthDays,
                    calendar:
                        calendar
                )


        case "MONTHLY":

            let monthDifference =
                (
                    candidateYear
                    - masterYear
                )
                * 12
                + (
                    candidateMonth
                    - masterMonth
                )


            guard
                monthDifference >= 0,
                monthDifference
                    % rule.interval
                    == 0
            else {
                return false
            }


            let validDays =
                selectedDays(
                    year:
                        candidateYear,
                    month:
                        candidateMonth,
                    masterDay:
                        masterDayNumber,
                    rule:
                        rule,
                    calendar:
                        calendar
                )


            return
                validDays
                    .contains(
                        candidateDayNumber
                    )


        case "YEARLY":

            let yearDifference =
                candidateYear
                - masterYear


            guard
                yearDifference >= 0,
                yearDifference
                    % rule.interval
                    == 0
            else {
                return false
            }


            let allowedMonths =
                rule.byMonths.isEmpty
                ? [
                    masterMonth
                ]
                : rule.byMonths


            guard
                allowedMonths
                    .contains(
                        candidateMonth
                    )
            else {
                return false
            }


            let validDays =
                selectedDays(
                    year:
                        candidateYear,
                    month:
                        candidateMonth,
                    masterDay:
                        masterDayNumber,
                    rule:
                        rule,
                    calendar:
                        calendar
                )


            return
                validDays
                    .contains(
                        candidateDayNumber
                    )


        default:
            return false
        }
    }


    // ========================================================
    // MARK: Monthly/yearly selectors
    // ========================================================

    private static func selectedDays(
        year:
            Int,
        month:
            Int,
        masterDay:
            Int,
        rule:
            Rule,
        calendar:
            Calendar
    ) -> Set<Int> {

        var components =
            DateComponents()

        components.year =
            year

        components.month =
            month

        components.day =
            1


        guard
            let firstDate =
                calendar
                    .date(
                        from:
                            components
                    ),
            let range =
                calendar
                    .range(
                        of:
                            .day,
                        in:
                            .month,
                        for:
                            firstDate
                    )
        else {
            return []
        }


        let daysInMonth =
            range.count

        var eligible =
            Set(
                range
            )


        // BYMONTHDAY
        if
            !rule
                .byMonthDays
                .isEmpty
        {
            let allowed =
                Set(
                    rule.byMonthDays
                        .compactMap {
                            value
                            -> Int? in

                            resolvedMonthDay(
                                value,
                                daysInMonth:
                                    daysInMonth
                            )
                        }
                )

            eligible
                .formIntersection(
                    allowed
                )
        }


        // BYDAY, including 1MO / -1FR etc.
        if
            !rule
                .byDays
                .isEmpty
        {
            var allowed:
                Set<Int> = []


            for weekdayRule in
                rule.byDays
            {
                var matchingDays:
                    [Int] = []


                for day in range {

                    var dayComponents =
                        components

                    dayComponents.day =
                        day


                    guard
                        let date =
                            calendar
                                .date(
                                    from:
                                        dayComponents
                                )
                    else {
                        continue
                    }


                    if
                        calendar
                            .component(
                                .weekday,
                                from:
                                    date
                            )
                            == weekdayRule
                                .weekday
                    {
                        matchingDays
                            .append(
                                day
                            )
                    }
                }


                if
                    let ordinal =
                        weekdayRule
                            .ordinal
                {
                    let index =
                        ordinal > 0
                        ? ordinal - 1
                        : matchingDays.count
                            + ordinal

                    if
                        matchingDays
                            .indices
                            .contains(
                                index
                            )
                    {
                        allowed
                            .insert(
                                matchingDays[
                                    index
                                ]
                            )
                    }

                } else {

                    allowed
                        .formUnion(
                            matchingDays
                        )
                }
            }


            eligible
                .formIntersection(
                    allowed
                )
        }


        // No explicit day selector -> DTSTART day-of-month.
        if
            rule.byMonthDays.isEmpty,
            rule.byDays.isEmpty
        {
            eligible =
                masterDay <= daysInMonth
                ? [
                    masterDay
                ]
                : []
        }


        // BYSETPOS is evaluated after the other selectors.
        if
            !rule
                .bySetPositions
                .isEmpty
        {
            let sorted =
                eligible
                    .sorted()

            var positioned:
                Set<Int> = []


            for position in
                rule.bySetPositions
            {
                let index =
                    position > 0
                    ? position - 1
                    : sorted.count
                        + position


                if
                    sorted.indices
                        .contains(
                            index
                        )
                {
                    positioned
                        .insert(
                            sorted[
                                index
                            ]
                        )
                }
            }


            eligible =
                positioned
        }


        return eligible
    }


    private static func matchesMonthDayConstraint(
        _ day:
            Int,
        year:
            Int,
        month:
            Int,
        values:
            [Int],
        calendar:
            Calendar
    ) -> Bool {

        guard
            !values.isEmpty
        else {
            return true
        }


        var components =
            DateComponents()

        components.year =
            year

        components.month =
            month

        components.day =
            1


        guard
            let first =
                calendar
                    .date(
                        from:
                            components
                    ),
            let range =
                calendar
                    .range(
                        of:
                            .day,
                        in:
                            .month,
                        for:
                            first
                    )
        else {
            return false
        }


        let daysInMonth =
            range.count


        return
            values
                .compactMap {
                    resolvedMonthDay(
                        $0,
                        daysInMonth:
                            daysInMonth
                    )
                }
                .contains(
                    day
                )
    }


    private static func resolvedMonthDay(
        _ value:
            Int,
        daysInMonth:
            Int
    ) -> Int? {

        if
            value > 0,
            value <= daysInMonth
        {
            return value
        }


        if
            value < 0
        {
            let resolved =
                daysInMonth
                + value
                + 1

            return
                resolved >= 1
                && resolved <= daysInMonth
                ? resolved
                : nil
        }


        return nil
    }


    // ========================================================
    // MARK: Rule parsing
    // ========================================================

    private static func parseRule(
        _ raw:
            String,
        master:
            ParsedICalendarEvent
    ) -> Rule? {

        var values:
            [String: String] =
            [:]


        for component in
            raw
                .split(
                    separator:
                        ";"
                )
        {
            let pair =
                component
                    .split(
                        separator:
                            "=",
                        maxSplits:
                            1
                    )


            guard
                pair.count
                    == 2
            else {
                continue
            }


            values[
                String(
                    pair[0]
                )
                .uppercased()
            ] =
                String(
                    pair[1]
                )
        }


        guard
            let frequency =
                values[
                    "FREQ"
                ]?
                .uppercased(),
            [
                "DAILY",
                "WEEKLY",
                "MONTHLY",
                "YEARLY",
            ]
            .contains(
                frequency
            )
        else {
            return nil
        }


        let interval =
            max(
                1,
                Int(
                    values[
                        "INTERVAL"
                    ]
                    ?? "1"
                )
                ?? 1
            )


        let count =
            values[
                "COUNT"
            ]
            .flatMap(
                Int.init
            )


        let until =
            values[
                "UNTIL"
            ]
            .flatMap {
                parseUntil(
                    $0,
                    master:
                        master
                )
            }


        let byDays =
            csv(
                values[
                    "BYDAY"
                ]
            )
            .compactMap(
                parseWeekday
            )


        let byMonthDays =
            csv(
                values[
                    "BYMONTHDAY"
                ]
            )
            .compactMap(
                Int.init
            )


        let byMonths =
            csv(
                values[
                    "BYMONTH"
                ]
            )
            .compactMap(
                Int.init
            )
            .filter {
                1...12
                    ~= $0
            }


        let bySetPositions =
            csv(
                values[
                    "BYSETPOS"
                ]
            )
            .compactMap(
                Int.init
            )
            .filter {
                $0
                    != 0
            }


        let weekStart =
            values[
                "WKST"
            ]
            .flatMap(
                weekdayNumber
            )
            ?? 2  // Monday


        return
            Rule(
                frequency:
                    frequency,
                interval:
                    interval,
                count:
                    count,
                until:
                    until,
                byDays:
                    byDays,
                byMonthDays:
                    byMonthDays,
                byMonths:
                    byMonths,
                bySetPositions:
                    bySetPositions,
                weekStart:
                    weekStart
            )
    }


    private static func csv(
        _ raw:
            String?
    ) -> [String] {

        guard
            let raw
        else {
            return []
        }


        return
            raw
                .split(
                    separator:
                        ","
                )
                .map(
                    String.init
                )
    }


    private static func parseWeekday(
        _ raw:
            String
    ) -> WeekdayRule? {

        let cleaned =
            raw
                .uppercased()


        guard
            cleaned.count >= 2
        else {
            return nil
        }


        let suffix =
            String(
                cleaned
                    .suffix(
                        2
                    )
            )


        guard
            let weekday =
                weekdayNumber(
                    suffix
                )
        else {
            return nil
        }


        let prefix =
            String(
                cleaned
                    .dropLast(
                        2
                    )
            )


        let ordinal =
            prefix.isEmpty
            ? nil
            : Int(
                prefix
            )


        return
            WeekdayRule(
                weekday:
                    weekday,
                ordinal:
                    ordinal
            )
    }


    private static func weekdayNumber(
        _ raw:
            String
    ) -> Int? {

        switch
            raw
                .uppercased()
        {
        case "SU":
            return 1

        case "MO":
            return 2

        case "TU":
            return 3

        case "WE":
            return 4

        case "TH":
            return 5

        case "FR":
            return 6

        case "SA":
            return 7

        default:
            return nil
        }
    }


    private static func parseUntil(
        _ raw:
            String,
        master:
            ParsedICalendarEvent
    ) -> Date? {

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


        if
            raw.hasSuffix(
                "Z"
            )
        {
            formatter.timeZone =
                TimeZone(
                    secondsFromGMT:
                        0
                )

            formatter.dateFormat =
                raw.containsSeconds
                ? "yyyyMMdd'T'HHmmss'Z'"
                : "yyyyMMdd'T'HHmm'Z'"

        } else if
            raw.count
                == 8,
            !raw.contains(
                "T"
            )
        {
            formatter.timeZone =
                TimeZone(
                    identifier:
                        master
                            .startTimeZoneID
                    ?? ""
                )
                ?? .autoupdatingCurrent

            formatter.dateFormat =
                "yyyyMMdd"

        } else {

            formatter.timeZone =
                TimeZone(
                    identifier:
                        master
                            .startTimeZoneID
                    ?? ""
                )
                ?? .autoupdatingCurrent

            formatter.dateFormat =
                raw.containsSeconds
                ? "yyyyMMdd'T'HHmmss"
                : "yyyyMMdd'T'HHmm"
        }


        return
            formatter
                .date(
                    from:
                        raw
                )
    }


    // ========================================================
    // MARK: Date helpers
    // ========================================================

    private static func occurrenceDate(
        on day:
            Date,
        master:
            ParsedICalendarEvent,
        calendar:
            Calendar
    ) -> Date? {

        if master.isAllDay {
            return
                calendar
                    .startOfDay(
                        for:
                            day
                    )
        }


        let time =
            calendar
                .dateComponents(
                    [
                        .hour,
                        .minute,
                        .second
                    ],
                    from:
                        master.startAt
                )


        var components =
            calendar
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day
                    ],
                    from:
                        day
                )

        components.hour =
            time.hour

        components.minute =
            time.minute

        components.second =
            time.second


        return
            calendar
                .date(
                    from:
                        components
                )
    }


    private static func startOfWeek(
        _ date:
            Date,
        firstWeekday:
            Int,
        calendar:
            Calendar
    ) -> Date {

        let weekday =
            calendar
                .component(
                    .weekday,
                    from:
                        date
                )

        let offset =
            (
                weekday
                - firstWeekday
                + 7
            )
            % 7


        return
            calendar
                .date(
                    byAdding:
                        .day,
                    value:
                        -offset,
                    to:
                        calendar
                            .startOfDay(
                                for:
                                    date
                            )
                )
            ?? date
    }


    private static func momentKey(
        _ date:
            Date
    ) -> Int64 {

        Int64(
            date
                .timeIntervalSince1970
                .rounded()
        )
    }


    private static func sameMoment(
        _ lhs:
            Date,
        _ rhs:
            Date
    ) -> Bool {

        momentKey(
            lhs
        )
        ==
        momentKey(
            rhs
        )
    }


    private static func replaceOrAppend(
        _ event:
            ParsedICalendarEvent,
        in events:
            inout [ParsedICalendarEvent]
    ) {

        if
            let index =
                events
                    .firstIndex(
                        where: {
                            $0.externalIdentity
                                == event.externalIdentity
                        }
                    )
        {
            events[
                index
            ] =
                event

        } else {

            events
                .append(
                    event
                )
        }
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
