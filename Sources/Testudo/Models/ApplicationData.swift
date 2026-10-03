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

// ============================================================
// MARK: - Local application authentication
//
// This credential protects the local Testudo installation only.
// It is completely independent from Work Environment accounts.
// ============================================================

struct ApplicationCredential:
    Codable,
    Hashable
{
    var passwordSaltBase64:
        String

    var passwordHashBase64:
        String

    var passwordIterations:
        Int

    var createdAt:
        Date

    var updatedAt:
        Date


    // Three user-defined recovery questions.
    //
    // Answers are salted hashes only.
    // nil means this older/local account has not configured
    // password recovery yet.
    var recoveryQuestions:
        [SecurityQuestionCredential]? = nil
}


struct ApplicationData:
    Codable
{
    var schemaVersion:
        Int = 5

    var localUserProfile:
        LocalUserProfile?

    // Password hash for the local Testudo user.
    //
    // This never travels with a Work Environment.
    var applicationCredential:
        ApplicationCredential?

    // Persisted login state.
    //
    // false means the user remains signed in across ordinary
    // application restarts.
    //
    // true means the user explicitly selected Log Out and must
    // enter the application password before continuing.
    var applicationIsLoggedOut:
        Bool = false

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
        case applicationCredential
        case applicationIsLoggedOut
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

        applicationCredential =
            try container.decodeIfPresent(
                ApplicationCredential.self,
                forKey:
                    .applicationCredential
            )

        applicationIsLoggedOut =
            try container.decodeIfPresent(
                Bool.self,
                forKey:
                    .applicationIsLoggedOut
            ) ?? false


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
