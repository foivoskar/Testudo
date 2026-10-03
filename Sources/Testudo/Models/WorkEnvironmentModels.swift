import Foundation


// ============================================================
// MARK: - Local Application User
//
// This is the owner/user of this installation of the app.
//
// It is NOT:
//   • an application login account
//   • an Environment Administrator
//   • automatically a Person entity
//
// Its information can later be copied into a Person entity
// inside any Work Environment.
// ============================================================

struct LocalUserProfile:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var firstName: String = ""
    var middleName: String = ""
    var lastName: String = ""
    var preferredName: String = ""

    var jobTitle: String = ""

    var professionalEmail: String = ""
    var secondaryProfessionalEmail: String = ""

    var professionalPhone: String = ""
    var secondaryPhone: String?

    var office: String = ""
    var employeeID: String = ""

    var website: String = ""
    var orcid: String = ""
    var linkedIn: String = ""
    var github: String = ""

    var professionalFields: String = ""
    var responsibilities: String = ""

    var notes: String = ""

    var avatarData: Data?

    var academicTitle: String?

    var professionalAddress: String?
    var city: String?
    var postalCode: String?
    var country: String?

    var researcherID: String?
    var scopusAuthorID: String?
    var googleScholarURL: String?

    var preferredLanguage: String?
    var timeZone: String?

    var assistantContact: String?
    var tags: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()


    var displayName: String {
        let preferred =
            preferredName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !preferred.isEmpty {
            return preferred
        }

        let fullName =
            [
                firstName,
                middleName,
                lastName
            ]
            .map {
                $0.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
            .joined(separator: " ")

        return fullName
    }
}


// ============================================================
// MARK: - Work Environment
// ============================================================

struct WorkEnvironment:
    Identifiable,
    Codable,
    Hashable
{
    var id:
        UUID = UUID()

    var name:
        String

    // --------------------------------------------------------
    // Application-local physical storage.
    //
    // This describes where this installation can find the
    // Environment files. It is NOT an identity directory.
    // --------------------------------------------------------

    var storage:
        EnvironmentStorageConfiguration?

    // --------------------------------------------------------
    // Environment identity / authentication provider.
    //
    // This is conceptually independent from physical storage.
    // --------------------------------------------------------

    var identityProvider:
        EnvironmentIdentityProviderConfiguration

    var createdAt:
        Date = Date()

    var updatedAt:
        Date = Date()


    init(
        id:
            UUID = UUID(),
        name:
            String,
        storage:
            EnvironmentStorageConfiguration? = nil,
        identityProvider:
            EnvironmentIdentityProviderConfiguration =
                EnvironmentIdentityProviderConfiguration(),
        createdAt:
            Date = Date(),
        updatedAt:
            Date = Date()
    ) {
        self.id =
            id

        self.name =
            name

        self.storage =
            storage

        self.identityProvider =
            identityProvider

        self.createdAt =
            createdAt

        self.updatedAt =
            updatedAt
    }


    // --------------------------------------------------------
    // Backward-compatible decoding
    //
    // ApplicationData schema <= 2 stored physical storage under
    // the misleading key "directory".
    //
    // Decode that old key into "storage", but never encode it
    // again.
    // --------------------------------------------------------

    enum CodingKeys:
        String,
        CodingKey
    {
        case id
        case name
        case storage
        case identityProvider
        case createdAt
        case updatedAt

        // Legacy ApplicationData key.
        case directory
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

        id =
            try container.decodeIfPresent(
                UUID.self,
                forKey:
                    .id
            )
            ?? UUID()

        name =
            try container.decode(
                String.self,
                forKey:
                    .name
            )

        let currentStorage =
            try container.decodeIfPresent(
                EnvironmentStorageConfiguration.self,
                forKey:
                    .storage
            )

        let legacyStorage =
            try container.decodeIfPresent(
                EnvironmentStorageConfiguration.self,
                forKey:
                    .directory
            )

        storage =
            currentStorage
            ?? legacyStorage

        identityProvider =
            try container.decodeIfPresent(
                EnvironmentIdentityProviderConfiguration.self,
                forKey:
                    .identityProvider
            )
            ?? EnvironmentIdentityProviderConfiguration()

        createdAt =
            try container.decodeIfPresent(
                Date.self,
                forKey:
                    .createdAt
            )
            ?? Date()

        updatedAt =
            try container.decodeIfPresent(
                Date.self,
                forKey:
                    .updatedAt
            )
            ?? createdAt
    }


    func encode(
        to encoder:
            Encoder
    ) throws {
        var container =
            encoder.container(
                keyedBy:
                    CodingKeys.self
            )

        try container.encode(
            id,
            forKey:
                .id
        )

        try container.encode(
            name,
            forKey:
                .name
        )

        try container.encodeIfPresent(
            storage,
            forKey:
                .storage
        )

        try container.encode(
            identityProvider,
            forKey:
                .identityProvider
        )

        try container.encode(
            createdAt,
            forKey:
                .createdAt
        )

        try container.encode(
            updatedAt,
            forKey:
                .updatedAt
        )
    }
}


// ============================================================

// MARK: - Local Environment Access
//
// This belongs to ApplicationData, NOT EnvironmentData.
//
// It connects this installation's LocalUserProfile to the
// Environment-local membership that represents the same person.
//
// Another computer/user can therefore open the same Environment
// directory and establish a different local mapping.
// ============================================================

struct EnvironmentAccess:
    Identifiable,
    Codable,
    Hashable
{
    var environmentID: UUID

    var membershipID: UUID?

    // Application-local remembered authentication.
    //
    // This never belongs to the portable Environment and never
    // stores the user's password.
    //
    // Optional so existing ApplicationData files decode without
    // requiring a schema migration.
    var staySignedIn: Bool? = nil

    var lastOpenedAt: Date?


    var id: UUID {
        environmentID
    }
}


// ============================================================
// MARK: - Portable Environment Manifest
//
// Stored inside the .testudoenv package as:
//
//     EnvironmentManifest.json
//
// This file makes a portable Environment package self-identifying
// before its database is opened.
// ============================================================

struct EnvironmentManifest:
    Codable,
    Hashable
{
    var schemaVersion: Int = 1

    var environmentID: UUID
    var name: String

    // Identity/authentication belongs to the Environment itself
    // and therefore travels with its portable manifest.
    //
    // nil is accepted only for manifests written before schema 2.
    var identityProvider:
        EnvironmentIdentityProviderConfiguration? = nil

    var createdAt: Date
    var updatedAt: Date
}


// ============================================================
// MARK: - Environment Storage
//
// Physical Environment package location known to this app
// installation.
//
// The canonical representation is a user-selected .testudoenv
// package. Legacy localFolder values remain readable only so old
// installations can be relocated explicitly.
//
// This is deliberately separate from the Environment's identity
// and authentication provider.
// ============================================================

enum EnvironmentStorageKind:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case testudoPackage

    // Legacy storage kind retained so existing ApplicationData
    // registries can still be decoded and explicitly relocated.
    case localFolder


    var id:
        String
    {
        rawValue
    }


    var displayName:
        String
    {
        switch self {
        case .testudoPackage:
            return "Testudo Work Environment Package"

        case .localFolder:
            return "Legacy Local Folder"
        }
    }
}


struct EnvironmentStorageConfiguration:
    Identifiable,
    Codable,
    Hashable
{
    var id:
        UUID = UUID()

    var kind:
        EnvironmentStorageKind =
            .testudoPackage

    var displayName:
        String = ""

    // Human-readable last-known filesystem path to the
    // .testudoenv package.
    //
    // bookmarkData preserves persistent macOS access to a
    // user-selected package, including cloud-backed locations.
    var path:
        String?

    var bookmarkData:
        Data?

    var createdAt:
        Date = Date()

    var updatedAt:
        Date = Date()

    var lastConnectedAt:
        Date?
}


// ============================================================
// MARK: - Environment Identity Provider
//
// Defines how identities are authenticated for one Environment.
//
// It has no relationship to where EnvironmentData.json is stored.
// ============================================================

enum EnvironmentIdentityProviderKind:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case localAccounts

    // Reserved architecture for the future.
    case externalDirectory


    var id:
        String
    {
        rawValue
    }


    var displayName:
        String
    {
        switch self {
        case .localAccounts:
            return
                "Local Environment Accounts"

        case .externalDirectory:
            return
                "External Directory"
        }
    }
}


struct EnvironmentIdentityProviderConfiguration:
    Codable,
    Hashable
{
    var kind:
        EnvironmentIdentityProviderKind

    var displayName:
        String

    var createdAt:
        Date

    var updatedAt:
        Date


    init(
        kind:
            EnvironmentIdentityProviderKind =
                .localAccounts,
        displayName:
            String? = nil,
        createdAt:
            Date = Date(),
        updatedAt:
            Date = Date()
    ) {
        self.kind =
            kind

        self.displayName =
            displayName
            ?? kind.displayName

        self.createdAt =
            createdAt

        self.updatedAt =
            updatedAt
    }
}


// ============================================================

// MARK: - Environment Membership
//
// Roles belong to a Work Environment, never to the app.
//
// The same LocalUserProfile can therefore be:
//
//   Environment A -> Administrator
//   Environment B -> User
//
// Other Environment members do not need a LocalUserProfile.
// ============================================================

enum EnvironmentRole:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case administrator
    case user

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .administrator:
            return "Administrator"

        case .user:
            return "User"
        }
    }
}


struct EnvironmentMembership:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var environmentID: UUID

    // Legacy migration field.
    //
    // IMPORTANT:
    // A Work Environment must never permanently reference the
    // LocalUserProfile UUID of one particular app installation.
    //
    // Phase 2C migrates this link into ApplicationData and then
    // clears this field from EnvironmentData.
    //
    // Keep it optional for backward-compatible decoding only.
    var localUserProfileID: UUID?

    // Optional link to the Environment's People database.
    var personEntityID: UUID?

    // Identifier supplied by the Environment identity provider.
    var directoryUserIdentifier: String?

    // Snapshot / display information for Environment management.
    var firstName: String = ""
    var lastName: String = ""

    var role:
        EnvironmentRole =
            .user

    var isActive: Bool = true

    var createdAt: Date = Date()
    var lastAccessAt: Date?


    var displayName: String {
        let full =
            [
                firstName,
                lastName
            ]
            .map {
                $0.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
            .joined(separator: " ")

        if !full.isEmpty {
            return full
        }

        return
            directoryUserIdentifier
            ?? "User"
    }
}



// ============================================================
// MARK: - Environment Entry Result
// ============================================================

enum EnvironmentOpenOutcome {
    case opened
    case identityRequired
    case failed(String)
}



// ============================================================
// MARK: - Environment-local authentication credentials
//
// Credentials belong to the Work Environment, never to the
// application installation and never to LocalUserProfile.
//
// For a Local Folder Environment these are stored beside the
// Environment database in EnvironmentCredentials.json.
//
// Future directory providers may authenticate externally and
// therefore may not use a local EnvironmentCredential.
// ============================================================

struct EnvironmentCredential:
    Identifiable,
    Codable,
    Hashable
{
    var membershipID:
        UUID

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


    var id:
        UUID
    {
        membershipID
    }
}


struct EnvironmentCredentialStore:
    Codable,
    Hashable
{
    var schemaVersion:
        Int

    var environmentID:
        UUID

    var credentials:
        [EnvironmentCredential]


    init(
        schemaVersion:
            Int = 1,
        environmentID:
            UUID,
        credentials:
            [EnvironmentCredential] = []
    ) {
        self.schemaVersion =
            schemaVersion

        self.environmentID =
            environmentID

        self.credentials =
            credentials
    }
}
