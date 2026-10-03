import Foundation
import UniformTypeIdentifiers


// ============================================================
// MARK: - Portable Testudo User Profile
//
// A .testudouser file contains ONLY the application user's
// personal LocalUserProfile.
//
// It deliberately does NOT contain:
//
// • application password
// • Work Environment registrations
// • Environment bookmarks / paths
// • Environment memberships
// • Environment passwords
// • Stay signed in state
//
// After import, the user creates a new local application
// password and explicitly reopens the .testudoenv packages
// they want to use.
// ============================================================

struct TestudoUserProfileDocument:
    Codable
{
    var schemaVersion:
        Int

    var exportedAt:
        Date

    var profile:
        LocalUserProfile


    init(
        schemaVersion:
            Int = 1,
        exportedAt:
            Date = Date(),
        profile:
            LocalUserProfile
    ) {
        self.schemaVersion =
            schemaVersion

        self.exportedAt =
            exportedAt

        self.profile =
            profile
    }
}


enum TestudoUserProfileFile {

    static let filenameExtension =
        "testudouser"

    static let typeIdentifier =
        "com.testudo.user-profile"


    static let contentType =
        UTType(
            exportedAs:
                typeIdentifier,
            conformingTo:
                .data
        )


    static func normalizedURL(
        _ url:
            URL
    ) -> URL {

        if
            url
                .pathExtension
                .caseInsensitiveCompare(
                    filenameExtension
                )
                == .orderedSame
        {
            return url
        }

        return
            url
                .appendingPathExtension(
                    filenameExtension
                )
    }


    static func suggestedFileName(
        for profile:
            LocalUserProfile
    ) -> String {

        let rawName =
            profile
                .displayName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        let baseName =
            rawName.isEmpty
            ? "Testudo User"
            : rawName


        let forbidden =
            CharacterSet(
                charactersIn:
                    "/:\\"
            )


        let cleaned =
            baseName
                .components(
                    separatedBy:
                        forbidden
                )
                .joined(
                    separator:
                        "-"
                )


        return
            "\(cleaned).\(filenameExtension)"
    }
}
