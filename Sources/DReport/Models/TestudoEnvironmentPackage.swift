import Foundation
import UniformTypeIdentifiers

// ============================================================
// MARK: - Testudo Work Environment package
//
// A Work Environment is exposed to the user as one package:
//
//     Research.testudoenv
//
// Finder treats it as one document, while internally it remains
// a directory that can contain Environment-owned files.
// ============================================================

enum TestudoEnvironmentPackage {

    static let filenameExtension =
        "testudoenv"

    static let typeIdentifier =
        "com.testudo.environment"

    // Optional Environment-owned appearance asset.
    //
    // Absence of this file means: use Testudo's bundled default
    // blue Environment icon.
    static let customIconFileName =
        "EnvironmentIcon.png"

    static let contentType:
        UTType =
        UTType(
            exportedAs:
                typeIdentifier,
            conformingTo:
                .package
        )


    static func normalizedURL(
        _ url:
            URL
    ) -> URL {

        if
            url.pathExtension
                .caseInsensitiveCompare(
                    filenameExtension
                )
                == .orderedSame
        {
            return url
        }

        return
            url.appendingPathExtension(
                filenameExtension
            )
    }


    static func suggestedFileName(
        for environmentName:
            String
    ) -> String {

        let cleaned =
            environmentName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .replacingOccurrences(
                    of:
                        "/",
                    with:
                        "-"
                )
                .replacingOccurrences(
                    of:
                        ":",
                    with:
                        "-"
                )

        let base =
            cleaned.isEmpty
            ? "Work Environment"
            : cleaned

        return
            "\(base).\(filenameExtension)"
    }
}
