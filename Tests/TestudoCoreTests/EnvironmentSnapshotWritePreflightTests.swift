import Foundation
import XCTest
@testable import TestudoCore

final class EnvironmentSnapshotWritePreflightTests:
    XCTestCase
{
    private let environmentID = UUID(
        uuidString:
            "11111111-2222-3333-4444-555555555555"
    )!

    private struct Fixture {
        let root: URL

        var databaseURL: URL {
            root.appendingPathComponent(
                "EnvironmentData.json"
            )
        }

        var manifestURL: URL {
            root.appendingPathComponent(
                "EnvironmentManifest.json"
            )
        }
    }

    private func fixture(
        manifestSchema: Int = 2,
        databaseSchema: Int = 8,
        syncVersion: Int? = nil
    ) throws -> Fixture {

        let root =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "TestudoWritePreflight-" +
                    UUID().uuidString +
                    ".testudoenv",
                    isDirectory: true
                )

        try FileManager.default.createDirectory(
            at: root,
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

        let result = Fixture(root: root)

        try JSONSerialization.data(
            withJSONObject: manifest
        ).write(to: result.manifestURL)

        try JSONSerialization.data(
            withJSONObject: database
        ).write(to: result.databaseURL)

        return result
    }

    private func verify(
        _ item: Fixture,
        expectedID: UUID? = nil
    ) throws {

        try EnvironmentSnapshotWritePreflight.verify(
            databaseURL: item.databaseURL,
            expectedEnvironmentID:
                expectedID ?? environmentID
        )
    }

    private func assertDenied(
        _ item: Fixture,
        status: EnvironmentCompatibilityStatus,
        expectedID: UUID? = nil
    ) {

        XCTAssertThrowsError(
            try verify(
                item,
                expectedID: expectedID
            )
        ) { error in

            XCTAssertEqual(
                error as? EnvironmentSnapshotWritePreflightError,
                .incompatible(status)
            )
        }
    }

    func testSchemaNinePermitsSnapshotWriting() throws {
        let item = try fixture(databaseSchema: 9)

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        XCTAssertNoThrow(try verify(item))
    }

    func testSchemaTenRejectsSnapshotWriting() throws {
        let item = try fixture(databaseSchema: 10)

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        assertDenied(
            item,
            status: .unsupported
        )
    }

    func testLegacySchemaEightPermitsWriting() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        XCTAssertNoThrow(try verify(item))
    }

    func testSchemaSevenRejectsSnapshotWriting() throws {
        let item = try fixture(databaseSchema: 7)

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        assertDenied(
            item,
            status: .legacyDatabaseMigrationRequired
        )
    }

    func testJournalRejectsSnapshotWriting() throws {
        let item = try fixture(syncVersion: 1)

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        assertDenied(
            item,
            status: .journalEngineUnavailable
        )
    }

    func testFutureDatabaseRejectsWriting() throws {
        let item = try fixture(databaseSchema: 99)

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        assertDenied(
            item,
            status: .unsupported
        )
    }

    func testFutureManifestRejectsWriting() throws {
        let item = try fixture(manifestSchema: 99)

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        assertDenied(
            item,
            status: .unsupported
        )
    }

    func testIdentityMismatchRejectsWriting() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        assertDenied(
            item,
            status: .unsupported,
            expectedID: UUID()
        )
    }

    func testMissingManifestRejectsWriting() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        try FileManager.default.removeItem(
            at: item.manifestURL
        )

        XCTAssertThrowsError(
            try verify(item)
        )
    }

    func testMissingDatabaseRejectsWriting() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        try FileManager.default.removeItem(
            at: item.databaseURL
        )

        XCTAssertThrowsError(
            try verify(item)
        )
    }

    func testIncorrectDatabaseFilenameIsRejected() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        let invalidURL =
            item.root.appendingPathComponent(
                "OtherData.json"
            )

        XCTAssertThrowsError(
            try EnvironmentSnapshotWritePreflight.verify(
                databaseURL: invalidURL,
                expectedEnvironmentID: environmentID
            )
        ) { error in

            XCTAssertEqual(
                error as? EnvironmentSnapshotWritePreflightError,
                .invalidDatabaseLocation
            )
        }
    }

    func testPreflightNeverModifiesFiles() throws {
        let item = try fixture()

        defer {
            try? FileManager.default.removeItem(
                at: item.root
            )
        }

        let originalManifest =
            try Data(contentsOf: item.manifestURL)

        let originalDatabase =
            try Data(contentsOf: item.databaseURL)

        try verify(item)

        XCTAssertEqual(
            try Data(contentsOf: item.manifestURL),
            originalManifest
        )

        XCTAssertEqual(
            try Data(contentsOf: item.databaseURL),
            originalDatabase
        )
    }
}
