import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case administrator
    case member

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .administrator:
            return "Administrator"
        case .member:
            return "Member"
        }
    }
}

struct DReportUser: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    // Every DReport user corresponds to one Person entity.
    // Optional only for migration of databases created before
    // User ↔ Person linking was introduced.
    var personEntityID: UUID?

    var username: String

    var firstName: String
    var lastName: String

    var role: UserRole

    var passwordSaltBase64: String
    var passwordHashBase64: String
    var passwordIterations: Int

    var avatarData: Data?

    var isActive: Bool = true

    var createdAt: Date = Date()
    var lastLoginAt: Date?

    var displayName: String {
        let combined =
            "\(firstName) \(lastName)"
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        return combined.isEmpty
            ? username
            : combined
    }

    var initials: String {
        let cleaned =
            firstName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if let first =
            cleaned.first
        {
            return String(first).uppercased()
        }

        if let first =
            username.first
        {
            return String(first).uppercased()
        }

        return "?"
    }
}
