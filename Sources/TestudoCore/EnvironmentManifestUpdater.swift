import Foundation

public enum EnvironmentManifestUpdateError:
    Error, Equatable, Sendable
{
    case unsupportedFormat
    case invalidManifest
    case environmentMismatch
    case invalidIdentityProvider
}

public enum EnvironmentManifestUpdater {

    public static func updateLegacyManifest(
        _ originalData: Data,
        expectedEnvironmentID: UUID,
        identityProviderData: Data,
        updatedAt: Date
    ) throws -> Data? {

        let assessment =
            try EnvironmentFormatInspector.assess(
                manifestData: originalData
            )

        guard assessment == .legacyRequiresMigration else {
            throw EnvironmentManifestUpdateError
                .unsupportedFormat
        }

        guard var object =
            try JSONSerialization.jsonObject(
                with: originalData
            ) as? [String: Any]
        else {
            throw EnvironmentManifestUpdateError
                .invalidManifest
        }

        let reservedKeys = [
            "formatVersion",
            "minimumReaderVersion",
            "minimumWriterVersion",
            "syncProtocol"
        ]

        guard !reservedKeys.contains(
            where: { object[$0] != nil }
        ) else {
            throw EnvironmentManifestUpdateError
                .unsupportedFormat
        }

        guard
            let storedID = object["environmentID"] as? String,
            let manifestID = UUID(uuidString: storedID),
            manifestID == expectedEnvironmentID
        else {
            throw EnvironmentManifestUpdateError
                .environmentMismatch
        }

        guard
            let schemaVersion = object["schemaVersion"] as? Int,
            (1...2).contains(schemaVersion)
        else {
            throw EnvironmentManifestUpdateError
                .unsupportedFormat
        }

        guard let identityProvider =
            try JSONSerialization.jsonObject(
                with: identityProviderData
            ) as? [String: Any]
        else {
            throw EnvironmentManifestUpdateError
                .invalidIdentityProvider
        }

        var changed = false

        if schemaVersion == 1 {
            object["schemaVersion"] = 2
            changed = true
        }

        let existingProvider = object["identityProvider"]

        if existingProvider == nil ||
            existingProvider is NSNull
        {
            object["identityProvider"] = identityProvider
            changed = true
        }

        guard changed else {
            return nil
        }

        object["updatedAt"] =
            ISO8601DateFormatter().string(
                from: updatedAt
            )

        return try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
    }
}
