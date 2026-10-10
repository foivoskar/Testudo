import Foundation

public enum EnvironmentSnapshotWritePreflightError:
    Error, Equatable, Sendable
{
    case invalidDatabaseLocation
    case incompatible(EnvironmentCompatibilityStatus)
}

public enum EnvironmentSnapshotWritePreflight {

    public static func verify(
        databaseURL: URL,
        expectedEnvironmentID: UUID
    ) throws {

        guard databaseURL.lastPathComponent ==
            "EnvironmentData.json"
        else {
            throw EnvironmentSnapshotWritePreflightError
                .invalidDatabaseLocation
        }

        let environmentURL =
            databaseURL.deletingLastPathComponent()

        let status =
            try EnvironmentCompatibilityFileGuard.inspect(
                at: environmentURL,
                expectedEnvironmentID: expectedEnvironmentID
            )

        guard EnvironmentCompatibilityGate
            .permitsLegacySnapshotWrite(status)
        else {
            throw EnvironmentSnapshotWritePreflightError
                .incompatible(status)
        }
    }
}
