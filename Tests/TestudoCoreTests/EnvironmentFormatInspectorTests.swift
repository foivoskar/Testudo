import Foundation
import XCTest
@testable import TestudoCore

final class EnvironmentFormatInspectorTests: XCTestCase {

    private func manifest(
        syncVersion: Int? = nil,
        schemaVersion: Int = 2
    ) throws -> Data {

        var object: [String: Any] = [
            "schemaVersion": schemaVersion,
            "environmentID": UUID().uuidString,
            "name": "Research"
        ]

        if let syncVersion {
            object["syncFormatVersion"] = syncVersion
        }

        return try JSONSerialization.data(
            withJSONObject: object
        )
    }

    func testLegacyEnvironmentRequiresMigration() throws {
        let result = try EnvironmentFormatInspector.assess(
            manifestData: manifest()
        )

        XCTAssertEqual(
            result,
            .legacyRequiresMigration
        )
    }

    func testSupportedJournalFormat() throws {
        let result = try EnvironmentFormatInspector.assess(
            manifestData: manifest(syncVersion: 1)
        )

        XCTAssertEqual(
            result,
            .supportedJournal
        )
    }

    func testFutureFormatIsUnsupported() throws {
        let result = try EnvironmentFormatInspector.assess(
            manifestData: manifest(syncVersion: 99)
        )

        XCTAssertEqual(
            result,
            .unsupported
        )
    }

    func testInvalidManifestIsRejected() {
        let invalid = Data("not valid json".utf8)

        XCTAssertThrowsError(
            try EnvironmentFormatInspector.assess(
                manifestData: invalid
            )
        )
    }

    func testLegacySchemaOneRequiresMigration() throws {
        let result = try EnvironmentFormatInspector.assess(
            manifestData: manifest(schemaVersion: 1)
        )

        XCTAssertEqual(result, .legacyRequiresMigration)
    }

    func testUnknownManifestSchemaIsUnsupported() throws {
        let result = try EnvironmentFormatInspector.assess(
            manifestData: manifest(schemaVersion: 99)
        )

        XCTAssertEqual(result, .unsupported)
    }

    func testInvalidManifestSchemaIsUnsupported() throws {
        let result = try EnvironmentFormatInspector.assess(
            manifestData: manifest(schemaVersion: 0)
        )

        XCTAssertEqual(result, .unsupported)
    }

    func testInvalidJournalVersionIsUnsupported() throws {
        let result = try EnvironmentFormatInspector.assess(
            manifestData: manifest(syncVersion: 0)
        )

        XCTAssertEqual(
            result,
            .unsupported
        )
    }
}
