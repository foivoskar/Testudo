import Foundation
import XCTest
@testable import Testudo

final class TestudoStoreInitializationTests: XCTestCase {

    private func makeTemporaryStorage() throws -> URL {
        let parent =
            FileManager.default.temporaryDirectory
                .standardizedFileURL

        let directory =
            parent.appendingPathComponent(
                "TestudoStoreIntegration-\(UUID().uuidString)",
                isDirectory: true
            )

        guard
            directory.deletingLastPathComponent()
                .standardizedFileURL == parent
        else {
            throw NSError(
                domain: "TestudoIntegrationTests",
                code: 1
            )
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )

        return directory
    }

    private func writeFixture<T: Encodable>(
        _ value: T,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let encoded = try encoder.encode(value)

        try encoded.write(
            to: url,
            options: .atomic
        )
    }

    func testNewInstallationDoesNotCreateFiles() async throws {
        let directory = try makeTemporaryStorage()

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            return (
                store.startupBlockedReason,
                store.fileURL,
                store.applicationFileURL,
                store.data.schemaVersion
            )
        }

        XCTAssertNil(result.0)

        XCTAssertEqual(
            result.1,
            directory.appendingPathComponent(
                "TestudoData.json"
            )
        )

        XCTAssertEqual(
            result.2,
            directory.appendingPathComponent(
                "ApplicationData.json"
            )
        )

        XCTAssertEqual(result.3, 8)

        let contents =
            try FileManager.default.contentsOfDirectory(
                atPath: directory.path
            )

        XCTAssertTrue(contents.isEmpty)
    }

    func testValidSchemaEightRootIsNotRewritten() async throws {
        let directory = try makeTemporaryStorage()

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let databaseURL =
            directory.appendingPathComponent(
                "TestudoData.json"
            )

        try writeFixture(
            TestudoData(),
            to: databaseURL
        )

        let original = try Data(
            contentsOf: databaseURL
        )

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            return (
                store.startupBlockedReason,
                store.data.schemaVersion
            )
        }

        XCTAssertNil(result.0)
        XCTAssertEqual(result.1, 8)

        XCTAssertEqual(
            try Data(contentsOf: databaseURL),
            original
        )
    }

    func testCorruptApplicationRegistryIsPreserved() async throws {
        let directory = try makeTemporaryStorage()

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let registryURL =
            directory.appendingPathComponent(
                "ApplicationData.json"
            )

        let invalid = Data(
            "invalid application registry".utf8
        )

        try invalid.write(
            to: registryURL,
            options: .atomic
        )

        let blockedReason = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            return store.startupBlockedReason
        }

        XCTAssertNotNil(blockedReason)

        XCTAssertEqual(
            try Data(contentsOf: registryURL),
            invalid
        )

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory
                    .appendingPathComponent(
                        "TestudoData.json"
                    )
                    .path
            )
        )
    }

    func testFutureRootSchemaIsBlockedWithoutMutation() async throws {
        let directory = try makeTemporaryStorage()

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let databaseURL =
            directory.appendingPathComponent(
                "TestudoData.json"
            )

        let futureDatabase = Data(
            "{\"schemaVersion\":9}".utf8
        )

        try futureDatabase.write(
            to: databaseURL,
            options: .atomic
        )

        let blockedReason = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            return store.startupBlockedReason
        }

        XCTAssertNotNil(blockedReason)

        XCTAssertEqual(
            try Data(contentsOf: databaseURL),
            futureDatabase
        )
    }

    func testCorruptRootJSONIsPreserved() async throws {
        let directory = try makeTemporaryStorage()

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let databaseURL =
            directory.appendingPathComponent(
                "TestudoData.json"
            )

        let invalid = Data(
            "{invalid-json".utf8
        )

        try invalid.write(
            to: databaseURL,
            options: .atomic
        )

        let blockedReason = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            return store.startupBlockedReason
        }

        XCTAssertNotNil(blockedReason)

        XCTAssertEqual(
            try Data(contentsOf: databaseURL),
            invalid
        )
    }

    func testRegisteredEnvironmentWithoutActiveSelection() async throws {
        let directory = try makeTemporaryStorage()

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let registryURL =
            directory.appendingPathComponent(
                "ApplicationData.json"
            )

        var registry = ApplicationData()

        registry.workEnvironments.append(
            WorkEnvironment(
                name: "Integration Fixture Environment"
            )
        )

        try writeFixture(
            registry,
            to: registryURL
        )

        let original = try Data(
            contentsOf: registryURL
        )

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            return (
                store.startupBlockedReason,
                store.applicationData.workEnvironments.count,
                store.applicationData.activeEnvironmentID
            )
        }

        XCTAssertNil(result.0)
        XCTAssertEqual(result.1, 1)
        XCTAssertNil(result.2)

        XCTAssertEqual(
            try Data(contentsOf: registryURL),
            original
        )
    }

    func testMissingActiveEnvironmentIsBlocked() async throws {
        let directory = try makeTemporaryStorage()

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let registryURL =
            directory.appendingPathComponent(
                "ApplicationData.json"
            )

        var registry = ApplicationData()
        registry.activeEnvironmentID = UUID()

        try writeFixture(
            registry,
            to: registryURL
        )

        let original = try Data(
            contentsOf: registryURL
        )

        let blockedReason = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            return store.startupBlockedReason
        }

        XCTAssertNotNil(blockedReason)

        XCTAssertEqual(
            try Data(contentsOf: registryURL),
            original
        )
    }
}
