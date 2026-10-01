import Foundation

struct DReportData: Codable {
    var schemaVersion: Int = 3

    var themes: [Theme] = []
    var workItems: [WorkItem] = []

    var entities: [Entity] = []
    var memberships: [EntityMembership] = []

    var personProfiles: [PersonProfile] = []

    var workEntityRelationships:
        [WorkEntityRelationship] = []

    var historyEvents:
        [HistoryEvent] = []

    var users:
        [DReportUser] = []

    init() {}

    enum CodingKeys:
        String,
        CodingKey
    {
        case schemaVersion
        case themes
        case workItems
        case entities
        case memberships
        case personProfiles
        case workEntityRelationships
        case historyEvents
        case users
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

        historyEvents =
            try container.decodeIfPresent(
                [HistoryEvent].self,
                forKey: .historyEvents
            ) ?? []

        users =
            try container.decodeIfPresent(
                [DReportUser].self,
                forKey: .users
            ) ?? []
    }
}
