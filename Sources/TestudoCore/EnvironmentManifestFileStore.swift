import Foundation

public enum EnvironmentManifestFileStore {

    @discardableResult
    public static func updateExistingLegacyManifest(
        at url: URL,
        expectedEnvironmentID: UUID,
        identityProviderData: Data,
        updatedAt: Date
    ) throws -> Bool {

        let original = try Data(contentsOf: url)

        guard let updated =
            try EnvironmentManifestUpdater.updateLegacyManifest(
                original,
                expectedEnvironmentID: expectedEnvironmentID,
                identityProviderData: identityProviderData,
                updatedAt: updatedAt
            )
        else {
            return false
        }

        try updated.write(
            to: url,
            options: .atomic
        )

        return true
    }
}
