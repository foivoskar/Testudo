import Foundation

public enum EnvironmentCompatibilityStatus:
    Equatable, Sendable
{
    case legacyReady
    case legacyDatabaseMigrationRequired
    case journalEngineUnavailable
    case unsupported
}

public enum EnvironmentCompatibilityGate {

    private struct ManifestHeader: Decodable {
        let schemaVersion: Int
        let environmentID: UUID
        let syncFormatVersion: Int?
    }

    private struct DatabaseHeader: Decodable {
        let schemaVersion: Int
    }

    public static func inspect(
        manifestData: Data,
        environmentData: Data,
        expectedEnvironmentID: UUID? = nil
    ) throws -> EnvironmentCompatibilityStatus {

        guard let manifestObject =
            try JSONSerialization.jsonObject(
                with: manifestData
            ) as? [String: Any]
        else {
            return .unsupported
        }

        let decoder = JSONDecoder()

        let manifest = try decoder.decode(
            ManifestHeader.self,
            from: manifestData
        )

        let database = try decoder.decode(
            DatabaseHeader.self,
            from: environmentData
        )

        if let expectedEnvironmentID {
            guard manifest.environmentID ==
                expectedEnvironmentID
            else {
                return .unsupported
            }
        }

        guard (1...2).contains(
            manifest.schemaVersion
        ) else {
            return .unsupported
        }

        guard (7...8).contains(
            database.schemaVersion
        ) else {
            return .unsupported
        }

        let reservedKeys = [
            "formatVersion",
            "minimumReaderVersion",
            "minimumWriterVersion",
            "syncProtocol"
        ]

        guard !reservedKeys.contains(
            where: { manifestObject.keys.contains($0) }
        ) else {
            return .unsupported
        }

        if manifestObject.keys.contains(
            "syncFormatVersion"
        ) {
            guard manifest.syncFormatVersion == 1 else {
                return .unsupported
            }

            return .journalEngineUnavailable
        }

        if database.schemaVersion == 7 {
            return .legacyDatabaseMigrationRequired
        }

        return .legacyReady
    }

    public static func permitsLegacySnapshotWrite(
        _ status: EnvironmentCompatibilityStatus
    ) -> Bool {
        status == .legacyReady
    }
}
