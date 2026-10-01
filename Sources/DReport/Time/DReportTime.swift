import Foundation
import SwiftUI

enum DReportTime {
    static var deviceTimeZone: TimeZone {
        .autoupdatingCurrent
    }

    static var knownTimeZoneIdentifiers: [String] {
        TimeZone
            .knownTimeZoneIdentifiers
            .sorted {
                $0.localizedCaseInsensitiveCompare(
                    $1
                ) == .orderedAscending
            }
    }

    static func validTimeZoneIdentifier(
        _ value: String?
    ) -> String? {
        guard
            let value,
            TimeZone(identifier: value) != nil
        else {
            return nil
        }

        return value
    }

    static func dateTime(
        _ date: Date,
        includeTimeZone: Bool = false
    ) -> String {
        let formatter = DateFormatter()

        formatter.locale =
            .autoupdatingCurrent

        formatter.timeZone =
            .autoupdatingCurrent

        formatter.dateStyle =
            .medium

        formatter.timeStyle =
            .short

        var result =
            formatter.string(
                from: date
            )

        if
            includeTimeZone,
            let abbreviation =
                formatter.timeZone
                    .abbreviation(
                        for: date
                    )
        {
            result +=
                " \(abbreviation)"
        }

        return result
    }

    static func time(
        _ date: Date,
        includeTimeZone: Bool = false
    ) -> String {
        let formatter = DateFormatter()

        formatter.locale =
            .autoupdatingCurrent

        formatter.timeZone =
            .autoupdatingCurrent

        formatter.dateStyle =
            .none

        formatter.timeStyle =
            .short

        var result =
            formatter.string(
                from: date
            )

        if
            includeTimeZone,
            let abbreviation =
                formatter.timeZone
                    .abbreviation(
                        for: date
                    )
        {
            result +=
                " \(abbreviation)"
        }

        return result
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

    static func timeZoneLabel(
        identifier: String,
        referenceDate: Date = Date()
    ) -> String {
        guard
            let zone =
                TimeZone(
                    identifier:
                        identifier
                )
        else {
            return identifier
        }

        let seconds =
            zone.secondsFromGMT(
                for: referenceDate
            )

        let sign =
            seconds >= 0
            ? "+"
            : "-"

        let absolute =
            abs(seconds)

        let hours =
            absolute / 3600

        let minutes =
            (
                absolute % 3600
            ) / 60

        let offset =
            String(
                format:
                    "GMT%@%02d:%02d",
                sign,
                hours,
                minutes
            )

        return
            "\(identifier) (\(offset))"
    }
}

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

                if
                    TimeZone(
                        identifier:
                            selection
                    ) != nil
                {
                    return selection
                }

                return ""
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
                        .timeZoneLabel(
                            identifier:
                                identifier
                        )
                )
                .tag(identifier)
            }
        }
        .pickerStyle(.menu)
        .onAppear {
            if
                !selection.isEmpty,
                TimeZone(
                    identifier:
                        selection
                ) == nil
            {
                selection = ""
            }
        }
    }
}
