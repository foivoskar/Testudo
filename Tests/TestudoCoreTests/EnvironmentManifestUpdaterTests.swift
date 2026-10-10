import Foundation
import XCTest
@testable import TestudoCore

final class EnvironmentManifestUpdaterTests: XCTestCase {

    private let environmentID = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    )!

    private let fixedDate = Date(
        timeIntervalSince1970: 1_700_000_000
    )

    private func manifest(
        schema: Int = 2,
        identityProvider: [String: Any]? = nil,
        extra: [String: Any] = [:]
    ) throws -> Data {

        var object: [String: Any] = [
            "schemaVersion": schema,
            "environmentID": environmentID.uuidString,
            "name": "Research",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z"
        ]

        if let identityProvider {
            object["identityProvider"] = identityProvider
        }

        for (key, value) in extra {
            object[key] = value
        }

        return try JSONSerialization.data(
            withJSONObject: object
        )
    }

    private func provider() throws -> Data {
        let object: [String: Any] = [
            "kind": "localAccounts",
            "displayName": "Local Environment Accounts",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z"
        ]

        return try JSONSerialization.data(
            withJSONObject: object
        )
    }

    private func update(_ data: Data) throws -> Data? {
        try EnvironmentManifestUpdater.updateLegacyManifest(
            data,
            expectedEnvironmentID: environmentID,
            identityProviderData: provider(),
            updatedAt: fixedDate
        )
    }

    private func object(
        from data: Data
    ) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]
        )
    }

    func testSchemaOneUpgradesToTwo() throws {
        let original = try manifest(schema: 1)
        let updated = try XCTUnwrap(update(original))
        let result = try object(from: updated)

        XCTAssertEqual(
            result["schemaVersion"] as? Int,
            2
        )

        XCTAssertNotNil(result["identityProvider"])
    }

    func testSchemaTwoAddsMissingIdentity() throws {
        let original = try manifest(schema: 2)
        let updated = try XCTUnwrap(update(original))
        let result = try object(from: updated)

        XCTAssertEqual(
            result["schemaVersion"] as? Int,
            2
        )

        XCTAssertNotNil(result["identityProvider"])
    }

    func testAlreadyCompleteManifestIsNotModified() throws {
        let existing: [String: Any] = [
            "kind": "localAccounts",
            "displayName": "Existing Provider"
        ]

        let original = try manifest(
            identityProvider: existing
        )

        XCTAssertNil(try update(original))
    }

    func testUnknownFieldsArePreserved() throws {
        let original = try manifest(
            schema: 1,
            extra: [
                "customMetadata": [
                    "important": "keep this value"
                ]
            ]
        )

        let updated = try XCTUnwrap(update(original))
        let result = try object(from: updated)

        let metadata = try XCTUnwrap(
            result["customMetadata"] as? [String: Any]
        )

        XCTAssertEqual(
            metadata["important"] as? String,
            "keep this value"
        )
    }

    func testJournalManifestIsRejected() throws {
        let original = try manifest(
            extra: ["syncFormatVersion": 1]
        )

        XCTAssertThrowsError(
            try update(original)
        )
    }

    func testFutureManifestIsRejected() throws {
        let original = try manifest(schema: 99)

        XCTAssertThrowsError(
            try update(original)
        )
    }

    func testFutureProtocolMetadataIsRejected() throws {
        let original = try manifest(
            extra: ["formatVersion": 3]
        )

        XCTAssertThrowsError(
            try update(original)
        )
    }

    func testWrongEnvironmentIdentityIsRejected() throws {
        let original = try manifest()
        var result = try object(from: original)

        result["environmentID"] = UUID().uuidString

        let modified = try JSONSerialization.data(
            withJSONObject: result
        )

        XCTAssertThrowsError(
            try update(modified)
        )
    }

    func testUpdateIsIdempotent() throws {
        let original = try manifest(schema: 1)

        let first = try XCTUnwrap(update(original))

        XCTAssertNil(
            try update(first)
        )
    }

    func testInvalidIdentityProviderIsRejected() throws {
        let original = try manifest(schema: 1)

        XCTAssertThrowsError(
            try EnvironmentManifestUpdater.updateLegacyManifest(
                original,
                expectedEnvironmentID: environmentID,
                identityProviderData: Data("invalid".utf8),
                updatedAt: fixedDate
            )
        )
    }
}
