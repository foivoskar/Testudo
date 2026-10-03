import Foundation


// ============================================================
// MARK: - Frequently used preferences
//
// Rankings are derived from data currently available to Testudo:
//
//   • current Work Environment
//   • local application profile
//
// We deliberately do not open unrelated .testudoenv packages in
// the background merely to calculate preference rankings.
// ============================================================

extension TestudoStore {

    func mostUsedTimeZoneIdentifiers(
        limit: Int = 5
    ) -> [String] {
        guard limit > 0 else {
            return []
        }

        var counts:
            [String: Int] = [:]


        func add(
            _ identifier:
                String?
        ) {
            guard
                let identifier =
                    TestudoTime
                        .validTimeZoneIdentifier(
                            identifier
                        )
            else {
                return
            }

            counts[
                identifier,
                default: 0
            ] += 1
        }


        // ----------------------------------------------------
        // Local application profile
        // ----------------------------------------------------

        add(
            localUserProfile?
                .timeZone
        )


        // Legacy/local profile copy, only when it is not the
        // same profile already counted above.

        if
            let legacyProfile =
                data.localUserProfile,
            legacyProfile.id
                != localUserProfile?.id
        {
            add(
                legacyProfile
                    .timeZone
            )
        }


        // ----------------------------------------------------
        // People
        // ----------------------------------------------------

        for profile in
            data.personProfiles
        {
            add(
                profile.timeZone
            )
        }


        // ----------------------------------------------------
        // Work timestamps
        // ----------------------------------------------------

        for item in
            data.workItems
        {
            add(item.createdTimeZoneID)
            add(item.updatedTimeZoneID)

            add(item.scheduledTimeZoneID)
            add(item.deadlineTimeZoneID)
            add(item.reminderTimeZoneID)

            add(item.startedTimeZoneID)
            add(item.completedTimeZoneID)
            add(item.loggedTimeZoneID)
        }


        // ----------------------------------------------------
        // History
        // ----------------------------------------------------

        for event in
            data.historyEvents
        {
            add(event.timeZoneID)
            add(event.valueTimeZoneID)
        }


        // ----------------------------------------------------
        // Calendars
        // ----------------------------------------------------

        for calendar in
            data.calendars
        {
            add(calendar.timeZoneID)
        }


        for event in
            data.calendarEvents
        {
            add(event.startTimeZoneID)
            add(event.endTimeZoneID)
        }


        return counts
            .sorted {
                lhs,
                rhs in

                if lhs.value != rhs.value {
                    return lhs.value
                        > rhs.value
                }

                return
                    TestudoTime
                        .shortTimeZoneLabel(
                            identifier:
                                lhs.key
                        )
                        .localizedCaseInsensitiveCompare(
                            TestudoTime
                                .shortTimeZoneLabel(
                                    identifier:
                                        rhs.key
                                )
                        )
                    == .orderedAscending
            }
            .prefix(limit)
            .map(\.key)
    }


    func mostUsedLanguages(
        limit: Int = 5
    ) -> [String] {
        guard limit > 0 else {
            return []
        }

        var counts:
            [
                String:
                    (
                        display:
                            String,
                        count:
                            Int
                    )
            ] = [:]


        func add(
            _ language:
                String?
        ) {
            guard
                let language
            else {
                return
            }

            let trimmed =
                language
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard !trimmed.isEmpty else {
                return
            }

            let key =
                trimmed
                    .folding(
                        options: [
                            .caseInsensitive,
                            .diacriticInsensitive
                        ],
                        locale:
                            Locale(identifier: "en")
                    )
                    .lowercased()

            if var existing =
                counts[key]
            {
                existing.count += 1
                counts[key] =
                    existing

            } else {
                counts[key] =
                    (
                        display:
                            trimmed,
                        count:
                            1
                    )
            }
        }


        add(
            localUserProfile?
                .preferredLanguage
        )


        if
            let legacyProfile =
                data.localUserProfile,
            legacyProfile.id
                != localUserProfile?.id
        {
            add(
                legacyProfile
                    .preferredLanguage
            )
        }


        for profile in
            data.personProfiles
        {
            add(
                profile
                    .preferredLanguage
            )
        }


        return counts
            .values
            .sorted {
                lhs,
                rhs in

                if lhs.count
                    != rhs.count
                {
                    return lhs.count
                        > rhs.count
                }

                return
                    lhs.display
                        .localizedCaseInsensitiveCompare(
                            rhs.display
                        )
                    == .orderedAscending
            }
            .prefix(limit)
            .map(\.display)
    }
}
