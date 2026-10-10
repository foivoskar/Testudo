import Foundation

public enum EnvironmentFormatAssessment: Equatable, Sendable {
    case legacyRequiresMigration
    case supportedJournal
    case unsupported
}

public enum EnvironmentFormatInspector {

    public static let supportedJournalVersion = 1

    private struct ManifestProbe: Decodable {
        let schemaVersion: Int
        let environmentID: UUID
        let syncFormatVersion: Int?
    }

    public static func assess(
        manifestData: Data
    ) throws -> EnvironmentFormatAssessment {

        let manifest = try JSONDecoder().decode(
            ManifestProbe.self,
            from: manifestData
        )

        guard (1...2).contains(manifest.schemaVersion) else {
            return .unsupported
        }

        guard let version = manifest.syncFormatVersion else {
            return .legacyRequiresMigration
        }

        guard version == supportedJournalVersion else {
            return .unsupported
        }

        return .supportedJournal
    }
}
