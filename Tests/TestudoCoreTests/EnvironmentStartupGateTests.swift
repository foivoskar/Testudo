import Foundation
import XCTest
@testable import TestudoCore

final class EnvironmentStartupGateTests: XCTestCase {

    private let environmentID = UUID(
        uuidString:
            "11111111-2222-3333-4444-555555555555"
    )!

    private func directory() throws -> URL {
        let root =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "TestudoStartupTests-" + UUID().uuidString,
                    isDirectory: true
                )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )

        return root
    }

    private func writeJSON(
        _ object: [String: Any],
        to url: URL
    ) throws {
        let raw = try JSONSerialization.data(
            withJSONObject: object
        )

        try raw.write(to: url)
    }

    private func localDatabase(
        at root: URL,
        schema: Int = 8
    ) throws -> URL {

        let url = root.appendingPathComponent(
            "TestudoData.json"
        )

        try writeJSON(
            [
                "schemaVersion": schema,
                "workItems": []
            ],
            to: url
        )

        return url
    }

    private func environmentDatabase(
        at root: URL,
        databaseSchema: Int = 8,
        manifestSchema: Int = 2,
        syncVersion: Int? = nil
    ) throws -> URL {

        let package = root.appendingPathComponent(
            "Research.testudoenv",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: package,
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

        try writeJSON(
            manifest,
            to: package.appendingPathComponent(
                "EnvironmentManifest.json"
            )
        )

        let databaseURL = package.appendingPathComponent(
            "EnvironmentData.json"
        )

        try writeJSON(
            [
                "schemaVersion": databaseSchema,
                "workItems": []
            ],
            to: databaseURL
        )

        return databaseURL
    }

    private func inspect(
        _ url: URL,
        expectedID: UUID? = nil
    ) throws -> EnvironmentStartupDisposition {

        try EnvironmentStartupGate.inspect(
            databaseURL: url,
            expectedEnvironmentID: expectedID
        )
    }

    func testMissingLocalRootIsNewInstallation() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent(
            "TestudoData.json"
        )

        XCTAssertEqual(
            try inspect(url),
            .newLocalInstallation
        )

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: url.path)
        )
    }

    func testExistingLegacyRootIsReadable() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try localDatabase(at: root)

        XCTAssertEqual(
            try inspect(url),
            .readableLegacyRoot
        )
    }

    func testSchemaNineLocalRootIsReadable() throws {
        let root = try directory()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let url = try localDatabase(
            at: root,
            schema: 9
        )

        XCTAssertEqual(
            try inspect(url),
            .readableLegacyRoot
        )
    }

    func testSchemaTenLocalRootIsBlocked() throws {
        let root = try directory()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let url = try localDatabase(
            at: root,
            schema: 10
        )

        XCTAssertEqual(
            try inspect(url),
            .blocked(.unsupported)
        )
    }

    func testFutureLocalRootIsBlocked() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try localDatabase(
            at: root,
            schema: 99
        )

        XCTAssertEqual(
            try inspect(url),
            .blocked(.unsupported)
        )
    }

    func testCorruptLocalRootThrows() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent(
            "TestudoData.json"
        )

        try Data("invalid json".utf8).write(to: url)

        XCTAssertThrowsError(
            try inspect(url)
        )
    }

    func testLegacyEnvironmentIsReadable() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try environmentDatabase(at: root)

        XCTAssertEqual(
            try inspect(url, expectedID: environmentID),
            .readableLegacyEnvironment
        )
    }

    func testSchemaSevenDoesNotMigrateAutomatically() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try environmentDatabase(
            at: root,
            databaseSchema: 7
        )

        XCTAssertEqual(
            try inspect(url, expectedID: environmentID),
            .blocked(.legacyDatabaseMigrationRequired)
        )
    }

    func testJournalRequiresDifferentEngine() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try environmentDatabase(
            at: root,
            syncVersion: 1
        )

        XCTAssertEqual(
            try inspect(url, expectedID: environmentID),
            .blocked(.journalEngineUnavailable)
        )
    }

    func testIncorrectIdentityIsBlocked() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try environmentDatabase(at: root)

        XCTAssertEqual(
            try inspect(url, expectedID: UUID()),
            .blocked(.unsupported)
        )
    }

    func testMissingManifestIsNotReconstructed() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try environmentDatabase(at: root)

        let manifest = url.deletingLastPathComponent()
            .appendingPathComponent(
                "EnvironmentManifest.json"
            )

        try FileManager.default.removeItem(at: manifest)

        XCTAssertThrowsError(
            try inspect(url, expectedID: environmentID)
        )

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: manifest.path)
        )
    }

    func testUnexpectedFilenameIsRejected() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent(
            "UnknownDatabase.json"
        )

        XCTAssertThrowsError(
            try inspect(url)
        ) { error in
            XCTAssertEqual(
                error as? EnvironmentStartupGateError,
                .invalidDatabaseLocation
            )
        }
    }

    func testInspectionNeverModifiesDatabase() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try environmentDatabase(at: root)

        let manifestURL = url.deletingLastPathComponent()
            .appendingPathComponent(
                "EnvironmentManifest.json"
            )

        let originalDatabase = try Data(contentsOf: url)
        let originalManifest = try Data(contentsOf: manifestURL)

        XCTAssertEqual(
            try inspect(url, expectedID: environmentID),
            .readableLegacyEnvironment
        )

        XCTAssertEqual(
            try Data(contentsOf: url),
            originalDatabase
        )

        XCTAssertEqual(
            try Data(contentsOf: manifestURL),
            originalManifest
        )
    }
}
