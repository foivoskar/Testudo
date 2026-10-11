import Foundation
import XCTest
@testable import Testudo

final class TestudoEnvironmentActivationTests: XCTestCase {

    private struct PackageFixture {
        let id: UUID
        let packageURL: URL
        let databaseURL: URL
        let manifestURL: URL
        let environment: WorkEnvironment
    }

    private func temporaryRoot() throws -> URL {
        let parent =
            FileManager.default.temporaryDirectory
                .standardizedFileURL

        let directory =
            parent.appendingPathComponent(
                "TestudoActivation-\(UUID().uuidString)",
                isDirectory: true
            )

        guard
            directory.deletingLastPathComponent()
                .standardizedFileURL == parent
        else {
            throw NSError(
                domain: "TestudoActivationTests",
                code: 1
            )
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )

        return directory
    }

    private func writeJSON<T: Encodable>(
        _ value: T,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        try encoder.encode(value).write(
            to: url,
            options: .atomic
        )
    }

    private func makePackage(
        in root: URL,
        name: String,
        manifestSchema: Int = 2
    ) throws -> PackageFixture {
        let id = UUID()

        let packageURL =
            root.appendingPathComponent(
                "\(name).testudoenv",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: packageURL,
            withIntermediateDirectories: false
        )

        let databaseURL =
            packageURL.appendingPathComponent(
                "EnvironmentData.json"
            )

        let manifestURL =
            packageURL.appendingPathComponent(
                "EnvironmentManifest.json"
            )

        let date = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        var database = TestudoData()
        database.schemaVersion = 8

        var manifest = EnvironmentManifest(
            environmentID: id,
            name: name,
            createdAt: date,
            updatedAt: date
        )

        manifest.schemaVersion = manifestSchema

        manifest.identityProvider =
            EnvironmentIdentityProviderConfiguration(
                createdAt: date,
                updatedAt: date
            )

        try writeJSON(
            database,
            to: databaseURL
        )

        try writeJSON(
            manifest,
            to: manifestURL
        )

        var storage =
            EnvironmentStorageConfiguration()

        storage.kind = .testudoPackage
        storage.displayName = name
        storage.path = packageURL.path

        let environment = WorkEnvironment(
            id: id,
            name: name,
            storage: storage
        )

        return PackageFixture(
            id: id,
            packageURL: packageURL,
            databaseURL: databaseURL,
            manifestURL: manifestURL,
            environment: environment
        )
    }

    private func writeRegistry(
        in root: URL,
        environments: [WorkEnvironment],
        activeID: UUID? = nil
    ) throws -> URL {
        let registryURL =
            root.appendingPathComponent(
                "ApplicationData.json"
            )

        var registry = ApplicationData()
        registry.workEnvironments = environments
        registry.activeEnvironmentID = activeID

        try writeJSON(
            registry,
            to: registryURL
        )

        return registryURL
    }

    private func packageBytes(
        _ fixture: PackageFixture
    ) throws -> (Data, Data) {
        (
            try Data(contentsOf: fixture.databaseURL),
            try Data(contentsOf: fixture.manifestURL)
        )
    }

    func testValidActivationPreservesEnvironmentFiles() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let fixture = try makePackage(
            in: root,
            name: "Valid"
        )

        _ = try writeRegistry(
            in: root,
            environments: [fixture.environment]
        )

        let before = try packageBytes(fixture)

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            let error = store.activateEnvironment(
                id: fixture.id
            )

            return (
                error,
                store.applicationData.activeEnvironmentID,
                store.fileURL,
                store.startupBlockedReason
            )
        }

        XCTAssertNil(result.0)
        XCTAssertEqual(result.1, fixture.id)
        XCTAssertEqual(result.2, fixture.databaseURL)
        XCTAssertNil(result.3)

        let after = try packageBytes(fixture)

        XCTAssertEqual(after.0, before.0)
        XCTAssertEqual(after.1, before.1)
    }

    func testIncompatibleEnvironmentIsRejectedWithoutMutation() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let fixture = try makePackage(
            in: root,
            name: "Future",
            manifestSchema: 999
        )

        let registryURL = try writeRegistry(
            in: root,
            environments: [fixture.environment]
        )

        let before = try packageBytes(fixture)
        let registryBefore = try Data(
            contentsOf: registryURL
        )

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            let error = store.activateEnvironment(
                id: fixture.id
            )

            return (
                error,
                store.applicationData.activeEnvironmentID,
                store.fileURL
            )
        }

        XCTAssertNotNil(result.0)
        XCTAssertNil(result.1)

        XCTAssertNotEqual(
            result.2,
            fixture.databaseURL
        )

        let after = try packageBytes(fixture)

        XCTAssertEqual(after.0, before.0)
        XCTAssertEqual(after.1, before.1)

        XCTAssertEqual(
            try Data(contentsOf: registryURL),
            registryBefore
        )
    }

    func testRecoveryFromBlockedEnvironment() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let invalid = try makePackage(
            in: root,
            name: "Blocked",
            manifestSchema: 999
        )

        let valid = try makePackage(
            in: root,
            name: "Recovery"
        )

        let registryURL = try writeRegistry(
            in: root,
            environments: [
                invalid.environment,
                valid.environment
            ],
            activeID: invalid.id
        )

        let invalidBefore = try packageBytes(invalid)
        let validBefore = try packageBytes(valid)

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            let initialBlock =
                store.startupBlockedReason

            let recoveryError =
                store.activateEnvironment(
                    id: valid.id
                )

            return (
                initialBlock,
                recoveryError,
                store.startupBlockedReason,
                store.applicationData.activeEnvironmentID
            )
        }

        XCTAssertNotNil(result.0)
        XCTAssertNil(result.1)
        XCTAssertNil(result.2)
        XCTAssertEqual(result.3, valid.id)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let persisted = try decoder.decode(
            ApplicationData.self,
            from: Data(contentsOf: registryURL)
        )

        XCTAssertEqual(
            persisted.activeEnvironmentID,
            valid.id
        )

        let invalidAfter = try packageBytes(invalid)
        let validAfter = try packageBytes(valid)

        XCTAssertEqual(
            invalidAfter.0,
            invalidBefore.0
        )

        XCTAssertEqual(
            invalidAfter.1,
            invalidBefore.1
        )

        XCTAssertEqual(
            validAfter.0,
            validBefore.0
        )

        XCTAssertEqual(
            validAfter.1,
            validBefore.1
        )
    }

    func testOpenEnvironmentRequiresIdentityWithoutRewritingPackage() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let fixture = try makePackage(
            in: root,
            name: "Identity"
        )

        _ = try writeRegistry(
            in: root,
            environments: [fixture.environment]
        )

        let before = try packageBytes(fixture)

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            let outcome =
                store.openWorkEnvironment(
                    id: fixture.id
                )

            let identityRequired: Bool

            if case .identityRequired = outcome {
                identityRequired = true
            } else {
                identityRequired = false
            }

            return (
                identityRequired,
                store.environmentSessionIsOpen,
                store.applicationData.activeEnvironmentID
            )
        }

        XCTAssertTrue(result.0)
        XCTAssertFalse(result.1)
        XCTAssertEqual(result.2, fixture.id)

        let after = try packageBytes(fixture)

        XCTAssertEqual(after.0, before.0)
        XCTAssertEqual(after.1, before.1)
    }

    func testSwitchingBetweenEnvironmentsPreservesBothPackages() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let first = try makePackage(
            in: root,
            name: "First"
        )

        let second = try makePackage(
            in: root,
            name: "Second"
        )

        _ = try writeRegistry(
            in: root,
            environments: [
                first.environment,
                second.environment
            ]
        )

        let firstBefore = try packageBytes(first)
        let secondBefore = try packageBytes(second)

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            let firstError =
                store.activateEnvironment(
                    id: first.id
                )

            let firstSelected =
                store.applicationData.activeEnvironmentID

            let secondError =
                store.activateEnvironment(
                    id: second.id
                )

            return (
                firstError,
                firstSelected,
                secondError,
                store.applicationData.activeEnvironmentID,
                store.fileURL
            )
        }

        XCTAssertNil(result.0)
        XCTAssertEqual(result.1, first.id)
        XCTAssertNil(result.2)
        XCTAssertEqual(result.3, second.id)
        XCTAssertEqual(result.4, second.databaseURL)

        let firstAfter = try packageBytes(first)
        let secondAfter = try packageBytes(second)

        XCTAssertEqual(firstAfter.0, firstBefore.0)
        XCTAssertEqual(firstAfter.1, firstBefore.1)
        XCTAssertEqual(secondAfter.0, secondBefore.0)
        XCTAssertEqual(secondAfter.1, secondBefore.1)
    }

    func testCorruptRegistryBlocksRegistrationAndRecovery() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let fixture = try makePackage(
            in: root,
            name: "RegistryFailure"
        )

        let registryURL =
            root.appendingPathComponent(
                "ApplicationData.json"
            )

        let corruptRegistry = Data(
            "{invalid application registry".utf8
        )

        try corruptRegistry.write(
            to: registryURL,
            options: .atomic
        )

        let packageBefore =
            try packageBytes(fixture)

        let result = await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            let initialBlock =
                store.startupBlockedReason

            let registration =
                store.registerWorkEnvironment(
                    from: fixture.packageURL
                )

            let activationError =
                store.activateEnvironment(
                    id: fixture.id
                )

            return (
                initialBlock,
                registration.environmentID,
                registration.error,
                activationError,
                store.startupBlockedReason,
                store.applicationData.workEnvironments.count,
                store.applicationData.activeEnvironmentID
            )
        }

        XCTAssertNotNil(result.0)

        XCTAssertNil(result.1)

        XCTAssertNotNil(result.2)

        XCTAssertNotNil(result.3)

        XCTAssertNotNil(result.4)

        XCTAssertEqual(result.5, 0)

        XCTAssertNil(result.6)

        XCTAssertEqual(
            try Data(contentsOf: registryURL),
            corruptRegistry
        )

        let packageAfter =
            try packageBytes(fixture)

        XCTAssertEqual(
            packageAfter.0,
            packageBefore.0
        )

        XCTAssertEqual(
            packageAfter.1,
            packageBefore.1
        )
    }
}
