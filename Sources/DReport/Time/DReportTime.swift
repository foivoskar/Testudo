import Foundation
import SwiftUI

enum DReportTime {
    static var deviceTimeZone:
        TimeZone
    {
        .autoupdatingCurrent
    }

    static var deviceTimeZoneID:
        String
    {
        deviceTimeZone.identifier
    }

    static var knownTimeZoneIdentifiers:
        [String]
    {
        TimeZone
            .knownTimeZoneIdentifiers
            .sorted {
                shortTimeZoneLabel(
                    identifier: $0
                )
                .localizedCaseInsensitiveCompare(
                    shortTimeZoneLabel(
                        identifier: $1
                    )
                )
                == .orderedAscending
            }
    }

    static func validTimeZoneIdentifier(
        _ value: String?
    ) -> String? {
        guard
            let value,
            !value.isEmpty,
            TimeZone(
                identifier: value
            ) != nil
        else {
            return nil
        }

        return value
    }

    static func timeZone(
        identifier: String?
    ) -> TimeZone {
        guard
            let identifier =
                validTimeZoneIdentifier(
                    identifier
                ),
            let zone =
                TimeZone(
                    identifier:
                        identifier
                )
        else {
            return deviceTimeZone
        }

        return zone
    }

    // --------------------------------------------------------
    // Friendly geographic names
    // --------------------------------------------------------

    private static let
        timeZoneCountryCodes:
            [String: String] =
    {
        let paths = [
            "/usr/share/zoneinfo/zone1970.tab",
            "/usr/share/zoneinfo/zone.tab"
        ]

        for path in paths {
            guard
                let contents =
                    try? String(
                        contentsOfFile:
                            path,
                        encoding:
                            .utf8
                    )
            else {
                continue
            }

            var result:
                [String: String] = [:]

            for rawLine in
                contents.split(
                    whereSeparator:
                        \.isNewline
                )
            {
                if rawLine.hasPrefix("#") {
                    continue
                }

                let columns =
                    rawLine.split(
                        separator: "\t",
                        omittingEmptySubsequences:
                            false
                    )

                guard
                    columns.count >= 3
                else {
                    continue
                }

                let country =
                    columns[0]
                        .split(
                            separator: ","
                        )
                        .first
                        .map(String.init)

                let identifier =
                    String(
                        columns[2]
                    )

                if let country {
                    result[identifier] =
                        country
                }
            }

            if !result.isEmpty {
                return result
            }
        }

        return [:]
    }()

    static func shortTimeZoneLabel(
        identifier: String
    ) -> String {
        let components =
            identifier.split(
                separator: "/"
            )

        let city =
            components.last
                .map(String.init)?
                .replacingOccurrences(
                    of: "_",
                    with: " "
                )
            ?? identifier

        if
            let countryCode =
                timeZoneCountryCodes[
                    identifier
                ],
            let country =
                Locale
                    .autoupdatingCurrent
                    .localizedString(
                        forRegionCode:
                            countryCode
                    )
        {
            return
                "\(city), \(country)"
        }

        if components.count > 1 {
            let region =
                String(
                    components[0]
                )
                .replacingOccurrences(
                    of: "_",
                    with: " "
                )

            return
                "\(city), \(region)"
        }

        return city
    }

    static func timeZoneLabel(
        identifier: String,
        referenceDate: Date = Date()
    ) -> String {
        shortTimeZoneLabel(
            identifier:
                identifier
        )
    }

    static func pickerTimeZoneLabel(
        identifier: String
    ) -> String {
        let friendly =
            shortTimeZoneLabel(
                identifier:
                    identifier
            )

        return
            "\(friendly) — \(identifier)"
    }

    // --------------------------------------------------------
    // Formatting
    // --------------------------------------------------------

    private static func formatter(
        dateStyle:
            DateFormatter.Style,
        timeStyle:
            DateFormatter.Style,
        timeZone:
            TimeZone
    ) -> DateFormatter {
        let formatter =
            DateFormatter()

        formatter.locale =
            .autoupdatingCurrent

        formatter.timeZone =
            timeZone

        formatter.dateStyle =
            dateStyle

        formatter.timeStyle =
            timeStyle

        return formatter
    }

    static func localDateTime(
        _ date: Date,
        timeZone:
            TimeZone
    ) -> String {
        formatter(
            dateStyle: .medium,
            timeStyle: .short,
            timeZone: timeZone
        )
        .string(
            from: date
        )
    }

    static func localTime(
        _ date: Date,
        timeZone:
            TimeZone
    ) -> String {
        formatter(
            dateStyle: .none,
            timeStyle: .short,
            timeZone: timeZone
        )
        .string(
            from: date
        )
    }

    static func displayDateTime(
        _ date: Date,
        sourceTimeZoneID:
            String?
    ) -> String {
        let deviceZone =
            deviceTimeZone

        let deviceText =
            localDateTime(
                date,
                timeZone:
                    deviceZone
            )

        guard
            let sourceID =
                validTimeZoneIdentifier(
                    sourceTimeZoneID
                ),
            sourceID
                != deviceZone.identifier,
            let sourceZone =
                TimeZone(
                    identifier:
                        sourceID
                )
        else {
            return deviceText
        }

        let sourceText =
            localDateTime(
                date,
                timeZone:
                    sourceZone
            )

        return
            "\(deviceText) · \(sourceText) \(shortTimeZoneLabel(identifier: sourceID))"
    }

    static func displayTime(
        _ date: Date,
        sourceTimeZoneID:
            String?
    ) -> String {
        let deviceZone =
            deviceTimeZone

        let deviceText =
            localTime(
                date,
                timeZone:
                    deviceZone
            )

        guard
            let sourceID =
                validTimeZoneIdentifier(
                    sourceTimeZoneID
                ),
            sourceID
                != deviceZone.identifier,
            let sourceZone =
                TimeZone(
                    identifier:
                        sourceID
                )
        else {
            return deviceText
        }

        let sourceText =
            localTime(
                date,
                timeZone:
                    sourceZone
            )

        return
            "\(deviceText) · \(sourceText) \(shortTimeZoneLabel(identifier: sourceID))"
    }

    // Compatibility with existing call sites.
    static func dateTime(
        _ date: Date,
        includeTimeZone:
            Bool = false
    ) -> String {
        localDateTime(
            date,
            timeZone:
                deviceTimeZone
        )
    }

    static func time(
        _ date: Date,
        includeTimeZone:
            Bool = false
    ) -> String {
        localTime(
            date,
            timeZone:
                deviceTimeZone
        )
    }

    static func utcString(
        _ date: Date
    ) -> String {
        let formatter =
            ISO8601DateFormatter()

        formatter.timeZone =
            TimeZone(
                secondsFromGMT: 0
            )

        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        return formatter.string(
            from: date
        )
    }

    // --------------------------------------------------------
    // Changing the source zone
    //
    // If a user entered 10:00 Paris and changes the picker
    // to New York, it becomes 10:00 New York rather than
    // silently turning into 04:00 New York.
    // --------------------------------------------------------

    static func reinterpreting(
        _ date: Date,
        fromTimeZoneID:
            String,
        toTimeZoneID:
            String
    ) -> Date {
        let oldZone =
            timeZone(
                identifier:
                    fromTimeZoneID
            )

        let newZone =
            timeZone(
                identifier:
                    toTimeZoneID
            )

        var oldCalendar =
            Calendar(
                identifier:
                    .gregorian
            )

        oldCalendar.timeZone =
            oldZone

        let components =
            oldCalendar
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day,
                        .hour,
                        .minute,
                        .second
                    ],
                    from: date
                )

        var newCalendar =
            Calendar(
                identifier:
                    .gregorian
            )

        newCalendar.timeZone =
            newZone

        return
            newCalendar.date(
                from:
                    components
            )
            ?? date
    }
}

// ============================================================
// Canonical IANA time-zone picker
// ============================================================

struct TimeZoneIdentifierPicker:
    View
{
    @Binding
    var selection: String

    private var validSelection:
        Binding<String>
    {
        Binding(
            get: {
                if selection.isEmpty {
                    return ""
                }

                return
                    DReportTime
                        .validTimeZoneIdentifier(
                            selection
                        )
                    ?? ""
            },
            set: {
                selection = $0
            }
        )
    }

    var body: some View {
        Picker(
            "Time zone",
            selection:
                validSelection
        ) {
            Text("Not set")
                .tag("")

            ForEach(
                DReportTime
                    .knownTimeZoneIdentifiers,
                id: \.self
            ) { identifier in
                Text(
                    DReportTime
                        .pickerTimeZoneLabel(
                            identifier:
                                identifier
                        )
                )
                .tag(identifier)
            }
        }
        .pickerStyle(.menu)
    }
}

// ============================================================
// Date + time + source-zone editor
// ============================================================

struct TimeZoneAwareDateEditor:
    View
{
    let label: String

    @Binding
    var date: Date

    @Binding
    var timeZoneID: String

    private var selectedZone:
        TimeZone
    {
        DReportTime.timeZone(
            identifier:
                timeZoneID
        )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            DatePicker(
                "",
                selection:
                    $date,
                displayedComponents:
                    [
                        .date,
                        .hourAndMinute
                    ]
            )
            .labelsHidden()
            .environment(
                \.timeZone,
                selectedZone
            )

            HStack(
                spacing: 8
            ) {
                Text("Time zone")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                TimeZoneIdentifierPicker(
                    selection:
                        $timeZoneID
                )
            }
        }
        .onAppear {
            if
                DReportTime
                    .validTimeZoneIdentifier(
                        timeZoneID
                    ) == nil
            {
                timeZoneID =
                    DReportTime
                        .deviceTimeZoneID
            }
        }
        .onChange(
            of: timeZoneID
        ) {
            oldValue,
            newValue in

            guard
                oldValue != newValue,
                !oldValue.isEmpty,
                !newValue.isEmpty
            else {
                return
            }

            date =
                DReportTime
                    .reinterpreting(
                        date,
                        fromTimeZoneID:
                            oldValue,
                        toTimeZoneID:
                            newValue
                    )
        }
    }
}
