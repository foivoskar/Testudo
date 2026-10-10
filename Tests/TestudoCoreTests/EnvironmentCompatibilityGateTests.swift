import Foundation
import XCTest
@testable import TestudoCore

final class EnvironmentCompatibilityGateTests:
    XCTestCase
{
    private let environmentID = UUID(
        uuidString:
            "11111111-2222-3333-4444-555555555555"
    )!

    private func manifest(
        schemaVersion: Int = 2,
        syncVersion: Int? = nil,
        environmentID: UUID? = nil,
        extra: [String: Any] = [:]
    ) throws -> Data {

        var object: [String: Any] = [
            "schemaVersion": schemaVersion,
            "environmentID":
                (environmentID ?? self.environmentID).uuidString,
            "name": "Research"
        ]

        if let syncVersion {
            object["syncFormatVersion"] = syncVersion
        }

        for (key, value) in extra {
            object[key] = value
        }

        return try JSONSerialization.data(
            withJSONObject: object
        )
    }

    private func database(
        schemaVersion: Int = 8
    ) throws -> Data {

        try JSONSerialization.data(
            withJSONObject: [
                "schemaVersion": schemaVersion,
                "workItems": [],
                "entities": []
            ]
        )
    }

    private func inspect(
        manifestSchema: Int = 2,
        databaseSchema: Int = 8,
        syncVersion: Int? = nil,
        extra: [String: Any] = [:]
    ) throws -> EnvironmentCompatibilityStatus {

        try EnvironmentCompatibilityGate.inspect(
            manifestData: manifest(
                schemaVersion: manifestSchema,
                syncVersion: syncVersion,
                extra: extra
            ),
            environmentData: database(
                schemaVersion: databaseSchema
            ),
            expectedEnvironmentID: environmentID
        )
    }

    func testLegacySchemaOneIsRecognized() throws {
        XCTAssertEqual(
            try inspect(manifestSchema: 1),
            .legacyReady
        )
    }

    func testLegacySchemaTwoIsRecognized() throws {
        XCTAssertEqual(
            try inspect(manifestSchema: 2),
            .legacyReady
        )
    }

    func testLegacyDatabaseSevenRequiresMigration() throws {
        XCTAssertEqual(
            try inspect(databaseSchema: 7),
            .legacyDatabaseMigrationRequired
        )
    }

    func testFutureDatabaseSchemaIsBlocked() throws {
        XCTAssertEqual(
            try inspect(databaseSchema: 99),
            .unsupported
        )
    }

    func testOlderDatabaseSchemaIsBlocked() throws {
        XCTAssertEqual(
            try inspect(databaseSchema: 6),
            .unsupported
        )
    }

    func testFutureManifestSchemaIsBlocked() throws {
        XCTAssertEqual(
            try inspect(manifestSchema: 99),
            .unsupported
        )
    }

    func testJournalRequiresNewEngine() throws {
        XCTAssertEqual(
            try inspect(syncVersion: 1),
            .journalEngineUnavailable
        )
    }

    func testUnknownJournalVersionIsBlocked() throws {
        XCTAssertEqual(
            try inspect(syncVersion: 99),
            .unsupported
        )
    }

    func testFutureProtocolMetadataIsBlocked() throws {
        XCTAssertEqual(
            try inspect(
                extra: ["minimumWriterVersion": 3]
            ),
            .unsupported
        )
    }

    func testEnvironmentIdentityMismatchIsBlocked() throws {
        let result =
            try EnvironmentCompatibilityGate.inspect(
                manifestData: manifest(
                    environmentID: UUID()
                ),
                environmentData: database(),
                expectedEnvironmentID: environmentID
            )

        XCTAssertEqual(result, .unsupported)
    }

    func testMalformedDatabaseThrows() throws {
        XCTAssertThrowsError(
            try EnvironmentCompatibilityGate.inspect(
                manifestData: manifest(),
                environmentData: Data("invalid".utf8)
            )
        )
    }

    func testMissingDatabaseSchemaThrows() throws {
        let raw = try JSONSerialization.data(
            withJSONObject: ["workItems": []]
        )

        XCTAssertThrowsError(
            try EnvironmentCompatibilityGate.inspect(
                manifestData: manifest(),
                environmentData: raw
            )
        )
    }

    func testMalformedManifestThrows() throws {
        XCTAssertThrowsError(
            try EnvironmentCompatibilityGate.inspect(
                manifestData: Data("invalid".utf8),
                environmentData: database()
            )
        )
    }

    func testLegacyWritePermissionIsExplicit() {
        XCTAssertTrue(
            EnvironmentCompatibilityGate
                .permitsLegacySnapshotWrite(
                    .legacyReady
                )
        )

        XCTAssertFalse(
            EnvironmentCompatibilityGate
                .permitsLegacySnapshotWrite(
                    .journalEngineUnavailable
                )
        )

        XCTAssertFalse(
            EnvironmentCompatibilityGate
                .permitsLegacySnapshotWrite(
                    .unsupported
                )
        )

        XCTAssertFalse(
            EnvironmentCompatibilityGate
                .permitsLegacySnapshotWrite(
                    .legacyDatabaseMigrationRequired
                )
        )
    }
}
