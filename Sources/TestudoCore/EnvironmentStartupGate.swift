import Foundation

public enum EnvironmentStartupDisposition:
    Equatable, Sendable
{
    case newLocalInstallation
    case readableLegacyRoot
    case readableLegacyEnvironment
    case blocked(EnvironmentCompatibilityStatus)
}

public enum EnvironmentStartupGateError:
    Error, Equatable, Sendable
{
    case invalidDatabaseLocation
}

public enum EnvironmentStartupGate {

    public static func inspect(
        databaseURL: URL,
        expectedEnvironmentID: UUID? = nil
    ) throws -> EnvironmentStartupDisposition {

        switch databaseURL.lastPathComponent {

        case "TestudoData.json":

            guard FileManager.default.fileExists(
                atPath: databaseURL.path
            ) else {
                return .newLocalInstallation
            }

            let raw = try Data(
                contentsOf: databaseURL
            )

            guard
                let object =
                    try JSONSerialization.jsonObject(
                        with: raw
                    ) as? [String: Any],
                let schema = object["schemaVersion"] as? Int,
                (1...9).contains(schema)
            else {
                return .blocked(.unsupported)
            }

            return .readableLegacyRoot

        case "EnvironmentData.json":

            guard let expectedEnvironmentID else {
                return .blocked(.unsupported)
            }

            let status =
                try EnvironmentCompatibilityFileGuard.inspect(
                    at: databaseURL.deletingLastPathComponent(),
                    expectedEnvironmentID: expectedEnvironmentID
                )

            guard status == .legacyReady else {
                return .blocked(status)
            }

            return .readableLegacyEnvironment

        default:

            throw EnvironmentStartupGateError
                .invalidDatabaseLocation
        }
    }
}
