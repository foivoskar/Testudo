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
    var id: UUID = UUID()

    var name: String

    // Every Work Environment owns its own directory source.
    //
    // nil means that the Environment has not yet been connected
    // to an external directory. We deliberately do not invent
    // a path during legacy migration.
    var directory:
        EnvironmentDirectoryConfiguration?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()


    init(
        id: UUID = UUID(),
        name: String,
        directory:
            EnvironmentDirectoryConfiguration? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.directory = directory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

    var lastOpenedAt: Date?


    var id: UUID {
        environmentID
    }
}


// ============================================================
// MARK: - Portable Environment Manifest
//
// Stored inside the Environment directory as:
//
//     EnvironmentManifest.json
//
// This file makes an external Environment directory
// self-identifying before its database is opened.
// ============================================================

struct EnvironmentManifest:
    Codable,
    Hashable
{
    var schemaVersion: Int = 1

    var environmentID: UUID
    var name: String

    var createdAt: Date
    var updatedAt: Date
}


// ============================================================
// MARK: - Environment Directory
//
// This describes the database/source directory belonging to
// exactly one Work Environment.
//
// The security-scoped bookmark will later allow the macOS app
// to retain permission to a user-selected external directory.
// ============================================================

enum EnvironmentDirectoryKind:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case localFolder

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .localFolder:
            return "Local Folder"
        }
    }
}


struct EnvironmentDirectoryConfiguration:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var kind:
        EnvironmentDirectoryKind =
            .localFolder

    var displayName: String = ""

    // Human-readable path. This is not sufficient by itself
    // for sandbox permission; bookmarkData is the persistent
    // macOS permission token.
    var path: String?

    var bookmarkData: Data?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastConnectedAt: Date?
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

    // Identity supplied by the Environment directory.
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
