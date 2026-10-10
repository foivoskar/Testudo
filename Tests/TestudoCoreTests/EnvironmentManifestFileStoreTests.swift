import Foundation
import XCTest
@testable import TestudoCore

final class EnvironmentManifestFileStoreTests: XCTestCase {

    private let environmentID = UUID(
        uuidString:
            "11111111-2222-3333-4444-555555555555"
    )!

    private let fixedDate = Date(
        timeIntervalSince1970: 1_700_000_000
    )

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "TestudoManifestTests-" + UUID().uuidString
            )

        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )

        return url
    }

    private func manifest(
        schema: Int = 1,
        environmentID: UUID? = nil,
        providerPresent: Bool = false,
        journal: Bool = false
    ) throws -> Data {

        var object: [String: Any] = [
            "schemaVersion": schema,
            "environmentID":
                (environmentID ?? self.environmentID).uuidString,
            "name": "Research",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z",
            "customField": "preserve"
        ]

        if providerPresent {
            object["identityProvider"] = [
                "kind": "localAccounts",
                "displayName": "Existing Provider"
            ]
        }

        if journal {
            object["syncFormatVersion"] = 1
        }

        return try JSONSerialization.data(
            withJSONObject: object
        )
    }

    private func provider() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "kind": "localAccounts",
                "displayName": "Local Environment Accounts"
            ]
        )
    }

    private func update(at url: URL) throws -> Bool {
        try EnvironmentManifestFileStore
            .updateExistingLegacyManifest(
                at: url,
                expectedEnvironmentID: environmentID,
                identityProviderData: provider(),
                updatedAt: fixedDate
            )
    }

    func testLegacyFileUpgradesOnlyOnce() throws {
        let root = try directory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let file = root.appendingPathComponent(
            "EnvironmentManifest.json"
        )

        try manifest().write(to: file)

        XCTAssertTrue(try update(at: file))

        let first = try Data(contentsOf: file)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: first
            ) as? [String: Any]
        )

        XCTAssertEqual(
            object["schemaVersion"] as? Int,
            2
        )

        XCTAssertEqual(
            object["customField"] as? String,
            "preserve"
        )

        XCTAssertNotNil(object["identityProvider"])

        XCTAssertFalse(try update(at: file))

        XCTAssertEqual(
            try Data(contentsOf: file),
            first
        )
    }

    func testCompleteFileIsNotRewritten() throws {
        let root = try directory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let file = root.appendingPathComponent(
            "EnvironmentManifest.json"
        )

        let original = try manifest(
            schema: 2,
            providerPresent: true
        )

        try original.write(to: file)

        XCTAssertFalse(try update(at: file))

        XCTAssertEqual(
            try Data(contentsOf: file),
            original
        )
    }

    func testJournalFileIsNotModified() throws {
        let root = try directory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let file = root.appendingPathComponent(
            "EnvironmentManifest.json"
        )

        let original = try manifest(journal: true)
        try original.write(to: file)

        XCTAssertThrowsError(
            try update(at: file)
        )

        XCTAssertEqual(
            try Data(contentsOf: file),
            original
        )
    }

    func testWrongEnvironmentIsNotModified() throws {
        let root = try directory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let file = root.appendingPathComponent(
            "EnvironmentManifest.json"
        )

        let original = try manifest(
            environmentID: UUID()
        )

        try original.write(to: file)

        XCTAssertThrowsError(
            try update(at: file)
        )

        XCTAssertEqual(
            try Data(contentsOf: file),
            original
        )
    }

    func testMissingFileIsNotCreated() throws {
        let root = try directory()
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let file = root.appendingPathComponent(
            "EnvironmentManifest.json"
        )

        XCTAssertThrowsError(
            try update(at: file)
        )

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: file.path
            )
        )
    }
}
