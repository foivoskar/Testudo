import Foundation
import SwiftUI

enum TestudoTime {
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
    @EnvironmentObject
    private var store:
        TestudoStore

    @Binding
    var selection:
        String

    @State
    private var showingPicker =
        false

    @State
    private var searchText =
        ""


    private var normalizedSelection:
        String
    {
        if selection.isEmpty {
            return ""
        }

        return
            TestudoTime
                .validTimeZoneIdentifier(
                    selection
                )
            ?? ""
    }


    private var frequentTimeZones:
        [String]
    {
        store
            .mostUsedTimeZoneIdentifiers(
                limit:
                    5
            )
    }


    private var remainingTimeZones:
        [String]
    {
        let frequent =
            Set(
                frequentTimeZones
            )

        return
            TestudoTime
                .knownTimeZoneIdentifiers
                .filter {
                    !frequent
                        .contains(
                            $0
                        )
                }
    }


    private var searchResults:
        [String]
    {
        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard
            !query.isEmpty
        else {
            return []
        }

        return
            TestudoTime
                .knownTimeZoneIdentifiers
                .filter {
                    identifier in

                    identifier
                        .lowercased()
                        .contains(
                            query
                        )
                    ||
                    TestudoTime
                        .pickerTimeZoneLabel(
                            identifier:
                                identifier
                        )
                        .lowercased()
                        .contains(
                            query
                        )
                }
    }


    var body:
        some View
    {
        LabeledContent(
            "Time zone"
        ) {
            Button {
                searchText =
                    ""

                showingPicker =
                    true

            } label: {
                HStack(
                    spacing:
                        8
                ) {
                    Text(
                        normalizedSelection
                            .isEmpty
                        ? "Not set"
                        : TestudoTime
                            .shortTimeZoneLabel(
                                identifier:
                                    normalizedSelection
                            )
                    )
                    .lineLimit(1)

                    Spacer(
                        minLength:
                            8
                    )

                    Image(
                        systemName:
                            "chevron.up.chevron.down"
                    )
                    .font(
                        .system(
                            size:
                                9,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .frame(
                    minWidth:
                        280,
                    alignment:
                        .leading
                )
            }
            .buttonStyle(
                .bordered
            )
            .popover(
                isPresented:
                    $showingPicker,
                arrowEdge:
                    .bottom
            ) {
                pickerContent
            }
        }
    }


    private var pickerContent:
        some View
    {
        VStack(
            spacing:
                0
        ) {
            HStack(
                spacing:
                    8
            ) {
                Image(
                    systemName:
                        "magnifyingglass"
                )
                .foregroundStyle(
                    .secondary
                )

                TextField(
                    "Search time zones",
                    text:
                        $searchText
                )
                .textFieldStyle(
                    .plain
                )

                if
                    !searchText
                        .isEmpty
                {
                    Button {
                        searchText =
                            ""

                    } label: {
                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                }
            }
            .padding(
                .horizontal,
                12
            )
            .frame(
                height:
                    40
            )

            Divider()

            ScrollView {
                LazyVStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {
                    if
                        searchText
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                    {
                        if
                            !frequentTimeZones
                                .isEmpty
                        {
                            sectionHeader(
                                "Frequently used"
                            )

                            ForEach(
                                frequentTimeZones,
                                id:
                                    \.self
                            ) {
                                identifier in

                                timeZoneRow(
                                    identifier
                                )
                            }

                            Divider()
                                .padding(
                                    .vertical,
                                    5
                                )
                        }

                        sectionHeader(
                            "All time zones"
                        )

                        ForEach(
                            remainingTimeZones,
                            id:
                                \.self
                        ) {
                            identifier in

                            timeZoneRow(
                                identifier
                            )
                        }

                    } else if
                        searchResults
                            .isEmpty
                    {
                        Text(
                            "No time zones found"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .padding(
                            .vertical,
                            30
                        )

                    } else {
                        sectionHeader(
                            "Search results"
                        )

                        ForEach(
                            searchResults,
                            id:
                                \.self
                        ) {
                            identifier in

                            timeZoneRow(
                                identifier
                            )
                        }
                    }
                }
                .padding(
                    8
                )
            }

            Divider()

            Button {
                selection =
                    ""

                showingPicker =
                    false

            } label: {
                HStack {
                    Image(
                        systemName:
                            normalizedSelection
                                .isEmpty
                        ? "checkmark"
                        : "circle"
                    )
                    .frame(
                        width:
                            18
                    )

                    Text(
                        "Not set"
                    )

                    Spacer()
                }
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .padding(
                12
            )
        }
        .frame(
            width:
                460,
            height:
                480
        )
        .background(
            TestudoStyle
                .contentBackground
        )
    }


    private func timeZoneRow(
        _ identifier:
            String
    ) -> some View
    {
        Button {
            selection =
                identifier

            showingPicker =
                false

        } label: {
            HStack(
                spacing:
                    10
            ) {
                Image(
                    systemName:
                        identifier
                            == normalizedSelection
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    identifier
                        == normalizedSelection
                    ? Color.accentColor
                    : Color.secondary
                )

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        1
                ) {
                    Text(
                        TestudoTime
                            .shortTimeZoneLabel(
                                identifier:
                                    identifier
                            )
                    )

                    Text(
                        identifier
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()
            }
            .padding(
                .horizontal,
                8
            )
            .padding(
                .vertical,
                6
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .plain
        )
    }


    private func sectionHeader(
        _ title:
            String
    ) -> some View
    {
        Text(
            title
        )
        .font(
            .caption
        )
        .fontWeight(
            .semibold
        )
        .foregroundStyle(
            .secondary
        )
        .padding(
            .horizontal,
            8
        )
        .padding(
            .top,
            5
        )
        .padding(
            .bottom,
            3
        )
    }
}


// ============================================================
// Date + time + source-zone editor
// ============================================================

struct TimeZoneAwareDateEditor:
    View
{
    let label:
        String

    @Binding
    var date:
        Date

    @Binding
    var timeZoneID:
        String

    var includesTime:
        Bool = true


    @State
    private var showingEditor =
        false

    @State
    private var draftDate =
        Date()

    @State
    private var draftTimeZoneID =
        TestudoTime.deviceTimeZoneID


    var body: some View {
        DetailSelectionRow(
            label:
                label,
            valueText:
                includesTime
                ? TestudoTime
                    .displayDateTime(
                        date,
                        sourceTimeZoneID:
                            timeZoneID
                    )
                : date.formatted(
                    date:
                        .abbreviated,
                    time:
                        .omitted
                ),
            buttonSystemImage:
                "pencil",
            helpText:
                "Edit \(label.lowercased())",
            isPresented:
                $showingEditor,
            onEdit: {
                draftDate =
                    date

                draftTimeZoneID =
                    TestudoTime
                        .validTimeZoneIdentifier(
                            timeZoneID
                        )
                    ?? TestudoTime
                        .deviceTimeZoneID

                showingEditor =
                    true
            }
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    0
            ) {
                VStack(
                    alignment:
                        .leading,
                    spacing: 5
                ) {
                    Text(label)
                        .font(.headline)

                    Text(
                        includesTime
                        ? "Choose the date, time and source time zone."
                        : "Choose the date."
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .top,
                    18
                )
                .padding(
                    .bottom,
                    14
                )

                Divider()

                LargeDateTimeEditor(
                    date:
                        $draftDate,
                    timeZoneID:
                        $draftTimeZoneID,
                    includesTime:
                        includesTime,
                    showsTimeZone:
                        includesTime
                )
                .padding(
                    .horizontal,
                    10
                )
                .padding(
                    .vertical,
                    8
                )

                Divider()

                HStack {
                    Spacer()

                    Button(
                        "Cancel"
                    ) {
                        showingEditor =
                            false
                    }
                    .keyboardShortcut(
                        .cancelAction
                    )

                    Button(
                        "Save"
                    ) {
                        date =
                            draftDate

                        if includesTime {
                            timeZoneID =
                                draftTimeZoneID
                        }

                        showingEditor =
                            false
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .keyboardShortcut(
                        .defaultAction
                    )
                }
                .padding(
                    .horizontal,
                    18
                )
                .padding(
                    .vertical,
                    14
                )
            }
            .frame(
                width: 780
            )
            .background(
                TestudoStyle
                    .contentBackground
            )
        }
    }
}
