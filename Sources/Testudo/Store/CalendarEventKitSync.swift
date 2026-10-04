import Foundation
@preconcurrency import EventKit


// ============================================================
// MARK: - Apple Calendar descriptors
// ============================================================

struct AppleCalendarCandidate:
    Identifiable,
    Hashable
{
    let identifier:
        String

    let title:
        String

    let sourceTitle:
        String


    var id:
        String
    {
        identifier
    }


    var displayName:
        String
    {
        let cleanedSource =
            sourceTitle
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanedSource.isEmpty,
            cleanedSource
                .localizedCaseInsensitiveCompare(
                    title
                )
                != .orderedSame
        else {
            return title
        }

        return
            "\(title) — \(cleanedSource)"
    }
}


// ============================================================
// MARK: - Read-only EventKit snapshot
// ============================================================

struct AppleCalendarEventSnapshot
{
    let eventIdentifier:
        String?

    let calendarItemIdentifier:
        String

    let calendarItemExternalIdentifier:
        String?

    let title:
        String

    let notes:
        String

    let location:
        String?

    let startAt:
        Date

    let endAt:
        Date

    let isAllDay:
        Bool

    let timeZoneID:
        String?

    let status:
        CalendarEventStatus

    let recurrenceRules:
        [String]

    let occurrenceDate:
        Date?

    let externalURL:
        String?

    let organizerName:
        String?

    let organizerEmail:
        String?

    let attendeeEmails:
        [String]

    let createdAt:
        Date?

    let updatedAt:
        Date?
}


struct AppleCalendarFetchResult
{
    let calendar:
        AppleCalendarCandidate

    let windowStart:
        Date

    let windowEnd:
        Date

    let events:
        [AppleCalendarEventSnapshot]
}


// ============================================================
// MARK: - EventKit errors
// ============================================================

enum AppleCalendarEventKitError:
    LocalizedError
{
    case accessDenied
    case calendarNotFound


    var errorDescription:
        String?
    {
        switch self {
        case .accessDenied:
            return
                "Testudo does not currently have access to Apple Calendar. Grant Calendar access in System Settings → Privacy & Security → Calendars."

        case .calendarNotFound:
            return
                "This Apple Calendar is not available on this Mac. It may belong to another iCloud account or another computer."
        }
    }
}


// ============================================================
// MARK: - EventKit bridge
//
// IMPORTANT:
// Testudo uses EventKit only for READ operations here.
// There are intentionally no save/remove EventKit calls.
// ============================================================

@MainActor
final class AppleCalendarEventKitBridge
{
    static let shared =
        AppleCalendarEventKitBridge()


    private let eventStore =
        EKEventStore()


    private init() {}


    func requestFullAccessIfNeeded()
        async throws
    {
        let status =
            EKEventStore
                .authorizationStatus(
                    for:
                        .event
                )

        switch status {
        case .fullAccess:
            return

        case .authorized:
            // Legacy authorization state retained by EventKit.
            return

        case .notDetermined:
            let store =
                eventStore

            let granted:
                Bool =
                try await
                    withCheckedThrowingContinuation {
                        (
                            continuation:
                                CheckedContinuation<
                                    Bool,
                                    Error
                                >
                        ) in

                        store
                            .requestFullAccessToEvents {
                                granted,
                                error in

                                if let error {
                                    continuation
                                        .resume(
                                            throwing:
                                                error
                                        )
                                } else {
                                    continuation
                                        .resume(
                                            returning:
                                                granted
                                        )
                                }
                            }
                    }

            guard granted else {
                throw
                    AppleCalendarEventKitError
                        .accessDenied
            }

        case .denied,
             .restricted,
             .writeOnly:
            throw
                AppleCalendarEventKitError
                    .accessDenied

        @unknown default:
            throw
                AppleCalendarEventKitError
                    .accessDenied
        }
    }


    func availableCalendars()
        async throws
        -> [AppleCalendarCandidate]
    {
        try await
            requestFullAccessIfNeeded()

        return
            eventStore
                .calendars(
                    for:
                        .event
                )
                .map {
                    calendar in

                    AppleCalendarCandidate(
                        identifier:
                            calendar
                                .calendarIdentifier,
                        title:
                            calendar.title,
                        sourceTitle:
                            calendar
                                .source?
                                .title
                            ?? ""
                    )
                }
                .sorted {
                    lhs,
                    rhs in

                    lhs.displayName
                        .localizedCaseInsensitiveCompare(
                            rhs.displayName
                        )
                        == .orderedAscending
                }
    }


    func fetchEvents(
        calendarIdentifier:
            String
    ) async throws
        -> AppleCalendarFetchResult
    {
        try await
            requestFullAccessIfNeeded()

        guard
            let calendar =
                eventStore
                    .calendar(
                        withIdentifier:
                            calendarIdentifier
                    )
        else {
            throw
                AppleCalendarEventKitError
                    .calendarNotFound
        }

        let descriptor =
            AppleCalendarCandidate(
                identifier:
                    calendar
                        .calendarIdentifier,
                title:
                    calendar.title,
                sourceTitle:
                    calendar
                        .source?
                        .title
                    ?? ""
            )

        let now =
            Date()

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

        let predicate =
            eventStore
                .predicateForEvents(
                    withStart:
                        windowStart,
                    end:
                        windowEnd,
                    calendars:
                        [
                            calendar
                        ]
                )

        let events =
            eventStore
                .events(
                    matching:
                        predicate
                )

        let snapshots =
            events.map {
                event in

                AppleCalendarEventSnapshot(
                    eventIdentifier:
                        event
                            .eventIdentifier,
                    calendarItemIdentifier:
                        event
                            .calendarItemIdentifier,
                    calendarItemExternalIdentifier:
                        event
                            .calendarItemExternalIdentifier,
                    title:
                        event.title
                        ?? "(Untitled event)",
                    notes:
                        event.notes
                        ?? "",
                    location:
                        event.location,
                    startAt:
                        event.startDate,
                    endAt:
                        event.endDate,
                    isAllDay:
                        event.isAllDay,
                    timeZoneID:
                        event
                            .timeZone?
                            .identifier,
                    status:
                        Self
                            .testudoStatus(
                                event.status
                            ),
                    recurrenceRules:
                        (
                            event
                                .recurrenceRules
                            ?? []
                        )
                        .map {
                            String(
                                describing:
                                    $0
                            )
                        },
                    occurrenceDate:
                        event
                            .occurrenceDate,
                    externalURL:
                        event
                            .url?
                            .absoluteString,
                    organizerName:
                        event
                            .organizer?
                            .name,
                    organizerEmail:
                        Self
                            .emailAddress(
                                event
                                    .organizer
                            ),
                    attendeeEmails:
                        (
                            event.attendees
                            ?? []
                        )
                        .compactMap { Self.emailAddress($0) },
                    createdAt:
                        event
                            .creationDate,
                    updatedAt:
                        event
                            .lastModifiedDate
                )
            }

        return
            AppleCalendarFetchResult(
                calendar:
                    descriptor,
                windowStart:
                    windowStart,
                windowEnd:
                    windowEnd,
                events:
                    snapshots
            )
    }


    private static func testudoStatus(
        _ status:
            EKEventStatus
    ) -> CalendarEventStatus
    {
        switch status {
        case .tentative:
            return .tentative

        case .canceled:
            return .cancelled

        default:
            return .confirmed
        }
    }


    private static func emailAddress(
        _ participant:
            EKParticipant?
    ) -> String?
    {
        guard
            let participant
        else {
            return nil
        }

        let url =
            participant.url

        let absolute =
            url.absoluteString

        guard
            absolute
                .lowercased()
                .hasPrefix(
                    "mailto:"
                )
        else {
            return nil
        }

        let raw =
            String(
                absolute
                    .dropFirst(
                        "mailto:".count
                    )
            )

        return
            raw
                .removingPercentEncoding
            ?? raw
    }
}
