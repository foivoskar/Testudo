import Foundation

struct TestudoData: Codable {
    var schemaVersion: Int = 8

    // --------------------------------------------------------
    // Application-level identity
    // --------------------------------------------------------

    var localUserProfile:
        LocalUserProfile?


    // --------------------------------------------------------
    // Work Environments
    // --------------------------------------------------------

    var workEnvironments:
        [WorkEnvironment] = []

    var environmentMemberships:
        [EnvironmentMembership] = []

    // Local application state: which Environment is currently
    // open on this installation.
    var activeEnvironmentID:
        UUID?


    var themes: [Theme] = []
    var workItems: [WorkItem] = []

    var entities: [Entity] = []
    var memberships: [EntityMembership] = []

    var personProfiles: [PersonProfile] = []

    var workEntityRelationships:
        [WorkEntityRelationship] = []

    var themeEntityRelationships:
        [ThemeEntityRelationship] = []

    var historyEvents:
        [HistoryEvent] = []

    var calendarAccounts:
        [CalendarAccount] = []

    var calendars:
        [TestudoCalendar] = []

    var calendarEvents:
        [CalendarEvent] = []

    var calendarEventWorkLinks:
        [CalendarEventWorkLink] = []

    var calendarEventThemeLinks:
        [CalendarEventThemeLink] = []

    init() {}

    enum CodingKeys:
        String,
        CodingKey
    {
        case schemaVersion
        case localUserProfile
        case workEnvironments
        case environmentMemberships
        case activeEnvironmentID
        case themes
        case workItems
        case entities
        case memberships
        case personProfiles
        case workEntityRelationships
        case themeEntityRelationships
        case historyEvents
        case calendarAccounts
        case calendars
        case calendarEvents
        case calendarEventWorkLinks
        case calendarEventThemeLinks
    }

    init(
        from decoder: Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        schemaVersion =
            try container.decodeIfPresent(
                Int.self,
                forKey: .schemaVersion
            ) ?? 1

        localUserProfile =
            try container.decodeIfPresent(
                LocalUserProfile.self,
                forKey:
                    .localUserProfile
            )

        workEnvironments =
            try container.decodeIfPresent(
                [WorkEnvironment].self,
                forKey:
                    .workEnvironments
            ) ?? []

        environmentMemberships =
            try container.decodeIfPresent(
                [EnvironmentMembership].self,
                forKey:
                    .environmentMemberships
            ) ?? []

        activeEnvironmentID =
            try container.decodeIfPresent(
                UUID.self,
                forKey:
                    .activeEnvironmentID
            )

        themes =
            try container.decodeIfPresent(
                [Theme].self,
                forKey: .themes
            ) ?? []

        workItems =
            try container.decodeIfPresent(
                [WorkItem].self,
                forKey: .workItems
            ) ?? []

        entities =
            try container.decodeIfPresent(
                [Entity].self,
                forKey: .entities
            ) ?? []

        memberships =
            try container.decodeIfPresent(
                [EntityMembership].self,
                forKey: .memberships
            ) ?? []

        personProfiles =
            try container.decodeIfPresent(
                [PersonProfile].self,
                forKey: .personProfiles
            ) ?? []

        workEntityRelationships =
            try container.decodeIfPresent(
                [WorkEntityRelationship].self,
                forKey:
                    .workEntityRelationships
            ) ?? []

        themeEntityRelationships =
            try container.decodeIfPresent(
                [ThemeEntityRelationship].self,
                forKey:
                    .themeEntityRelationships
            ) ?? []

        historyEvents =
            try container.decodeIfPresent(
                [HistoryEvent].self,
                forKey: .historyEvents
            ) ?? []

        calendarAccounts =
            try container.decodeIfPresent(
                [CalendarAccount].self,
                forKey:
                    .calendarAccounts
            ) ?? []

        calendars =
            try container.decodeIfPresent(
                [TestudoCalendar].self,
                forKey:
                    .calendars
            ) ?? []

        calendarEvents =
            try container.decodeIfPresent(
                [CalendarEvent].self,
                forKey:
                    .calendarEvents
            ) ?? []

        calendarEventWorkLinks =
            try container.decodeIfPresent(
                [CalendarEventWorkLink].self,
                forKey:
                    .calendarEventWorkLinks
            ) ?? []

        calendarEventThemeLinks =
            try container.decodeIfPresent(
                [CalendarEventThemeLink].self,
                forKey:
                    .calendarEventThemeLinks
            ) ?? []
    }
}
