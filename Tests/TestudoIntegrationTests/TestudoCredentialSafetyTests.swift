import Foundation
import XCTest
@testable import Testudo

final class TestudoCredentialSafetyTests: XCTestCase {

    private struct Fixture {
        let root: URL
        let databaseURL: URL
        let environmentID: UUID
        let administratorID: UUID
        let otherMembershipID: UUID
        let credentialsURL: URL
        let originalAdministrator: EnvironmentCredential
        let originalOther: EnvironmentCredential
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

    private func makeFixture() throws -> Fixture {
        let parent = FileManager.default
            .temporaryDirectory
            .standardizedFileURL

        let root = parent.appendingPathComponent(
            "TestudoCredentialSafety-\(UUID().uuidString)",
            isDirectory: true
        )

        guard root.deletingLastPathComponent()
            .standardizedFileURL == parent
        else {
            throw NSError(
                domain: "TestudoCredentialSafetyTests",
                code: 1
            )
        }

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )

        do {
            let environmentID = UUID()
            let date = Date(
                timeIntervalSince1970: 1_700_000_000
            )

            let packageURL = root.appendingPathComponent(
                "CredentialFixture.testudoenv",
                isDirectory: true
            )

            try FileManager.default.createDirectory(
                at: packageURL,
                withIntermediateDirectories: false
            )

            let databaseURL = packageURL.appendingPathComponent(
                "EnvironmentData.json"
            )

            let manifestURL = packageURL.appendingPathComponent(
                "EnvironmentManifest.json"
            )

            let credentialsURL = packageURL.appendingPathComponent(
                "EnvironmentCredentials.json"
            )

            let administrator = EnvironmentMembership(
                environmentID: environmentID,
                localUserProfileID: nil,
                personEntityID: nil,
                directoryUserIdentifier: "fixture-admin",
                firstName: "Synthetic",
                lastName: "Administrator",
                role: .administrator,
                isActive: true,
                createdAt: date,
                lastAccessAt: nil
            )

            let otherMember = EnvironmentMembership(
                environmentID: environmentID,
                localUserProfileID: nil,
                personEntityID: nil,
                directoryUserIdentifier: "fixture-member",
                firstName: "Synthetic",
                lastName: "Member",
                role: .user,
                isActive: true,
                createdAt: date,
                lastAccessAt: nil
            )

            var database = TestudoData()
            database.schemaVersion = 8
            database.environmentMemberships = [
                administrator,
                otherMember
            ]

            try writeJSON(
                database,
                to: databaseURL
            )

            var manifest = EnvironmentManifest(
                environmentID: environmentID,
                name: "Credential Fixture",
                createdAt: date,
                updatedAt: date
            )

            manifest.schemaVersion = 2

            manifest.identityProvider =
                EnvironmentIdentityProviderConfiguration(
                    createdAt: date,
                    updatedAt: date
                )

            try writeJSON(
                manifest,
                to: manifestURL
            )

            let administratorCredential = EnvironmentCredential(
                membershipID: administrator.id,
                passwordSaltBase64: "synthetic-admin-salt",
                passwordHashBase64: "synthetic-admin-hash",
                passwordIterations: 1,
                createdAt: date,
                updatedAt: date
            )

            let otherCredential = EnvironmentCredential(
                membershipID: otherMember.id,
                passwordSaltBase64: "synthetic-member-salt",
                passwordHashBase64: "synthetic-member-hash",
                passwordIterations: 1,
                createdAt: date,
                updatedAt: date
            )

            let credentialStore = EnvironmentCredentialStore(
                environmentID: environmentID,
                credentials: [
                    administratorCredential,
                    otherCredential
                ]
            )

            try JSONEncoder().encode(
                credentialStore
            ).write(
                to: credentialsURL,
                options: .atomic
            )

            var storage = EnvironmentStorageConfiguration()
            storage.kind = .testudoPackage
            storage.displayName = "Credential Fixture"
            storage.path = packageURL.path

            let environment = WorkEnvironment(
                id: environmentID,
                name: "Credential Fixture",
                storage: storage
            )

            var registry = ApplicationData()

            registry.workEnvironments = [
                environment
            ]

            registry.environmentAccesses = [
                EnvironmentAccess(
                    environmentID: environmentID,
                    membershipID: administrator.id,
                    staySignedIn: true,
                    lastOpenedAt: nil
                )
            ]

            try writeJSON(
                registry,
                to: root.appendingPathComponent(
                    "ApplicationData.json"
                )
            )

            return Fixture(
                root: root,
                databaseURL: databaseURL,
                environmentID: environmentID,
                administratorID: administrator.id,
                otherMembershipID: otherMember.id,
                credentialsURL: credentialsURL,
                originalAdministrator: administratorCredential,
                originalOther: otherCredential
            )

        } catch {
            try? FileManager.default.removeItem(
                at: root
            )

            throw error
        }
    }

    func testValidPasswordUpdatePreservesOtherCredentials() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            XCTAssertNil(
                store.startupBlockedReason
            )

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .opened = outcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 2
                )
            }

            XCTAssertTrue(
                store.environmentSessionIsOpen
            )

            XCTAssertTrue(
                store.currentEnvironmentUserIsAdministrator
            )

            let originalDatabase = try Data(
                contentsOf: fixture.databaseURL
            )

            let error = store.setEnvironmentMembershipPassword(
                membershipID: fixture.administratorID,
                newPassword: "SyntheticPassword2026"
            )

            XCTAssertNil(error)

            let resultingData = try Data(
                contentsOf: fixture.credentialsURL
            )

            let resultingStore = try JSONDecoder().decode(
                EnvironmentCredentialStore.self,
                from: resultingData
            )

            XCTAssertEqual(
                resultingStore.environmentID,
                fixture.environmentID
            )

            XCTAssertEqual(
                resultingStore.credentials.count,
                2
            )

            let administrator = resultingStore.credentials.first {
                $0.membershipID == fixture.administratorID
            }

            let other = resultingStore.credentials.first {
                $0.membershipID == fixture.otherMembershipID
            }

            XCTAssertNotNil(administrator)

            XCTAssertNotEqual(
                administrator?.passwordHashBase64,
                fixture.originalAdministrator.passwordHashBase64
            )

            XCTAssertEqual(
                other,
                fixture.originalOther
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.databaseURL),
                originalDatabase
            )
        }
    }

    func testCorruptCredentialFileIsNotReplaced() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            XCTAssertNil(
                store.startupBlockedReason
            )

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .opened = outcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 3
                )
            }

            XCTAssertTrue(
                store.currentEnvironmentUserIsAdministrator
            )

            let corruptBytes = Data(
                "not-valid-credential-json".utf8
            )

            try corruptBytes.write(
                to: fixture.credentialsURL,
                options: .atomic
            )

            let databaseBefore = try Data(
                contentsOf: fixture.databaseURL
            )

            let error = store.setEnvironmentMembershipPassword(
                membershipID: fixture.administratorID,
                newPassword: "SyntheticPassword2026"
            )

            XCTAssertNotNil(error)

            XCTAssertTrue(
                error?.contains(
                    "could not be read safely"
                ) ?? false
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.credentialsURL),
                corruptBytes
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.databaseURL),
                databaseBefore
            )
        }
    }

    func testWrongCredentialEnvironmentIDIsRejected() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            XCTAssertNil(store.startupBlockedReason)

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .opened = outcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 11
                )
            }

            XCTAssertTrue(
                store.currentEnvironmentUserIsAdministrator
            )

            let databaseBefore = try Data(
                contentsOf: fixture.databaseURL
            )

            let manifestURL = fixture.databaseURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )

            let manifestBefore = try Data(
                contentsOf: manifestURL
            )

            var credentials = try JSONDecoder().decode(
                EnvironmentCredentialStore.self,
                from: Data(
                    contentsOf: fixture.credentialsURL
                )
            )

            credentials.environmentID = UUID()

            try JSONEncoder().encode(
                credentials
            ).write(
                to: fixture.credentialsURL,
                options: .atomic
            )

            let invalidCredentials = try Data(
                contentsOf: fixture.credentialsURL
            )

            let error = store.setEnvironmentMembershipPassword(
                membershipID: fixture.administratorID,
                newPassword: "SyntheticPassword2026"
            )

            XCTAssertNotNil(error)

            XCTAssertTrue(
                error?.contains(
                    "incompatible identity or schema"
                ) ?? false
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.credentialsURL),
                invalidCredentials
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.databaseURL),
                databaseBefore
            )

            XCTAssertEqual(
                try Data(contentsOf: manifestURL),
                manifestBefore
            )
        }
    }

    func testFutureCredentialSchemaIsRejected() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            XCTAssertNil(store.startupBlockedReason)

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .opened = outcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 12
                )
            }

            XCTAssertTrue(
                store.currentEnvironmentUserIsAdministrator
            )

            let databaseBefore = try Data(
                contentsOf: fixture.databaseURL
            )

            var credentials = try JSONDecoder().decode(
                EnvironmentCredentialStore.self,
                from: Data(
                    contentsOf: fixture.credentialsURL
                )
            )

            credentials.schemaVersion = 999

            try JSONEncoder().encode(
                credentials
            ).write(
                to: fixture.credentialsURL,
                options: .atomic
            )

            let futureCredentials = try Data(
                contentsOf: fixture.credentialsURL
            )

            let error = store.setEnvironmentMembershipPassword(
                membershipID: fixture.administratorID,
                newPassword: "SyntheticPassword2026"
            )

            XCTAssertNotNil(error)

            XCTAssertTrue(
                error?.contains(
                    "unsupported schema"
                ) ?? false
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.credentialsURL),
                futureCredentials
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.databaseURL),
                databaseBefore
            )
        }
    }

    func testIncompatibleManifestBlocksCredentialChanges() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            XCTAssertNil(store.startupBlockedReason)

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .opened = outcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 13
                )
            }

            XCTAssertTrue(
                store.currentEnvironmentUserIsAdministrator
            )

            let manifestURL = fixture.databaseURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            var manifest = try decoder.decode(
                EnvironmentManifest.self,
                from: Data(
                    contentsOf: manifestURL
                )
            )

            manifest.schemaVersion = 999

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            try encoder.encode(
                manifest
            ).write(
                to: manifestURL,
                options: .atomic
            )

            let invalidManifest = try Data(
                contentsOf: manifestURL
            )

            let credentialsBefore = try Data(
                contentsOf: fixture.credentialsURL
            )

            let databaseBefore = try Data(
                contentsOf: fixture.databaseURL
            )

            let error = store.setEnvironmentMembershipPassword(
                membershipID: fixture.administratorID,
                newPassword: "SyntheticPassword2026"
            )

            XCTAssertNotNil(error)

            XCTAssertTrue(
                error?.contains(
                    "format or identity could not be verified"
                ) ?? false
            )

            XCTAssertEqual(
                try Data(contentsOf: manifestURL),
                invalidManifest
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.credentialsURL),
                credentialsBefore
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.databaseURL),
                databaseBefore
            )
        }
    }

    func testMissingCredentialFileDuringActiveSessionIsNotRecreated() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            XCTAssertNil(
                store.startupBlockedReason
            )

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .opened = outcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 14
                )
            }

            XCTAssertTrue(
                store.environmentSessionIsOpen
            )

            XCTAssertTrue(
                store.currentEnvironmentUserIsAdministrator
            )

            let originalCredentials = try Data(
                contentsOf: fixture.credentialsURL
            )

            let decoded = try JSONDecoder().decode(
                EnvironmentCredentialStore.self,
                from: originalCredentials
            )

            XCTAssertEqual(
                decoded.credentials.count,
                2
            )

            let manifestURL = fixture.databaseURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )

            let databaseBefore = try Data(
                contentsOf: fixture.databaseURL
            )

            let manifestBefore = try Data(
                contentsOf: manifestURL
            )

            let registryURL = fixture.root
                .appendingPathComponent(
                    "ApplicationData.json"
                )

            let registryBefore = try Data(
                contentsOf: registryURL
            )

            try FileManager.default.removeItem(
                at: fixture.credentialsURL
            )

            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: fixture.credentialsURL.path
                )
            )

            let error = store.setEnvironmentMembershipPassword(
                membershipID: fixture.administratorID,
                newPassword: "SyntheticPassword2026"
            )

            XCTAssertNotNil(error)

            XCTAssertTrue(
                error?.contains(
                    "The Environment credential file is missing."
                ) ?? false
            )

            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: fixture.credentialsURL.path
                )
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.databaseURL),
                databaseBefore
            )

            XCTAssertEqual(
                try Data(contentsOf: manifestURL),
                manifestBefore
            )

            XCTAssertEqual(
                try Data(contentsOf: registryURL),
                registryBefore
            )
        }
    }

    func testFirstAdministratorCredentialsPersistAfterEnvironmentCreation() async throws {
        let parent = FileManager.default
            .temporaryDirectory
            .standardizedFileURL

        let root = parent.appendingPathComponent(
            "TestudoFirstAdministrator-\(UUID().uuidString)",
            isDirectory: true
        )

        guard root.deletingLastPathComponent()
            .standardizedFileURL == parent
        else {
            throw NSError(
                domain: "TestudoCredentialSafetyTests",
                code: 21
            )
        }

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )

        defer {
            try? FileManager.default.removeItem(
                at: root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: root
            )

            XCTAssertNil(
                store.startupBlockedReason
            )

            var profile = LocalUserProfile()
            profile.firstName = "Synthetic"
            profile.lastName = "Administrator"

            let profileError = store.saveLocalUserProfile(
                profile
            )

            guard profileError == nil else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 22,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            profileError ?? "Profile initialization failed."
                    ]
                )
            }

            let packageURL = root.appendingPathComponent(
                "FirstAdministrator.testudoenv",
                isDirectory: true
            )

            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: packageURL.path
                )
            )

            let password = "SyntheticFirstAdmin2026"

            let creationError = store.createWorkEnvironment(
                name: "First Administrator Fixture",
                packageURL: packageURL,
                adminUsername: "fixture-admin",
                adminPassword: password
            )

            guard creationError == nil else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 23,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            creationError ?? "Environment creation failed."
                    ]
                )
            }

            XCTAssertTrue(
                store.environmentSessionIsOpen
            )

            XCTAssertTrue(
                store.currentEnvironmentUserIsAdministrator
            )

            guard let environmentID = store.activeEnvironmentID,
                  let membership = store.currentEnvironmentMembership
            else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 24
                )
            }

            XCTAssertEqual(
                membership.environmentID,
                environmentID
            )

            XCTAssertEqual(
                membership.role,
                .administrator
            )

            let databaseURL = packageURL.appendingPathComponent(
                "EnvironmentData.json"
            )

            let manifestURL = packageURL.appendingPathComponent(
                "EnvironmentManifest.json"
            )

            let credentialsURL = packageURL.appendingPathComponent(
                "EnvironmentCredentials.json"
            )

            for url in [
                databaseURL,
                manifestURL,
                credentialsURL
            ] {
                XCTAssertTrue(
                    FileManager.default.fileExists(
                        atPath: url.path
                    )
                )
            }

            let credentialBytes = try Data(
                contentsOf: credentialsURL
            )

            let credentialStore = try JSONDecoder().decode(
                EnvironmentCredentialStore.self,
                from: credentialBytes
            )

            XCTAssertEqual(
                credentialStore.environmentID,
                environmentID
            )

            XCTAssertEqual(
                credentialStore.schemaVersion,
                2
            )

            XCTAssertEqual(
                credentialStore.credentials.count,
                1
            )

            guard let credential = credentialStore
                .credentials.first
            else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 25
                )
            }

            XCTAssertEqual(
                credential.membershipID,
                membership.id
            )

            XCTAssertFalse(
                credential.passwordSaltBase64.isEmpty
            )

            XCTAssertFalse(
                credential.passwordHashBase64.isEmpty
            )

            XCTAssertGreaterThan(
                credential.passwordIterations,
                0
            )

            XCTAssertTrue(
                PasswordHasher.verify(
                    password: password,
                    saltBase64: credential.passwordSaltBase64,
                    expectedHashBase64: credential.passwordHashBase64,
                    iterations: credential.passwordIterations
                )
            )

            XCTAssertTrue(
                store.environmentMembershipHasPassword(
                    id: membership.id
                )
            )

            let reopened = TestudoStore(
                storageDirectoryURL: root
            )

            XCTAssertNil(
                reopened.startupBlockedReason
            )

            let reopenOutcome = reopened.openWorkEnvironment(
                id: environmentID
            )

            guard case .opened = reopenOutcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 26
                )
            }

            XCTAssertTrue(
                reopened.environmentSessionIsOpen
            )

            XCTAssertTrue(
                reopened.currentEnvironmentUserIsAdministrator
            )

            XCTAssertTrue(
                reopened.environmentMembershipHasPassword(
                    id: membership.id
                )
            )

            XCTAssertEqual(
                try Data(contentsOf: credentialsURL),
                credentialBytes
            )
        }
    }

    func testSchemaSevenWithCorruptCredentialsIsNotMigrated() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        let existingDatabase = try Data(
            contentsOf: fixture.databaseURL
        )

        guard var databaseRoot = try JSONSerialization
            .jsonObject(
                with: existingDatabase
            ) as? [String: Any]
        else {
            throw NSError(
                domain: "TestudoCredentialSafetyTests",
                code: 31
            )
        }

        databaseRoot["schemaVersion"] = 7

        databaseRoot["users"] = [
            [
                "id": UUID().uuidString,
                "username": "fixture-admin",
                "passwordSaltBase64": "synthetic-legacy-salt",
                "passwordHashBase64": "synthetic-legacy-hash",
                "passwordIterations": 1
            ]
        ]

        let legacyDatabase = try JSONSerialization.data(
            withJSONObject: databaseRoot,
            options: [.sortedKeys]
        )

        try legacyDatabase.write(
            to: fixture.databaseURL,
            options: .atomic
        )

        let corruptCredentials = Data(
            "intentionally-corrupt-synthetic-credentials".utf8
        )

        try corruptCredentials.write(
            to: fixture.credentialsURL,
            options: .atomic
        )

        let manifestURL = fixture.databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "EnvironmentManifest.json"
            )

        let registryURL = fixture.root
            .appendingPathComponent(
                "ApplicationData.json"
            )

        let manifestBefore = try Data(
            contentsOf: manifestURL
        )

        let registryBefore = try Data(
            contentsOf: registryURL
        )

        await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .failed(let reason) = outcome else {
                XCTFail(
                    "Schema 7 must not be opened or automatically migrated."
                )
                return
            }

            XCTAssertFalse(reason.isEmpty)

            XCTAssertFalse(
                store.environmentSessionIsOpen
            )
        }

        XCTAssertEqual(
            try Data(contentsOf: fixture.databaseURL),
            legacyDatabase
        )

        XCTAssertEqual(
            try Data(contentsOf: fixture.credentialsURL),
            corruptCredentials
        )

        XCTAssertEqual(
            try Data(contentsOf: manifestURL),
            manifestBefore
        )

        XCTAssertEqual(
            try Data(contentsOf: registryURL),
            registryBefore
        )
    }

    func testClosedSessionCannotChangeAdministratorPassword() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            XCTAssertNil(store.startupBlockedReason)

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .opened = outcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 41
                )
            }

            XCTAssertTrue(
                store.environmentSessionIsOpen
            )

            XCTAssertTrue(
                store.currentEnvironmentUserIsAdministrator
            )

            let credentialBytes = try Data(
                contentsOf: fixture.credentialsURL
            )

            let databaseBytes = try Data(
                contentsOf: fixture.databaseURL
            )

            store.closeWorkEnvironment()

            XCTAssertFalse(
                store.environmentSessionIsOpen
            )

            let error = store.setEnvironmentMembershipPassword(
                membershipID: fixture.administratorID,
                newPassword: "SyntheticClosedSessionPassword2026"
            )

            XCTAssertEqual(
                error,
                "An open Work Environment session is required to change Environment membership passwords."
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.credentialsURL),
                credentialBytes
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.databaseURL),
                databaseBytes
            )
        }
    }

    func testMissingCredentialsAfterSessionClosureAreNotRecreated() async throws {
        let fixture = try makeFixture()

        defer {
            try? FileManager.default.removeItem(
                at: fixture.root
            )
        }

        try await MainActor.run { () throws -> Void in
            let store = TestudoStore(
                storageDirectoryURL: fixture.root
            )

            XCTAssertNil(store.startupBlockedReason)

            let outcome = store.openWorkEnvironment(
                id: fixture.environmentID
            )

            guard case .opened = outcome else {
                throw NSError(
                    domain: "TestudoCredentialSafetyTests",
                    code: 42
                )
            }

            XCTAssertTrue(
                store.environmentSessionIsOpen
            )

            let databaseBytes = try Data(
                contentsOf: fixture.databaseURL
            )

            let manifestURL = fixture.databaseURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )

            let manifestBytes = try Data(
                contentsOf: manifestURL
            )

            store.closeWorkEnvironment()

            XCTAssertFalse(
                store.environmentSessionIsOpen
            )

            try FileManager.default.removeItem(
                at: fixture.credentialsURL
            )

            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: fixture.credentialsURL.path
                )
            )

            let error = store.setEnvironmentMembershipPassword(
                membershipID: fixture.administratorID,
                newPassword: "SyntheticClosedSessionPassword2026"
            )

            XCTAssertEqual(
                error,
                "An open Work Environment session is required to change Environment membership passwords."
            )

            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: fixture.credentialsURL.path
                )
            )

            XCTAssertEqual(
                try Data(contentsOf: fixture.databaseURL),
                databaseBytes
            )

            XCTAssertEqual(
                try Data(contentsOf: manifestURL),
                manifestBytes
            )
        }
    }
}
