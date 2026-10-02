import Foundation


// ============================================================
// MARK: - Application Data
//
// Data belonging to this installation of the application.
//
// This is deliberately separate from Work Environment data.
//
// ApplicationData contains:
//   • the local owner/user profile
//   • references to known Work Environments
//   • which Environment is currently active
//   • later: application Settings
//
// It must NOT contain:
//   • Themes
//   • Work items
//   • People / Groups / Organizations
//   • Calendar data
//   • Environment members / roles
//   • Environment history
//
// Those belong to an Environment database.
// ============================================================

struct ApplicationData:
    Codable
{
    var schemaVersion:
        Int = 2

    var localUserProfile:
        LocalUserProfile?

    var workEnvironments:
        [WorkEnvironment] = []

    // Local mapping between this app installation and each
    // Environment's own membership identity.
    var environmentAccesses:
        [EnvironmentAccess] = []

    var activeEnvironmentID:
        UUID?


    init() {}


    enum CodingKeys:
        String,
        CodingKey
    {
        case schemaVersion
        case localUserProfile
        case workEnvironments
        case environmentAccesses
        case activeEnvironmentID
    }


    init(
        from decoder:
            Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        schemaVersion =
            try container.decodeIfPresent(
                Int.self,
                forKey:
                    .schemaVersion
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

        environmentAccesses =
            try container.decodeIfPresent(
                [EnvironmentAccess].self,
                forKey:
                    .environmentAccesses
            ) ?? []

        activeEnvironmentID =
            try container.decodeIfPresent(
                UUID.self,
                forKey:
                    .activeEnvironmentID
            )
    }
}
