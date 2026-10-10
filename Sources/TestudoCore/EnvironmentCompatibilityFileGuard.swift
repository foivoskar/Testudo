import Foundation

public enum EnvironmentCompatibilityFileGuard {

    public static func inspect(
        at packageURL: URL,
        expectedEnvironmentID: UUID? = nil
    ) throws -> EnvironmentCompatibilityStatus {

        let manifestURL =
            packageURL.appendingPathComponent(
                "EnvironmentManifest.json"
            )

        let databaseURL =
            packageURL.appendingPathComponent(
                "EnvironmentData.json"
            )

        let manifestData = try Data(
            contentsOf: manifestURL
        )

        let databaseData = try Data(
            contentsOf: databaseURL
        )

        return try EnvironmentCompatibilityGate.inspect(
            manifestData: manifestData,
            environmentData: databaseData,
            expectedEnvironmentID: expectedEnvironmentID
        )
    }
}
