import Foundation

struct PersonProfile:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var entityID: UUID

    var firstName: String = ""
    var middleName: String = ""
    var lastName: String = ""
    var preferredName: String = ""

    var jobTitle: String = ""

    var professionalEmail: String = ""
    var secondaryProfessionalEmail: String = ""

    var professionalPhone: String = ""

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

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var displayName: String {
        let preferred =
            preferredName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if !preferred.isEmpty {
            return preferred
        }

        let full =
            [
                firstName,
                middleName,
                lastName
            ]
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
            .joined(separator: " ")

        return full
    }
}
