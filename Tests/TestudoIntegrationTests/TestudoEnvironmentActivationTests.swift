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

    func testPlannedStartUpgradesRealPackageFixture() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let fixture = try makePackage(
            in: root,
            name: "PlannedStartUpgrade"
        )

        _ = try writeRegistry(
            in: root,
            environments: [fixture.environment]
        )

        let originalManifest = try Data(
            contentsOf: fixture.manifestURL
        )

        let failure = await MainActor.run { () -> String? in
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            if let error = store.activateEnvironment(
                id: fixture.id
            ) {
                return error
            }

            guard
                store.data.schemaVersion == 8,
                let taskID = store.createWorkItem(
                    themeID: nil,
                    parentWorkItemID: nil,
                    kind: .task,
                    title: "Schema Upgrade Task",
                    body: "",
                    deadlineAt: nil
                )
            else {
                return "Could not create schema 8 test Task."
            }

            guard let plannedStart = ISO8601DateFormatter()
                .date(from: "2026-11-02T08:30:00Z")
            else {
                return "Could not construct Planned Start date."
            }

            let error = store.updateWorkItemDetails(
                itemID: taskID,
                title: "Schema Upgrade Task",
                body: "",
                themeID: nil,
                parentWorkItemID: nil,
                status: .todo,
                deadlineAt: nil,
                reminderAt: nil,
                scheduledAt: nil,
                plannedStartAt: plannedStart,
                plannedStartTimeZoneID: "Europe/Paris"
            )

            if let error {
                return error
            }

            guard store.data.schemaVersion == 9 else {
                return "In-memory schema was not upgraded."
            }

            guard
                let raw = try? Data(
                    contentsOf: fixture.databaseURL
                ),
                let object = try?
                    JSONSerialization.jsonObject(
                        with: raw
                    ) as? [String: Any],
                object["schemaVersion"] as? Int == 9
            else {
                return "Package database was not upgraded."
            }

            let reopened = TestudoStore(
                storageDirectoryURL: root
            )

            guard
                reopened.startupBlockedReason == nil,
                reopened.data.schemaVersion == 9,
                reopened.workItem(id: taskID)?
                    .plannedStartAt == plannedStart,
                reopened.workItem(id: taskID)?
                    .plannedStartTimeZoneID == "Europe/Paris",
                reopened.data.historyEvents.contains(
                    where: {
                        $0.workItemID == taskID
                        && $0.kind == .plannedStartChanged
                    }
                )
            else {
                return "Schema 9 package reload failed."
            }

            return nil
        }

        XCTAssertNil(failure, failure ?? "")

        XCTAssertEqual(
            try Data(contentsOf: fixture.manifestURL),
            originalManifest
        )
    }

    func testFailedPlannedStartSaveRestoresTask() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let fixture = try makePackage(
            in: root,
            name: "PlannedStartSaveFailure"
        )

        _ = try writeRegistry(
            in: root,
            environments: [fixture.environment]
        )

        let failure = await MainActor.run { () -> String? in
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            if let error = store.activateEnvironment(
                id: fixture.id
            ) {
                return error
            }

            guard let taskID = store.createWorkItem(
                themeID: nil,
                parentWorkItemID: nil,
                kind: .task,
                title: "Protected Task",
                body: "",
                deadlineAt: nil
            ) else {
                return "Could not create test Task."
            }

            guard let before = try? Data(
                contentsOf: fixture.databaseURL
            ) else {
                return "Could not read original test database."
            }

            do {
                try FileManager.default.removeItem(
                    at: fixture.manifestURL
                )
            } catch {
                return "Could not simulate manifest failure."
            }

            guard let plannedStart = ISO8601DateFormatter()
                .date(from: "2026-11-02T08:30:00Z")
            else {
                return "Could not construct Planned Start date."
            }

            let error = store.updateWorkItemDetails(
                itemID: taskID,
                title: "Modified Task",
                body: "This edit must be rolled back.",
                themeID: nil,
                parentWorkItemID: nil,
                status: .todo,
                deadlineAt: nil,
                reminderAt: nil,
                scheduledAt: nil,
                plannedStartAt: plannedStart,
                plannedStartTimeZoneID: "Europe/Paris"
            )

            guard
                error == "Could not save Task changes. Existing data was preserved."
            else {
                return "Failed save did not return an error."
            }

            guard
                let task = store.workItem(id: taskID),
                task.title == "Protected Task",
                task.body.isEmpty,
                task.plannedStartAt == nil,
                task.plannedStartTimeZoneID == nil,
                store.data.schemaVersion == 8,
                !store.data.historyEvents.contains(
                    where: {
                        $0.workItemID == taskID
                        && $0.kind == .plannedStartChanged
                    }
                )
            else {
                return "Failed save did not restore in-memory data."
            }

            guard
                let after = try? Data(
                    contentsOf: fixture.databaseURL
                ),
                before == after
            else {
                return "Failed save modified the package database."
            }

            return nil
        }

        XCTAssertNil(failure, failure ?? "")
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

    func testFailedSavePreventsPackageCopy() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let fixture = try makePackage(
            in: root,
            name: "FailedPackageCopy"
        )

        _ = try writeRegistry(
            in: root,
            environments: [fixture.environment]
        )

        let destination = root.appendingPathComponent(
            "CopyAfterFailedSave.testudoenv",
            isDirectory: true
        )

        let result = await MainActor.run {
            () -> (String?, URL, String?) in

            let store = TestudoStore(
                storageDirectoryURL: root
            )

            if let error = store.activateEnvironment(
                id: fixture.id
            ) {
                return (
                    error,
                    store.fileURL,
                    nil
                )
            }

            guard store.createWorkItem(
                themeID: nil,
                parentWorkItemID: nil,
                kind: .task,
                title: "Protected Package Task",
                body: "",
                deadlineAt: nil
            ) != nil
            else {
                return (
                    "Could not create test Task.",
                    store.fileURL,
                    nil
                )
            }

            do {
                try FileManager.default.removeItem(
                    at: fixture.manifestURL
                )
            } catch {
                return (
                    "Could not simulate manifest failure.",
                    store.fileURL,
                    nil
                )
            }

            let error = store.saveWorkEnvironmentAsPackage(
                id: fixture.id,
                destinationURL: destination
            )

            let storagePath = store.applicationData
                .workEnvironments
                .first {
                    $0.id == fixture.id
                }?
                .storage?
                .path

            return (
                error,
                store.fileURL,
                storagePath
            )
        }

        XCTAssertEqual(
            result.0,
            "The current Work Environment could not be saved. Copying was cancelled."
        )

        XCTAssertEqual(
            result.1,
            fixture.databaseURL
        )

        XCTAssertEqual(
            result.2,
            fixture.packageURL.path
        )

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destination.path
            )
        )
    }

    func testFailedSavePreventsEnvironmentSwitchAndPreservesMemory() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(
                at: root
            )
        }

        let first = try makePackage(
            in: root,
            name: "UnsavedChanges"
        )

        let second = try makePackage(
            in: root,
            name: "SwitchDestination"
        )

        let date = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let member = EnvironmentMembership(
            environmentID: first.id,
            localUserProfileID: nil,
            personEntityID: nil,
            directoryUserIdentifier: "fixture-user",
            firstName: "Integration",
            lastName: "Fixture",
            role: .administrator,
            isActive: true,
            createdAt: date,
            lastAccessAt: nil
        )

        var database = TestudoData()
        database.environmentMemberships = [member]

        try writeJSON(
            database,
            to: first.databaseURL
        )

        let credential = EnvironmentCredential(
            membershipID: member.id,
            passwordSaltBase64: "synthetic-salt",
            passwordHashBase64: "synthetic-hash",
            passwordIterations: 1,
            createdAt: date,
            updatedAt: date
        )

        let credentialStore = EnvironmentCredentialStore(
            environmentID: first.id,
            credentials: [credential]
        )

        let credentialsURL =
            first.packageURL.appendingPathComponent(
                "EnvironmentCredentials.json"
            )

        let credentialEncoder = JSONEncoder()

        credentialEncoder.outputFormatting = [
            .sortedKeys
        ]

        let encodedCredentials =
            try credentialEncoder.encode(
                credentialStore
            )

        try encodedCredentials.write(
            to: credentialsURL,
            options: .atomic
        )

        let decodedCredentials =
            try JSONDecoder().decode(
                EnvironmentCredentialStore.self,
                from: Data(contentsOf: credentialsURL)
            )

        XCTAssertEqual(
            decodedCredentials.environmentID,
            first.id
        )

        XCTAssertEqual(
            decodedCredentials.credentials.count,
            1
        )

        XCTAssertEqual(
            decodedCredentials.credentials.first?.membershipID,
            member.id
        )

        var registry = ApplicationData()

        registry.workEnvironments = [
            first.environment,
            second.environment
        ]

        registry.environmentAccesses = [
            EnvironmentAccess(
                environmentID: first.id,
                membershipID: member.id,
                staySignedIn: true,
                lastOpenedAt: nil
            )
        ]

        let registryURL =
            root.appendingPathComponent(
                "ApplicationData.json"
            )

        try writeJSON(
            registry,
            to: registryURL
        )

        let result = try await MainActor.run { () throws -> (
            switchError: String?,
            activeID: UUID?,
            selectedFileURL: URL,
            sessionOpen: Bool,
            unsavedChangePreserved: Bool,
            firstDatabaseUnchanged: Bool,
            secondDatabaseUnchanged: Bool,
            firstManifestUnchanged: Bool,
            secondManifestUnchanged: Bool,
            registryUnchanged: Bool
        ) in
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            guard store.startupBlockedReason == nil else {
                throw NSError(
                    domain: "TestudoActivationTests",
                    code: 10,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The synthetic Store failed startup verification."
                    ]
                )
            }

            let openResult = store.openWorkEnvironment(
                id: first.id
            )

            guard case .opened = openResult else {
                throw NSError(
                    domain: "TestudoActivationTests",
                    code: 11,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The synthetic remembered session did not open."
                    ]
                )
            }

            guard store.environmentSessionIsOpen else {
                throw NSError(
                    domain: "TestudoActivationTests",
                    code: 12,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The Environment session is not open."
                    ]
                )
            }

            guard let themeID = store.createTheme(
                name: "Persisted draft",
                parentThemeID: nil
            ) else {
                throw NSError(
                    domain: "TestudoActivationTests",
                    code: 13,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not create the initial synthetic Theme."
                    ]
                )
            }

            let firstDatabaseBefore = try Data(
                contentsOf: first.databaseURL
            )

            let secondDatabaseBefore = try Data(
                contentsOf: second.databaseURL
            )

            let firstManifestBefore = try Data(
                contentsOf: first.manifestURL
            )

            let secondManifestBefore = try Data(
                contentsOf: second.manifestURL
            )

            let registryBefore = try Data(
                contentsOf: registryURL
            )

            try FileManager.default.setAttributes(
                [
                    .posixPermissions: NSNumber(
                        value: 0o555
                    )
                ],
                ofItemAtPath: first.packageURL.path
            )

            defer {
                try? FileManager.default.setAttributes(
                    [
                        .posixPermissions: NSNumber(
                            value: 0o700
                        )
                    ],
                    ofItemAtPath: first.packageURL.path
                )
            }

            let attributes = try FileManager.default
                .attributesOfItem(
                    atPath: first.packageURL.path
                )

            guard
                let permissions = attributes[
                    .posixPermissions
                ] as? NSNumber,
                permissions.intValue & 0o222 == 0
            else {
                throw NSError(
                    domain: "TestudoActivationTests",
                    code: 15,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The synthetic package is not read-only."
                    ]
                )
            }

            guard let unsavedThemeID = store.createTheme(
                name: "Unsaved theme during switch",
                parentThemeID: nil
            ) else {
                throw NSError(
                    domain: "TestudoActivationTests",
                    code: 16,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not create the unsaved synthetic Theme."
                    ]
                )
            }

            let failedWriteDiskBytes = try Data(
                contentsOf: first.databaseURL
            )

            guard failedWriteDiskBytes == firstDatabaseBefore else {
                throw NSError(
                    domain: "TestudoActivationTests",
                    code: 17,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The filesystem allowed the write. Failure injection was ineffective."
                    ]
                )
            }

            let switchError = store.activateEnvironment(
                id: second.id
            )

            let unsavedChangePreserved =
                store.data.themes.contains {
                    $0.id == unsavedThemeID
                    && $0.name == "Unsaved theme during switch"
                }
                && store.data.themes.contains {
                    $0.id == themeID
                    && $0.name == "Persisted draft"
                }

            return (
                switchError: switchError,
                activeID:
                    store.applicationData.activeEnvironmentID,
                selectedFileURL: store.fileURL,
                sessionOpen: store.environmentSessionIsOpen,
                unsavedChangePreserved:
                    unsavedChangePreserved,
                firstDatabaseUnchanged:
                    try Data(contentsOf: first.databaseURL)
                    == firstDatabaseBefore,
                secondDatabaseUnchanged:
                    try Data(contentsOf: second.databaseURL)
                    == secondDatabaseBefore,
                firstManifestUnchanged:
                    try Data(contentsOf: first.manifestURL)
                    == firstManifestBefore,
                secondManifestUnchanged:
                    try Data(contentsOf: second.manifestURL)
                    == secondManifestBefore,
                registryUnchanged:
                    try Data(contentsOf: registryURL)
                    == registryBefore
            )
        }

        XCTAssertNotNil(result.switchError)

        XCTAssertTrue(
            result.switchError?.contains(
                "Switching was cancelled"
            ) ?? false
        )

        XCTAssertEqual(
            result.activeID,
            first.id
        )

        XCTAssertEqual(
            result.selectedFileURL,
            first.databaseURL
        )

        XCTAssertTrue(result.sessionOpen)

        XCTAssertTrue(result.unsavedChangePreserved)

        XCTAssertTrue(result.firstDatabaseUnchanged)
        XCTAssertTrue(result.secondDatabaseUnchanged)

        XCTAssertTrue(result.firstManifestUnchanged)
        XCTAssertTrue(result.secondManifestUnchanged)

        XCTAssertTrue(result.registryUnchanged)
    }

    func testRegistryWriteFailureCancelsEnvironmentSwitch() async throws {
        let root = try temporaryRoot()

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let first = try makePackage(
            in: root,
            name: "RegistrySource"
        )

        let second = try makePackage(
            in: root,
            name: "RegistryDestination"
        )

        let registryURL = try writeRegistry(
            in: root,
            environments: [
                first.environment,
                second.environment
            ]
        )

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            guard store.startupBlockedReason == nil else {
                throw NSError(
                    domain: "TestudoRegistryIntegrationTests",
                    code: 101,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Synthetic Store startup was blocked."
                    ]
                )
            }

            guard store.activateEnvironment(
                id: first.id
            ) == nil else {
                throw NSError(
                    domain: "TestudoRegistryIntegrationTests",
                    code: 102,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Initial Environment activation failed."
                    ]
                )
            }

            guard let themeID = store.createTheme(
                name: "Registry rollback fixture",
                parentThemeID: nil
            ) else {
                throw NSError(
                    domain: "TestudoRegistryIntegrationTests",
                    code: 103,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not create the synthetic Theme."
                    ]
                )
            }

            let registryBefore = try Data(
                contentsOf: registryURL
            )

            let firstDatabaseBefore = try Data(
                contentsOf: first.databaseURL
            )

            let secondDatabaseBefore = try Data(
                contentsOf: second.databaseURL
            )

            let firstManifestBefore = try Data(
                contentsOf: first.manifestURL
            )

            let secondManifestBefore = try Data(
                contentsOf: second.manifestURL
            )

            try FileManager.default.setAttributes(
                [
                    .posixPermissions: NSNumber(
                        value: 0o555
                    )
                ],
                ofItemAtPath: root.path
            )

            defer {
                try? FileManager.default.setAttributes(
                    [
                        .posixPermissions: NSNumber(
                            value: 0o700
                        )
                    ],
                    ofItemAtPath: root.path
                )
            }

            let attributes = try FileManager.default
                .attributesOfItem(
                    atPath: root.path
                )

            guard
                let permissions =
                    attributes[.posixPermissions] as? NSNumber,
                permissions.intValue & 0o222 == 0
            else {
                throw NSError(
                    domain: "TestudoRegistryIntegrationTests",
                    code: 104,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Registry write restriction was not applied."
                    ]
                )
            }

            let error = store.activateEnvironment(
                id: second.id
            )

            XCTAssertNotNil(error)

            XCTAssertTrue(
                error?.contains(
                    "Switching was cancelled"
                ) ?? false
            )

            XCTAssertEqual(
                store.applicationData.activeEnvironmentID,
                first.id
            )

            XCTAssertEqual(
                store.fileURL,
                first.databaseURL
            )

            XCTAssertTrue(
                store.data.themes.contains {
                    $0.id == themeID
                    && $0.name == "Registry rollback fixture"
                }
            )

            XCTAssertEqual(
                try Data(contentsOf: registryURL),
                registryBefore
            )

            XCTAssertEqual(
                try Data(contentsOf: first.databaseURL),
                firstDatabaseBefore
            )

            XCTAssertEqual(
                try Data(contentsOf: second.databaseURL),
                secondDatabaseBefore
            )

            XCTAssertEqual(
                try Data(contentsOf: first.manifestURL),
                firstManifestBefore
            )

            XCTAssertEqual(
                try Data(contentsOf: second.manifestURL),
                secondManifestBefore
            )
        }
    }
}
