import Foundation
import XCTest
@testable import TestudoCore

final class EnvironmentCompatibilityFileGuardTests:
    XCTestCase
{
    private let environmentID = UUID(
        uuidString:
            "11111111-2222-3333-4444-555555555555"
    )!

    private struct Fixture {
        let url: URL
        let manifestData: Data
        let databaseData: Data

        var manifestURL: URL {
            url.appendingPathComponent(
                "EnvironmentManifest.json"
            )
        }

        var databaseURL: URL {
            url.appendingPathComponent(
                "EnvironmentData.json"
            )
        }
    }

    private func fixture(
        manifestSchema: Int = 2,
        databaseSchema: Int = 8,
        syncVersion: Int? = nil
    ) throws -> Fixture {

        let directory =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "TestudoCompatibility-" + UUID().uuidString
                )
                .appendingPathExtension("testudoenv")

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )

        var manifest: [String: Any] = [
            "schemaVersion": manifestSchema,
            "environmentID": environmentID.uuidString,
            "name": "Research"
        ]

        if let syncVersion {
            manifest["syncFormatVersion"] = syncVersion
        }

        let database: [String: Any] = [
            "schemaVersion": databaseSchema,
            "workItems": [],
            "entities": []
        ]

        let manifestData =
            try JSONSerialization.data(
                withJSONObject: manifest
            )

        let databaseData =
            try JSONSerialization.data(
                withJSONObject: database
            )

        let result = Fixture(
            url: directory,
            manifestData: manifestData,
            databaseData: databaseData
        )

        try manifestData.write(
            to: result.manifestURL
        )

        try databaseData.write(
            to: result.databaseURL
        )

        return result
    }

    func testLegacySchemaEightIsAccepted() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.url
            )
        }

        let result =
            try EnvironmentCompatibilityFileGuard.inspect(
                at: item.url,
                expectedEnvironmentID: environmentID
            )

        XCTAssertEqual(result, .legacyReady)
    }

    func testLegacySchemaSevenRequiresMigration() throws {
        let item = try fixture(databaseSchema: 7)

        defer {
            try? FileManager.default.removeItem(
                at: item.url
            )
        }

        let result =
            try EnvironmentCompatibilityFileGuard.inspect(
                at: item.url,
                expectedEnvironmentID: environmentID
            )

        XCTAssertEqual(
            result,
            .legacyDatabaseMigrationRequired
        )
    }

    func testJournalRequiresNewEngine() throws {
        let item = try fixture(syncVersion: 1)

        defer {
            try? FileManager.default.removeItem(
                at: item.url
            )
        }

        let result =
            try EnvironmentCompatibilityFileGuard.inspect(
                at: item.url
            )

        XCTAssertEqual(
            result,
            .journalEngineUnavailable
        )
    }

    func testFutureDatabaseIsRejected() throws {
        let item = try fixture(databaseSchema: 99)

        defer {
            try? FileManager.default.removeItem(
                at: item.url
            )
        }

        let result =
            try EnvironmentCompatibilityFileGuard.inspect(
                at: item.url
            )

        XCTAssertEqual(result, .unsupported)
    }

    func testIncorrectEnvironmentIdentityIsRejected() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.url
            )
        }

        let result =
            try EnvironmentCompatibilityFileGuard.inspect(
                at: item.url,
                expectedEnvironmentID: UUID()
            )

        XCTAssertEqual(result, .unsupported)
    }

    func testMissingManifestFailsWithoutCreatingIt() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.url
            )
        }

        try FileManager.default.removeItem(
            at: item.manifestURL
        )

        XCTAssertThrowsError(
            try EnvironmentCompatibilityFileGuard.inspect(
                at: item.url
            )
        )

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: item.manifestURL.path
            )
        )
    }

    func testInspectionDoesNotModifyFiles() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.url
            )
        }

        _ = try EnvironmentCompatibilityFileGuard.inspect(
            at: item.url
        )

        XCTAssertEqual(
            try Data(contentsOf: item.manifestURL),
            item.manifestData
        )

        XCTAssertEqual(
            try Data(contentsOf: item.databaseURL),
            item.databaseData
        )
    }
}
