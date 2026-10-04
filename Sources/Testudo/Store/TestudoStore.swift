import Foundation
import AppKit
import Combine

@MainActor
final class TestudoStore: ObservableObject {
    @Published private(set) var data: TestudoData

    // Application-level state is deliberately independent
    // from the currently loaded Work Environment database.
    @Published
    private(set)
    var applicationData:
        ApplicationData

    // This is intentionally NOT persisted.
    //
    // Opening the application is not the same thing as
    // entering a Work Environment.
    @Published
    private(set)
    var environmentSessionIsOpen:
        Bool = false


    // Application-level authentication is separate from
    // Environment authentication.
    @Published
    private(set)
    var applicationSessionIsOpen:
        Bool = false

    // Temporary legacy Environment database location.
    //
    // In Phase 2B this becomes the backing database of
    // Test Environment and then moves to its own directory.
    private(set)
    var fileURL: URL

    // Local application registry / profile / settings.
    let applicationFileURL:
        URL

    init() {

        TestudoLegacyMigration
            .migrateIfNeeded()

        let fileManager = FileManager.default

        let baseDirectory =
            fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support")

        let directory =
            baseDirectory
                .appendingPathComponent(
                    "Testudo",
                    isDirectory: true
                )

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            print(
                "Testudo: could not create storage directory:",
                error
            )
        }

        fileURL =
            directory
                .appendingPathComponent("TestudoData.json")

        applicationFileURL =
            directory
                .appendingPathComponent(
                    "ApplicationData.json"
                )

        if
            let storedApplicationData =
                try? Data(
                    contentsOf:
                        applicationFileURL
                ),
            let decodedApplicationData =
                Self.decodeApplicationData(
                    storedApplicationData
                )
        {
            applicationData =
                decodedApplicationData
        } else {
            applicationData =
                ApplicationData()
        }


        // Swift requires every stored property to be
        // initialized before `self` can be used.
        //
        // This temporary value is replaced immediately below
        // when the active Environment database is decoded.
        data =
            TestudoData()


        // ----------------------------------------------------
        // Resolve the database belonging to the active
        // Work Environment.
        //
        // Existing installations still have the historical
        // TestudoData.json at the application root. The first
        // Environment migration copies it into:
        //
        //   Testudo/
        //     Environments/
        //       <environment UUID>/
        //         EnvironmentData.json
        //
        // The historical file is intentionally retained as
        // a migration backup.
        // ----------------------------------------------------

        let legacyDataFileURL =
            fileURL

        if
            let activeEnvironmentID =
                applicationData
                    .activeEnvironmentID,
            applicationData
                .workEnvironments
                .contains(
                    where: {
                        $0.id
                            == activeEnvironmentID
                    }
                )
        {
            let environmentsDirectory =
                directory
                    .appendingPathComponent(
                        "Environments",
                        isDirectory:
                            true
                    )

            let activeEnvironmentDirectory =
                environmentsDirectory
                    .appendingPathComponent(
                        activeEnvironmentID
                            .uuidString,
                        isDirectory:
                            true
                    )

            let environmentDataFileURL =
                activeEnvironmentDirectory
                    .appendingPathComponent(
                        "EnvironmentData.json"
                    )

            do {
                try fileManager.createDirectory(
                    at:
                        activeEnvironmentDirectory,
                    withIntermediateDirectories:
                        true
                )

                if
                    !fileManager.fileExists(
                        atPath:
                            environmentDataFileURL
                                .path
                    )
                {
                    if
                        fileManager.fileExists(
                            atPath:
                                legacyDataFileURL
                                    .path
                        )
                    {
                        try fileManager.copyItem(
                            at:
                                legacyDataFileURL,
                            to:
                                environmentDataFileURL
                        )

                        print(
                            "Testudo: migrated legacy database to Environment:",
                            environmentDataFileURL.path
                        )
                    }
                }

                if
                    fileManager.fileExists(
                        atPath:
                            environmentDataFileURL
                                .path
                    )
                {
                    fileURL =
                        environmentDataFileURL
                }

            } catch {
                print(
                    "Testudo: could not prepare Environment database:",
                    error
                )

                // Keep using the historical database rather
                // than risk starting with an empty dataset.
                fileURL =
                    legacyDataFileURL
            }
        }


        do {
            try Self
                .migrateEnvironmentIdentityToSchema8IfNeeded(
                    at:
                        fileURL
                )
        } catch {
            fatalError(
                "Environment schema migration failed: \(error.localizedDescription)"
            )
        }

        if
            let storedData = try? Data(contentsOf: fileURL),
            let decoded = Self.decode(storedData)
        {
            data = decoded
        } else {
            data = TestudoData()
        }

        ensureAllPeopleHaveProfiles()

        // Phase 2A:
        // extract application-owned state from the legacy
        // combined database into ApplicationData.json.

        configureActiveEnvironmentStorageIfNeeded()

        // Phase 2C:
        // move the machine-local identity link out of the
        // portable Environment database.

        ensureEnvironmentManifestIfNeeded()

        removeApplicationMetadataFromEnvironmentDatabaseIfNeeded()

        // Application launch no longer restores a global login.
        //
        // Legacy credentials remain temporarily inside old
        // Environment databases only for Environment entry.
        migrateKnownEnvironmentManifestsIfNeeded()

        environmentSessionIsOpen =
            false

        applicationSessionIsOpen =
            applicationData
                .localUserProfile
                != nil
            && applicationData
                .applicationCredential
                != nil
            && !applicationData
                .applicationIsLoggedOut
    }

    // ========================================================
    // MARK: Legacy schema 6 -> Work Environment schema 7
    // ========================================================

    // ========================================================
    // MARK: Combined database -> application registry
    // ========================================================

    // ========================================================
    // MARK: Application / Environment context
    // ========================================================

    var localUserProfile:
        LocalUserProfile?
    {
        applicationData
            .localUserProfile
    }


    var workEnvironments:
        [WorkEnvironment]
    {
        applicationData
            .workEnvironments
    }


    var activeEnvironmentID:
        UUID?
    {
        applicationData
            .activeEnvironmentID
    }


    var activeWorkEnvironment:
        WorkEnvironment?
    {
        guard
            let activeEnvironmentID
        else {
            return nil
        }

        return
            applicationData
                .workEnvironments
                .first {
                    $0.id
                        == activeEnvironmentID
                }
    }


    var currentEnvironmentMembership:
        EnvironmentMembership?
    {
        guard
            let environmentID =
                activeEnvironmentID,
            let membershipID =
                applicationData
                    .environmentAccesses
                    .first(
                        where: {
                            $0.environmentID
                                == environmentID
                        }
                    )?
                    .membershipID
        else {
            return nil
        }

        return
            data.environmentMemberships
                .first {
                    $0.id
                        == membershipID
                    && $0.environmentID
                        == environmentID
                }
    }


    var currentEnvironmentRole:
        EnvironmentRole?
    {
        currentEnvironmentMembership?
            .role
    }


    var currentEnvironmentUserIsAdministrator:
        Bool
    {
        currentEnvironmentRole
            == .administrator
    }


    // ========================================================
    // MARK: Local identity ↔ Environment identity
    // ========================================================

    private func ensureEnvironmentManifestIfNeeded() {
        guard
            let environment =
                activeWorkEnvironment,
            fileURL.lastPathComponent
                == "EnvironmentData.json"
        else {
            return
        }


        let manifestURL =
            fileURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )


        let manifest =
            EnvironmentManifest(
                schemaVersion:
                    1,
                environmentID:
                    environment.id,
                name:
                    environment.name,
                createdAt:
                    environment.createdAt,
                updatedAt:
                    environment.updatedAt
            )


        let encoder =
            JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        encoder.dateEncodingStrategy =
            .iso8601


        do {
            let encoded =
                try encoder.encode(
                    manifest
                )

            // Rewrite as well as create, so the manifest follows
            // future Environment renames.
            try encoded.write(
                to:
                    manifestURL,
                options:
                    .atomic
            )
        } catch {
            print(
                "Testudo: could not write Environment manifest:",
                error
            )
        }
    }


    // ========================================================
    // MARK: Application user profile
    // ========================================================

    @discardableResult
    func saveLocalUserProfile(
        _ profile:
            LocalUserProfile
    ) -> String? {
        var profile =
            profile

        profile.firstName =
            profile.firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        profile.middleName =
            profile.middleName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        profile.lastName =
            profile.lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        profile.preferredName =
            profile.preferredName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !profile.firstName.isEmpty
        else {
            return
                "First name is required."
        }


        guard
            !profile.lastName.isEmpty
        else {
            return
                "Last name is required."
        }


        let now =
            Date()

        if
            let existing =
                applicationData
                    .localUserProfile
        {
            profile.id =
                existing.id

            profile.createdAt =
                existing.createdAt
        } else {
            profile.createdAt =
                now
        }

        profile.updatedAt =
            now


        applicationData
            .localUserProfile =
            profile

        saveApplicationData()

        return nil
    }


    // ========================================================
    // MARK: Work Environment creation
    // ========================================================

    @discardableResult
    func createWorkEnvironment(
        name:
            String,
        packageURL:
            URL,
        adminUsername:
            String,
        adminPassword:
            String
    ) -> String? {

        guard
            let localProfile =
                applicationData
                    .localUserProfile
        else {
            return
                "Create your application profile first."
        }


        let cleanedName =
            name.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )


        let cleanedAdminUsername =
            adminUsername
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanedAdminPassword =
            adminPassword


        guard
            !cleanedAdminUsername.isEmpty
        else {
            return
                "Administrator username is required."
        }


        guard
            !cleanedAdminPassword.isEmpty
        else {
            return
                "Administrator password is required."
        }


        guard !cleanedName.isEmpty else {
            return
                "Environment name is required."
        }


        let destinationURL =
            TestudoEnvironmentPackage
                .normalizedURL(
                    packageURL
                )


        guard
            destinationURL
                .pathExtension
                .caseInsensitiveCompare(
                    TestudoEnvironmentPackage
                        .filenameExtension
                )
                == .orderedSame
        else {
            return
                "A Work Environment must be stored as a .testudoenv package."
        }


        guard
            !FileManager.default
                .fileExists(
                    atPath:
                        destinationURL.path
                )
        else {
            return
                "A file or Work Environment already exists at that location."
        }


        let duplicate =
            applicationData
                .workEnvironments
                .contains {
                    $0.name
                        .caseInsensitiveCompare(
                            cleanedName
                        )
                        == .orderedSame
                }


        guard !duplicate else {
            return
                "A Work Environment with that name already exists."
        }


        let environmentID =
            UUID()

        let now =
            Date()


        let dataURL =
            destinationURL
                .appendingPathComponent(
                    "EnvironmentData.json"
                )

        let manifestURL =
            destinationURL
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )

        let credentialsURL =
            destinationURL
                .appendingPathComponent(
                    "EnvironmentCredentials.json"
                )


        let membership =
            EnvironmentMembership(
                environmentID:
                    environmentID,
                localUserProfileID:
                    nil,
                personEntityID:
                    nil,
                directoryUserIdentifier:
                    cleanedAdminUsername,
                firstName:
                    localProfile.firstName,
                lastName:
                    localProfile.lastName,
                role:
                    .administrator,
                isActive:
                    true,
                createdAt:
                    now,
                lastAccessAt:
                    now
            )


        var newData =
            TestudoData()

        newData.schemaVersion =
            max(
                newData.schemaVersion,
                8
            )

        newData
            .environmentMemberships =
            [
                membership
            ]


        let identityProvider =
            EnvironmentIdentityProviderConfiguration(
                kind:
                    .localAccounts,
                displayName:
                    "Local Environment Accounts",
                createdAt:
                    now,
                updatedAt:
                    now
            )


        let manifest =
            EnvironmentManifest(
                schemaVersion:
                    2,
                environmentID:
                    environmentID,
                name:
                    cleanedName,
                identityProvider:
                    identityProvider,
                createdAt:
                    now,
                updatedAt:
                    now
            )


        let credentialStore =
            EnvironmentCredentialStore(
                environmentID:
                    environmentID
            )


        let encoder =
            JSONEncoder()

        encoder.outputFormatting =
            [
                .prettyPrinted,
                .sortedKeys
            ]

        encoder.dateEncodingStrategy =
            .iso8601


        do {
            try FileManager.default
                .createDirectory(
                    at:
                        destinationURL,
                    withIntermediateDirectories:
                        false
                )


            try encoder
                .encode(
                    newData
                )
                .write(
                    to:
                        dataURL,
                    options:
                        .atomic
                )


            try encoder
                .encode(
                    manifest
                )
                .write(
                    to:
                        manifestURL,
                    options:
                        .atomic
                )


            try encoder
                .encode(
                    credentialStore
                )
                .write(
                    to:
                        credentialsURL,
                    options:
                        .atomic
                )

        } catch {

            try? FileManager.default
                .removeItem(
                    at:
                        destinationURL
                )

            return
                "The Work Environment could not be created: \(error.localizedDescription)"
        }


        _ =
            destinationURL
                .startAccessingSecurityScopedResource()


        let storage =
            EnvironmentStorageConfiguration(
                kind:
                    .testudoPackage,
                displayName:
                    destinationURL
                        .lastPathComponent,
                path:
                    destinationURL.path,
                bookmarkData:
                    Self
                        .securityScopedBookmarkData(
                            for:
                                destinationURL
                        ),
                createdAt:
                    now,
                updatedAt:
                    now,
                lastConnectedAt:
                    now
            )


        let environment =
            WorkEnvironment(
                id:
                    environmentID,
                name:
                    cleanedName,
                storage:
                    storage,
                identityProvider:
                    identityProvider,
                createdAt:
                    now,
                updatedAt:
                    now
            )


        applicationData
            .workEnvironments
            .append(
                environment
            )


        applicationData
            .environmentAccesses
            .append(
                EnvironmentAccess(
                    environmentID:
                        environmentID,
                    membershipID:
                        membership.id,
                    staySignedIn:
                        true,
                    lastOpenedAt:
                        now
                )
            )


        applicationData
            .activeEnvironmentID =
            environmentID


        fileURL =
            dataURL

        data =
            newData

        environmentSessionIsOpen =
            true


        saveApplicationData()


        if
            let passwordError =
                setEnvironmentMembershipPassword(
                    membershipID:
                        membership.id,
                    newPassword:
                        cleanedAdminPassword
                )
        {
            return
                "The Work Environment was created, but its administrator password could not be saved: \(passwordError)"
        }



        return nil
    }


    // ========================================================
    // MARK: Register Environment from a storage folder
    // ========================================================

    func registerWorkEnvironment(
        from packageURL:
            URL
    ) -> (
        environmentID:
            UUID?,
        error:
            String?
    ) {

        let packageURL =
            packageURL
                .standardizedFileURL


        guard
            packageURL
                .pathExtension
                .caseInsensitiveCompare(
                    TestudoEnvironmentPackage
                        .filenameExtension
                )
                == .orderedSame
        else {
            return (
                nil,
                "Select a Testudo Work Environment (.testudoenv)."
            )
        }


        _ =
            packageURL
                .startAccessingSecurityScopedResource()


        let manifestURL =
            packageURL
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )

        let dataURL =
            packageURL
                .appendingPathComponent(
                    "EnvironmentData.json"
                )


        guard
            FileManager.default
                .fileExists(
                    atPath:
                        manifestURL.path
                )
        else {
            return (
                nil,
                "This package does not contain EnvironmentManifest.json."
            )
        }


        guard
            FileManager.default
                .fileExists(
                    atPath:
                        dataURL.path
                )
        else {
            return (
                nil,
                "This package does not contain EnvironmentData.json."
            )
        }


        do {
            try Self
                .migrateEnvironmentIdentityToSchema8IfNeeded(
                    at:
                        dataURL
                )
        } catch {
            return (
                nil,
                "The Environment database could not be migrated: \(error.localizedDescription)"
            )
        }


        let manifestDecoder =
            JSONDecoder()

        manifestDecoder.dateDecodingStrategy =
            .iso8601


        let manifest:
            EnvironmentManifest


        do {
            manifest =
                try manifestDecoder.decode(
                    EnvironmentManifest.self,
                    from:
                        Data(
                            contentsOf:
                                manifestURL
                        )
                )

        } catch {
            return (
                nil,
                "The Environment manifest could not be read."
            )
        }


        guard
            let environmentRawData =
                try? Data(
                    contentsOf:
                        dataURL
                ),
            let environmentData =
                Self.decode(
                    environmentRawData
                )
        else {
            return (
                nil,
                "The Environment database could not be read."
            )
        }


        let invalidMembership =
            environmentData
                .environmentMemberships
                .contains {
                    $0.environmentID
                        != manifest.environmentID
                }


        guard !invalidMembership else {
            return (
                nil,
                "The Environment database does not match its manifest."
            )
        }


        let now =
            Date()


        let identityProvider =
            manifest.identityProvider
            ?? EnvironmentIdentityProviderConfiguration(
                kind:
                    .localAccounts,
                displayName:
                    "Local Environment Accounts",
                createdAt:
                    manifest.createdAt,
                updatedAt:
                    now
            )


        let storage =
            EnvironmentStorageConfiguration(
                kind:
                    .testudoPackage,
                displayName:
                    packageURL
                        .lastPathComponent,
                path:
                    packageURL.path,
                bookmarkData:
                    Self
                        .securityScopedBookmarkData(
                            for:
                                packageURL
                        ),
                createdAt:
                    manifest.createdAt,
                updatedAt:
                    now,
                lastConnectedAt:
                    now
            )


        if
            let index =
                applicationData
                    .workEnvironments
                    .firstIndex(
                        where: {
                            $0.id
                                == manifest.environmentID
                        }
                    )
        {
            applicationData
                .workEnvironments[index]
                .name =
                manifest.name

            applicationData
                .workEnvironments[index]
                .storage =
                storage

            applicationData
                .workEnvironments[index]
                .identityProvider =
                identityProvider

            applicationData
                .workEnvironments[index]
                .updatedAt =
                now

        } else {

            applicationData
                .workEnvironments
                .append(
                    WorkEnvironment(
                        id:
                            manifest.environmentID,
                        name:
                            manifest.name,
                        storage:
                            storage,
                        identityProvider:
                            identityProvider,
                        createdAt:
                            manifest.createdAt,
                        updatedAt:
                            manifest.updatedAt
                    )
                )
        }


        applicationData
            .activeEnvironmentID =
            manifest.environmentID


        saveApplicationData()

        migrateKnownEnvironmentManifestsIfNeeded()


        return (
            manifest.environmentID,
            nil
        )
    }


    // ========================================================
    // MARK: Environment entry
    // ========================================================

    var activeEnvironmentMemberships:
        [EnvironmentMembership]
    {
        guard
            let environmentID =
                activeEnvironmentID
        else {
            return []
        }

        return
            data.environmentMemberships
                .filter {
                    $0.environmentID
                        == environmentID
                    && $0.isActive
                }
                .sorted {
                    $0.displayName
                        .localizedCaseInsensitiveCompare(
                            $1.displayName
                        )
                        == .orderedAscending
                }
    }


    var environmentMembershipsForActiveEnvironment:
        [EnvironmentMembership]
    {
        guard
            let environmentID =
                activeEnvironmentID
        else {
            return []
        }

        return
            data.environmentMemberships
                .filter {
                    $0.environmentID
                        == environmentID
                }
                .sorted {
                    $0.displayName
                        .localizedCaseInsensitiveCompare(
                            $1.displayName
                        )
                        == .orderedAscending
                }
    }


    func environmentMembership(
        id membershipID:
            UUID
    ) -> EnvironmentMembership? {
        guard
            let environmentID =
                activeEnvironmentID
        else {
            return nil
        }

        return
            data.environmentMemberships
                .first {
                    $0.id
                        == membershipID
                    && $0.environmentID
                        == environmentID
                }
    }


    @discardableResult
    func updateEnvironmentMembership(
        membershipID:
            UUID,
        firstName:
            String,
        lastName:
            String,
        directoryUserIdentifier:
            String,
        personEntityID:
            UUID?,
        role:
            EnvironmentRole,
        isActive:
            Bool
    ) -> String? {
        guard
            currentEnvironmentUserIsAdministrator
        else {
            return
                "Environment Administrator rights are required."
        }

        guard
            let environmentID =
                activeEnvironmentID,
            let index =
                data.environmentMemberships
                    .firstIndex(
                        where: {
                            $0.id
                                == membershipID
                            && $0.environmentID
                                == environmentID
                        }
                    )
        else {
            return
                "Environment membership not found."
        }

        let cleanedFirstName =
            firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanedLastName =
            lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanedDirectoryIdentifier =
            directoryUserIdentifier
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !cleanedDirectoryIdentifier.isEmpty
        else {
            return
                "Username is required."
        }


        if !cleanedDirectoryIdentifier.isEmpty {
            let duplicateIdentifier =
                data.environmentMemberships
                    .contains {
                        guard
                            $0.environmentID
                                == environmentID,
                            $0.id
                                != membershipID,
                            let existingIdentifier =
                                $0.directoryUserIdentifier
                        else {
                            return false
                        }

                        return
                            existingIdentifier
                                .caseInsensitiveCompare(
                                    cleanedDirectoryIdentifier
                                )
                                == .orderedSame
                    }

            guard
                !duplicateIdentifier
            else {
                return
                    "That username is already used by another Environment membership."
            }
        }


        var linkedPerson:
            Entity?

        if let personEntityID {
            guard
                let person =
                    data.entities.first(
                        where: {
                            $0.id
                                == personEntityID
                            && $0.kind
                                == .person
                        }
                    )
            else {
                return
                    "The selected Person no longer exists."
            }

            let alreadyLinkedElsewhere =
                data.environmentMemberships
                    .contains {
                        $0.environmentID
                            == environmentID
                        && $0.id
                            != membershipID
                        && $0.personEntityID
                            == personEntityID
                    }

            guard
                !alreadyLinkedElsewhere
            else {
                return
                    "That Person is already linked to another Environment membership."
            }

            linkedPerson =
                person
        }


        let currentMembershipID =
            currentEnvironmentMembership?
                .id

        if
            membershipID
                == currentMembershipID,
            !isActive
        {
            return
                "You cannot deactivate the Environment membership currently in use."
        }

        let existing =
            data.environmentMemberships[
                index
            ]

        let removesActiveAdministrator =
            existing.isActive
            && existing.role
                == .administrator
            && (
                !isActive
                || role != .administrator
            )

        if removesActiveAdministrator {
            let otherActiveAdministrators =
                data.environmentMemberships
                    .filter {
                        $0.environmentID
                            == environmentID
                        && $0.id
                            != membershipID
                        && $0.isActive
                        && $0.role
                            == .administrator
                    }

            guard
                !otherActiveAdministrators
                    .isEmpty
            else {
                return
                    "The last active Environment Administrator cannot be deactivated or changed to User."
            }
        }

        data.environmentMemberships[
            index
        ].personEntityID =
            personEntityID

        data.environmentMemberships[
            index
        ].directoryUserIdentifier =
            cleanedDirectoryIdentifier.isEmpty
            ? nil
            : cleanedDirectoryIdentifier


        if let linkedPerson {
            if
                let profile =
                    data.personProfiles.first(
                        where: {
                            $0.entityID
                                == linkedPerson.id
                        }
                    )
            {
                let first =
                    profile.firstName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                let last =
                    profile.lastName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                if
                    !first.isEmpty
                    || !last.isEmpty
                {
                    data.environmentMemberships[
                        index
                    ].firstName =
                        first

                    data.environmentMemberships[
                        index
                    ].lastName =
                        last

                } else {
                    data.environmentMemberships[
                        index
                    ].firstName =
                        linkedPerson.name

                    data.environmentMemberships[
                        index
                    ].lastName =
                        ""
                }

            } else {
                data.environmentMemberships[
                    index
                ].firstName =
                    linkedPerson.name

                data.environmentMemberships[
                    index
                ].lastName =
                    ""
            }

        } else {
            guard
                !cleanedFirstName.isEmpty
                || !cleanedLastName.isEmpty
            else {
                return
                    "A member name is required when no Person is linked."
            }

            data.environmentMemberships[
                index
            ].firstName =
                cleanedFirstName

            data.environmentMemberships[
                index
            ].lastName =
                cleanedLastName
        }


        data.environmentMemberships[
            index
        ].role =
            role

        data.environmentMemberships[
            index
        ].isActive =
            isActive

        save()

        return nil
    }



    func environmentMembershipNeedsPassword(
        id membershipID:
            UUID
    ) -> Bool {
        environmentMembershipHasPassword(
            id:
                membershipID
        )
    }


    @discardableResult
    func openWorkEnvironment(
        id environmentID:
            UUID
    ) -> EnvironmentOpenOutcome {

        if
            let error =
                activateEnvironment(
                    id:
                        environmentID
                )
        {
            return
                .failed(
                    error
                )
        }


        if
            openManagedDemoEnvironmentSessionIfAvailable(
                environmentID:
                    environmentID
            )
        {
            return
                .opened
        }


        guard
            let access =
                applicationData
                    .environmentAccesses
                    .first(
                        where: {
                            $0.environmentID
                                == environmentID
                        }
                    ),
            access.staySignedIn
                == true,
            let membershipID =
                access.membershipID,
            let membership =
                data.environmentMemberships
                    .first(
                        where: {
                            $0.id
                                == membershipID
                            && $0.environmentID
                                == environmentID
                            && $0.isActive
                        }
                    ),
            let username =
                membership
                    .directoryUserIdentifier?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !username.isEmpty,
            environmentCredential(
                for:
                    membership.id
            ) != nil
        else {
            environmentSessionIsOpen =
                false

            return
                .identityRequired
        }


        let now =
            Date()


        if
            let accessIndex =
                applicationData
                    .environmentAccesses
                    .firstIndex(
                        where: {
                            $0.environmentID
                                == environmentID
                        }
                    )
        {
            applicationData
                .environmentAccesses[
                    accessIndex
                ]
                .lastOpenedAt =
                now
        }


        if
            let membershipIndex =
                data.environmentMemberships
                    .firstIndex(
                        where: {
                            $0.id
                                == membership.id
                        }
                    )
        {
            data.environmentMemberships[
                membershipIndex
            ]
            .lastAccessAt =
                now

            save()
        }


        saveApplicationData()


        environmentSessionIsOpen =
            true


        return
            .opened
    }


    @discardableResult
    func enterActiveEnvironment(
        username:
            String,
        password:
            String,
        staySignedIn:
            Bool
    ) -> String? {

        guard
            let environmentID =
                activeEnvironmentID
        else {
            return
                "No Work Environment is active."
        }


        let cleanedUsername =
            username
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanedPassword =
            password


        guard
            !cleanedUsername.isEmpty,
            !cleanedPassword.isEmpty
        else {
            return
                "Username and password are required."
        }


        guard
            let membership =
                data.environmentMemberships
                    .first(
                        where: {
                            guard
                                $0.environmentID
                                    == environmentID,
                                $0.isActive,
                                let identifier =
                                    $0.directoryUserIdentifier?
                                        .trimmingCharacters(
                                            in:
                                                .whitespacesAndNewlines
                                        ),
                                !identifier.isEmpty
                            else {
                                return false
                            }

                            return
                                identifier
                                    .caseInsensitiveCompare(
                                        cleanedUsername
                                    )
                                    == .orderedSame
                        }
                    )
        else {
            return
                "Incorrect username or password."
        }


        guard
            let credential =
                environmentCredential(
                    for:
                        membership.id
                )
        else {
            return
                "This Environment account does not have a password. Ask an Environment Administrator to configure its login credentials."
        }


        guard
            PasswordHasher.verify(
                password:
                    cleanedPassword,
                saltBase64:
                    credential
                        .passwordSaltBase64,
                expectedHashBase64:
                    credential
                        .passwordHashBase64,
                iterations:
                    credential
                        .passwordIterations
            )
        else {
            return
                "Incorrect username or password."
        }


        let now =
            Date()


        if
            let index =
                applicationData
                    .environmentAccesses
                    .firstIndex(
                        where: {
                            $0.environmentID
                                == environmentID
                        }
                    )
        {
            applicationData
                .environmentAccesses[
                    index
                ]
                .membershipID =
                membership.id

            applicationData
                .environmentAccesses[
                    index
                ]
                .staySignedIn =
                staySignedIn

            applicationData
                .environmentAccesses[
                    index
                ]
                .lastOpenedAt =
                now

        } else {

            applicationData
                .environmentAccesses
                .append(
                    EnvironmentAccess(
                        environmentID:
                            environmentID,
                        membershipID:
                            membership.id,
                        staySignedIn:
                            staySignedIn,
                        lastOpenedAt:
                            now
                    )
                )
        }


        if
            let membershipIndex =
                data.environmentMemberships
                    .firstIndex(
                        where: {
                            $0.id
                                == membership.id
                        }
                    )
        {
            data.environmentMemberships[
                membershipIndex
            ]
            .lastAccessAt =
                now

            save()
        }


        saveApplicationData()


        environmentSessionIsOpen =
            true


        return nil
    }


    func closeWorkEnvironment() {

        // Deliberately preserve EnvironmentAccess.
        //
        // If Stay signed in is enabled, selecting this Environment
        // again can immediately reopen it.
        environmentSessionIsOpen =
            false
    }


    func signOutActiveEnvironment() {

        if environmentSessionIsOpen {
            save()
        }


        if
            let environmentID =
                activeEnvironmentID,
            let accessIndex =
                applicationData
                    .environmentAccesses
                    .firstIndex(
                        where: {
                            $0.environmentID
                                == environmentID
                        }
                    )
        {
            applicationData
                .environmentAccesses[
                    accessIndex
                ]
                .membershipID =
                nil

            applicationData
                .environmentAccesses[
                    accessIndex
                ]
                .staySignedIn =
                false
        }


        environmentSessionIsOpen =
            false

        saveApplicationData()
    }


    // ========================================================
    // MARK: Environment database storage
    // ========================================================

    private func managedEnvironmentDirectoryURL(
        for environmentID:
            UUID
    ) -> URL {
        applicationFileURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Environments",
                isDirectory:
                    true
            )
            .appendingPathComponent(
                environmentID
                    .uuidString,
                isDirectory:
                    true
            )
    }


    private func environmentDataURL(
        for environment:
            WorkEnvironment
    ) -> URL? {

        guard
            let packageURL =
                resolvedStorageURL(
                    for:
                        environment
                )
        else {
            return nil
        }


        return
            packageURL
                .appendingPathComponent(
                    "EnvironmentData.json"
                )
    }


    private func configureActiveEnvironmentStorageIfNeeded() {
        guard
            fileURL.lastPathComponent
                == "EnvironmentData.json",
            let environmentID =
                applicationData
                    .activeEnvironmentID,
            let index =
                applicationData
                    .workEnvironments
                    .firstIndex(
                        where: {
                            $0.id
                                == environmentID
                        }
                    )
        else {
            return
        }


        // ApplicationData schema 2 -> 3.
        //
        // WorkEnvironment's custom decoder has already translated
        // the legacy JSON key "directory" into "storage".
        // Saving now permanently writes the new representation.
        if applicationData.schemaVersion < 3 {
            applicationData.schemaVersion =
                3

            saveApplicationData()
        }

        migrateActiveEnvironmentManifestIdentityIfNeeded()


        let environmentDirectory =
            fileURL
                .deletingLastPathComponent()


        let existingPath =
            applicationData
                .workEnvironments[index]
                .storage?
                .path?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            existingPath == nil
            || existingPath?.isEmpty
                == true
        else {
            return
        }


        let environmentName =
            applicationData
                .workEnvironments[index]
                .name


        applicationData
            .workEnvironments[index]
            .storage =
            EnvironmentStorageConfiguration(
                kind:
                    .localFolder,
                displayName:
                    environmentName,
                path:
                    environmentDirectory.path,
                bookmarkData:
                    nil,
                createdAt:
                    Date(),
                updatedAt:
                    Date(),
                lastConnectedAt:
                    Date()
            )


        applicationData
            .workEnvironments[index]
            .updatedAt =
            Date()


        saveApplicationData()
    }


    private func removeApplicationMetadataFromEnvironmentDatabaseIfNeeded() {
        guard
            fileURL.lastPathComponent
                == "EnvironmentData.json"
        else {
            return
        }


        let containsApplicationMetadata =
            data.localUserProfile != nil
            || !data.workEnvironments.isEmpty
            || data.activeEnvironmentID != nil


        guard containsApplicationMetadata else {
            return
        }


        // These values now live exclusively in
        // ApplicationData.json.
        data.localUserProfile =
            nil

        data.workEnvironments =
            []

        data.activeEnvironmentID =
            nil


        save()
    }


    // ========================================================
    // MARK: Environment switching
    //
    // No UI invokes this yet.
    //
    // The Environment chooser introduced later will call this
    // after resolving the user's membership / authentication.
    // ========================================================

    @discardableResult
    func activateEnvironment(
        id environmentID:
            UUID
    ) -> String? {
        guard
            let environment =
                applicationData
                    .workEnvironments
                    .first(
                        where: {
                            $0.id
                                == environmentID
                        }
                    )
        else {
            return
                "Work Environment not found."
        }


        guard
            let targetURL =
                environmentDataURL(
                    for:
                        environment
                )
        else {
            return
                "This Work Environment has no registered storage location. Open its .testudoenv package again."
        }


        guard
            FileManager.default
                .fileExists(
                    atPath:
                        targetURL.path
                )
        else {
            return
                "The Work Environment database could not be found."
        }


        guard
            let rawData =
                try? Data(
                    contentsOf:
                        targetURL
                ),
            let decoded =
                Self.decode(
                    rawData
                )
        else {
            return
                "The Work Environment database could not be read."
        }


        // Persist only a genuinely open Environment.
        //
        // A Work Environment may have been removed from this
        // installation while its package remains safely on disk.
        if environmentSessionIsOpen {
            save()
        }


        fileURL =
            targetURL

        data =
            decoded


        applicationData
            .activeEnvironmentID =
            environmentID


        if
            let accessIndex =
                applicationData
                    .environmentAccesses
                    .firstIndex(
                        where: {
                            $0.environmentID
                                == environmentID
                        }
                    )
        {
            applicationData
                .environmentAccesses[accessIndex]
                .lastOpenedAt =
                Date()
        }


        saveApplicationData()


        ensureAllPeopleHaveProfiles()

        ensureEnvironmentManifestIfNeeded()

        removeApplicationMetadataFromEnvironmentDatabaseIfNeeded()


        return nil
    }


    private static func decodeApplicationData(
        _ rawData:
            Data
    ) -> ApplicationData? {
        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601

        do {
            return
                try decoder.decode(
                    ApplicationData.self,
                    from:
                        rawData
                )
        } catch {
            print(
                "Testudo: could not decode application data:",
                error
            )

            return nil
        }
    }


    private static func decode(
        _ rawData: Data
    ) -> TestudoData? {
        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601

        do {
            var decoded =
                try decoder.decode(
                    TestudoData.self,
                    from:
                        rawData
                )

            // -----------------------------------------------
            // Legacy Closed archive migration
            //
            // Testudo <= 0.1.6 represented archival state as
            // TaskStatus.closed.
            //
            // Current Testudo preserves the real workflow
            // status and stores archival state independently
            // in closedAt.
            // -----------------------------------------------

            for index in
                decoded.workItems.indices
            {
                guard
                    decoded.workItems[index].kind
                        == .task,
                    decoded.workItems[index].status
                        == .closed
                else {
                    continue
                }

                let itemID =
                    decoded.workItems[index].id

                let legacyCloseEvent =
                    decoded.historyEvents
                        .filter {
                            $0.workItemID
                                == itemID
                            && $0.newValue
                                == TaskStatus.closed.rawValue
                        }
                        .max {
                            $0.timestamp
                                < $1.timestamp
                        }

                let closedAt =
                    legacyCloseEvent?
                        .timestamp
                    ?? decoded.workItems[index]
                        .updatedAt

                let closedTimeZoneID =
                    legacyCloseEvent?
                        .timeZoneID
                    ?? decoded.workItems[index]
                        .updatedTimeZoneID

                let previousStatus =
                    legacyCloseEvent?
                        .previousValue
                        .flatMap {
                            TaskStatus(
                                rawValue:
                                    $0
                            )
                        }

                if
                    let previousStatus,
                    previousStatus
                        != .closed
                {
                    decoded.workItems[index]
                        .status =
                        previousStatus

                } else if
                    decoded.workItems[index]
                        .discontinuedAt != nil
                {
                    decoded.workItems[index]
                        .status =
                        .discontinued

                } else {
                    decoded.workItems[index]
                        .status =
                        .completed
                }

                // Closed is valid only on the root Task.
                if
                    decoded.workItems[index]
                        .parentWorkItemID == nil
                {
                    decoded.workItems[index]
                        .closedAt =
                        closedAt

                    decoded.workItems[index]
                        .closedTimeZoneID =
                        closedTimeZoneID
                }
            }

            // Existing "Status changed to Closed" records
            // become archive-lifecycle records. We retain their
            // original timestamps and old/new values.
            for index in
                decoded.historyEvents.indices
            {
                if
                    decoded.historyEvents[index]
                        .kind
                        == .statusChanged,
                    decoded.historyEvents[index]
                        .newValue
                        == TaskStatus.closed.rawValue
                {
                    decoded.historyEvents[index]
                        .kind =
                        .closed

                    decoded.historyEvents[index]
                        .text =
                        "Task closed and moved to Archive"
                }
            }

            return decoded

        } catch {
            print(
                "Testudo: could not decode stored data:",
                error
            )

            return nil
        }
    }


    private func saveApplicationData() {
        let encoder =
            JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        encoder.dateEncodingStrategy =
            .iso8601

        do {
            let encoded =
                try encoder.encode(
                    applicationData
                )

            try encoded.write(
                to:
                    applicationFileURL,
                options:
                    .atomic
            )
        } catch {
            print(
                "Testudo: could not save application data:",
                error
            )
        }
    }


    private func save() {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        encoder.dateEncodingStrategy = .iso8601

        do {
            let encoded =
                try encoder.encode(data)

            try encoded.write(
                to: fileURL,
                options: .atomic
            )
        } catch {
            print(
                "Testudo: could not save data:",
                error
            )
        }
    }

    func createTheme(
        name: String,
        parentThemeID: UUID?
    ) {
        let cleaned =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleaned.isEmpty else {
            return
        }

        data.themes.append(
            Theme(
                parentThemeID: parentThemeID,
                name: cleaned
            )
        )

        save()
    }

    func deleteTheme(
        id: UUID
    ) {
        let descendants =
            themeDescendantIDs(of: id)

        let allThemeIDs =
            Set(descendants + [id])

        let workIDs =
            data.workItems
                .filter {
                    guard
                        let themeID = $0.themeID
                    else {
                        return false
                    }

                    return allThemeIDs.contains(
                        themeID
                    )
                }
                .map(\.id)

        for workID in workIDs {
            deleteWorkItem(
                id: workID,
                saveAfterDeletion: false
            )
        }

        data.themes.removeAll {
            allThemeIDs.contains($0.id)
        }

        data.themeEntityRelationships
            .removeAll {
                allThemeIDs.contains(
                    $0.themeID
                )
            }

        save()
    }

    func theme(
        id: UUID?
    ) -> Theme? {
        guard let id else {
            return nil
        }

        return data.themes.first {
            $0.id == id
        }
    }

    func childThemes(
        of themeID: UUID?
    ) -> [Theme] {
        data.themes
            .filter {
                $0.parentThemeID == themeID
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }

    func themeDescendantIDs(
        of parentID: UUID
    ) -> [UUID] {
        let children =
            childThemes(of: parentID)

        var result =
            children.map(\.id)

        for child in children {
            result.append(
                contentsOf:
                    themeDescendantIDs(
                        of: child.id
                    )
            )
        }

        return result
    }

    @discardableResult
    func createWorkItem(
        themeID: UUID?,
        parentWorkItemID: UUID?,
        kind: WorkItemKind,
        title: String,
        body: String,
        deadlineAt: Date?,
        deadlineTimeZoneID: String? = nil
    ) -> UUID? {
        let cleanedTitle =
            title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanedBody =
            body.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !cleanedTitle.isEmpty
            || !cleanedBody.isEmpty
        else {
            return nil
        }

        let now = Date()

        let currentTimeZoneID =
            TestudoTime
                .deviceTimeZoneID

        let item =
            WorkItem(
                themeID: themeID,
                parentWorkItemID:
                    parentWorkItemID,
                kind: kind,
                title:
                    cleanedTitle.isEmpty
                    ? nil
                    : cleanedTitle,
                body: cleanedBody,
                status:
                    kind == .task
                    ? .todo
                    : nil,
                createdAt: now,
                updatedAt: now,
                deadlineAt:
                    kind == .task
                    ? deadlineAt
                    : nil,
                loggedAt:
                    kind == .activity
                    ? now
                    : nil,
                createdByMembershipID:
                    currentEnvironmentMembership?.id,
                updatedByMembershipID:
                    currentEnvironmentMembership?.id,
                createdTimeZoneID:
                    currentTimeZoneID,
                updatedTimeZoneID:
                    currentTimeZoneID,
                deadlineTimeZoneID:
                    kind == .task
                    && deadlineAt != nil
                    ? (
                        TestudoTime
                            .validTimeZoneIdentifier(
                                deadlineTimeZoneID
                            )
                        ?? currentTimeZoneID
                    )
                    : nil,
                loggedTimeZoneID:
                    kind == .activity
                    ? currentTimeZoneID
                    : nil
            )

        data.workItems.append(item)

        data.historyEvents.append(
            HistoryEvent(
                workItemID: item.id,
                kind: .created,
                timestamp: now,
                text:
                    "Created \(kind.displayName.lowercased())",
                actorMembershipID:
                    currentEnvironmentMembership?.id,
                timeZoneID:
                    currentTimeZoneID
            )
        )

        if
            kind == .task,
            let deadlineAt
        {
            appendTaskLifecycleHistory(
                workItemID:
                    item.id,
                kind:
                    .scheduled,
                timestamp:
                    now,
                text:
                    "\(taskHistoryTitle(item)) scheduled",
                newValue:
                    TestudoTime
                        .utcString(
                            deadlineAt
                        ),
                valueTimeZoneID:
                    TestudoTime
                        .validTimeZoneIdentifier(
                            deadlineTimeZoneID
                        )
                    ?? currentTimeZoneID
            )
        }

        save()

        return item.id
    }

    func workItem(
        id: UUID
    ) -> WorkItem? {
        data.workItems.first {
            $0.id == id
        }
    }

    func rootWorkItems(
        for themeID: UUID
    ) -> [WorkItem] {
        activeWorkItems
            .filter {
                $0.themeID == themeID
                && $0.parentWorkItemID == nil
            }
            .sorted {
                $0.createdAt < $1.createdAt
            }
    }

    func childWorkItems(
        of parentID: UUID
    ) -> [WorkItem] {
        data.workItems
            .filter {
                $0.parentWorkItemID
                == parentID
            }
            .sorted {
                $0.createdAt < $1.createdAt
            }
    }

    func workItemDescendantIDs(
        of parentID: UUID
    ) -> [UUID] {
        let children =
            childWorkItems(of: parentID)

        var result =
            children.map(\.id)

        for child in children {
            result.append(
                contentsOf:
                    workItemDescendantIDs(
                        of: child.id
                    )
            )
        }

        return result
    }

    func setTaskStatus(
        workItemID: UUID,
        status: TaskStatus
    ) {
        guard
            let index =
                data.workItems.firstIndex(
                    where: {
                        $0.id == workItemID
                    }
                ),
            data.workItems[index].kind
                == .task
        else {
            return
        }

        // Closed is no longer a workflow status.
        // .closed exists only for decoding historical files.
        if status == .closed {
            return
        }

        // Archived Tasks must first be reopened.
        if
            data.workItems[index]
                .closedAt != nil
        {
            return
        }

        // Discontinued carries additional lifecycle metadata.
        // It must be entered through the full Work editor so a
        // reason is always recorded.
        if status == .discontinued {
            return
        }

        let previous =
            data.workItems[index].status

        let hadStarted =
            data.workItems[index]
                .startedAt != nil

        guard previous != status else {
            return
        }

        let now = Date()

        let currentTimeZoneID =
            TestudoTime
                .deviceTimeZoneID

        data.workItems[index].status =
            status

        data.workItems[index].updatedAt =
            now

        data.workItems[index].updatedByMembershipID =
            currentEnvironmentMembership?.id

        data.workItems[index]
            .updatedTimeZoneID =
            currentTimeZoneID

        if
            status == .inProgress,
            data.workItems[index].startedAt
                == nil
        {
            data.workItems[index].startedAt =
                now

            data.workItems[index]
                .startedTimeZoneID =
                currentTimeZoneID
        }

        if status == .completed {
            data.workItems[index].completedAt =
                now

            data.workItems[index]
                .completedTimeZoneID =
                currentTimeZoneID
        } else {
            data.workItems[index].completedAt =
                nil

            data.workItems[index]
                .completedTimeZoneID =
                nil
        }

        if
            data.workItems[index]
                .discontinuedAt != nil
        {
            data.workItems[index]
                .discontinuedAt =
                nil

            data.workItems[index]
                .discontinuedTimeZoneID =
                nil

            data.workItems[index]
                .discontinuationReason =
                nil

            data.workItems[index]
                .discontinuationNote =
                nil
        }

        let updatedTask =
            data.workItems[index]

        let historyTitle =
            taskHistoryTitle(
                updatedTask
            )

        if
            status == .inProgress,
            !hadStarted
        {
            appendTaskLifecycleHistory(
                workItemID:
                    workItemID,
                kind:
                    .started,
                timestamp:
                    now,
                text:
                    "\(historyTitle) started"
            )
        }

        if
            status == .completed,
            previous != .completed
        {
            appendTaskLifecycleHistory(
                workItemID:
                    workItemID,
                kind:
                    .completed,
                timestamp:
                    now,
                text:
                    "\(historyTitle) completed"
            )
        }

        data.historyEvents.append(
            HistoryEvent(
                workItemID: workItemID,
                kind: .statusChanged,
                timestamp: now,
                text:
                    "Status changed to \(status.displayName)",
                previousValue:
                    previous?.rawValue,
                newValue:
                    status.rawValue,
                actorMembershipID:
                    currentEnvironmentMembership?.id,
                timeZoneID:
                    currentTimeZoneID            )
        )

        save()
    }

    @discardableResult
    func updateTaskStartedAt(
        workItemID: UUID,
        startedAt: Date?,
        startedTimeZoneID: String?,
        recordAudit: Bool = true
    ) -> String? {
        guard
            let index =
                data.workItems.firstIndex(
                    where: {
                        $0.id
                            == workItemID
                    }
                ),
            data.workItems[index]
                .kind
                == .task
        else {
            return "Task not found."
        }

        let now =
            Date()

        let currentTimeZoneID =
            TestudoTime
                .deviceTimeZoneID

        if let startedAt {
            guard
                startedAt <= now
            else {
                return
                    "Started date cannot be in the future."
            }

            if
                let completedAt =
                    data.workItems[index]
                        .completedAt,
                startedAt > completedAt
            {
                return
                    "Started date cannot be later than the completed date."
            }

            if
                let discontinuedAt =
                    data.workItems[index]
                        .discontinuedAt,
                startedAt > discontinuedAt
            {
                return
                    "Started date cannot be later than the discontinued date."
            }
        }

        let previousStartedAt =
            data.workItems[index]
                .startedAt

        let previousTimeZoneID =
            data.workItems[index]
                .startedTimeZoneID

        let normalizedTimeZoneID:
            String?

        if startedAt == nil {
            normalizedTimeZoneID =
                nil
        } else {
            normalizedTimeZoneID =
                TestudoTime
                    .validTimeZoneIdentifier(
                        startedTimeZoneID
                    )
                ?? previousTimeZoneID
                ?? currentTimeZoneID
        }

        if
            previousStartedAt == startedAt,
            previousTimeZoneID
                == normalizedTimeZoneID
        {
            return nil
        }

        data.workItems[index]
            .startedAt =
            startedAt

        data.workItems[index]
            .startedTimeZoneID =
            normalizedTimeZoneID

        data.workItems[index]
            .updatedAt =
            now

        data.workItems[index]
            .updatedTimeZoneID =
            currentTimeZoneID

        data.workItems[index]
            .updatedByMembershipID =
            currentEnvironmentMembership?
                .id

        // There should be one canonical lifecycle-start event.
        // Its timestamp is the real-world Started value.
        data.historyEvents.removeAll {
            $0.workItemID
                == workItemID
            && $0.kind
                == .started
        }

        let updatedTask =
            data.workItems[index]

        if let startedAt {
            data.historyEvents.append(
                HistoryEvent(
                    workItemID:
                        workItemID,
                    kind:
                        .started,
                    timestamp:
                        startedAt,
                    text:
                        "\(taskHistoryTitle(updatedTask)) started",
                    actorMembershipID:
                        currentEnvironmentMembership?
                            .id,
                    timeZoneID:
                        normalizedTimeZoneID,
                    valueTimeZoneID:
                        normalizedTimeZoneID
                )
            )
        }

        if recordAudit {
            let auditText:
                String

            if
                previousStartedAt == nil,
                startedAt != nil
            {
                auditText =
                    "Started date set"
            } else if startedAt == nil {
                auditText =
                    "Started date cleared"
            } else {
                auditText =
                    "Started date changed"
            }

            data.historyEvents.append(
                HistoryEvent(
                    workItemID:
                        workItemID,
                    kind:
                        .edited,
                    timestamp:
                        now,
                    text:
                        auditText,
                    previousValue:
                        previousStartedAt.map {
                            TestudoTime
                                .utcString(
                                    $0
                                )
                        },
                    newValue:
                        startedAt.map {
                            TestudoTime
                                .utcString(
                                    $0
                                )
                        },
                    actorMembershipID:
                        currentEnvironmentMembership?
                            .id,
                    timeZoneID:
                        currentTimeZoneID,
                    valueTimeZoneID:
                        normalizedTimeZoneID
                )
            )
        }

        save()

        return nil
    }


    @discardableResult
    func updateTaskDiscontinuationDetails(
        workItemID: UUID,
        discontinuedAt: Date,
        discontinuedTimeZoneID: String?,
        reason: TaskDiscontinuationReason,
        note: String,
        recordAudit: Bool = true
    ) -> String? {
        guard
            let index =
                data.workItems.firstIndex(
                    where: {
                        $0.id
                            == workItemID
                    }
                ),
            data.workItems[index]
                .kind
                == .task
        else {
            return "Task not found."
        }

        guard
            data.workItems[index]
                .status
                == .discontinued
        else {
            return
                "Discontinuation details require a Discontinued Task."
        }

        let now =
            Date()

        guard discontinuedAt <= now
        else {
            return
                "Discontinued date cannot be in the future."
        }

        if
            let startedAt =
                data.workItems[index]
                    .startedAt,
            discontinuedAt < startedAt
        {
            return
                "Discontinued date cannot be earlier than Started."
        }

        let currentTimeZoneID =
            TestudoTime
                .deviceTimeZoneID

        let normalizedTimeZoneID =
            TestudoTime
                .validTimeZoneIdentifier(
                    discontinuedTimeZoneID
                )
            ?? data.workItems[index]
                .discontinuedTimeZoneID
            ?? currentTimeZoneID

        let cleanedNote =
            note
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let previousDate =
            data.workItems[index]
                .discontinuedAt

        let previousTimeZoneID =
            data.workItems[index]
                .discontinuedTimeZoneID

        let previousReason =
            data.workItems[index]
                .discontinuationReason

        let previousNote =
            data.workItems[index]
                .discontinuationNote

        let normalizedNote =
            cleanedNote.isEmpty
            ? nil
            : cleanedNote

        let changed =
            previousDate != discontinuedAt
            || previousTimeZoneID
                != normalizedTimeZoneID
            || previousReason != reason
            || previousNote != normalizedNote

        data.workItems[index]
            .discontinuedAt =
            discontinuedAt

        data.workItems[index]
            .discontinuedTimeZoneID =
            normalizedTimeZoneID

        data.workItems[index]
            .discontinuationReason =
            reason

        data.workItems[index]
            .discontinuationNote =
            normalizedNote

        data.workItems[index]
            .updatedAt =
            now

        data.workItems[index]
            .updatedTimeZoneID =
            currentTimeZoneID

        data.workItems[index]
            .updatedByMembershipID =
            currentEnvironmentMembership?
                .id

        // Replace only the lifecycle event representing the
        // CURRENT discontinuation instance. Earlier discontinued
        // -> reopened -> discontinued cycles remain in history.
        if
            let previousDate,
            let eventIndex =
                data.historyEvents
                    .lastIndex(
                        where: {
                            $0.workItemID
                                == workItemID
                            && $0.kind
                                == .discontinued
                            && $0.timestamp
                                == previousDate
                        }
                    )
        {
            data.historyEvents
                .remove(
                    at:
                        eventIndex
                )
        }

        let updatedTask =
            data.workItems[index]

        data.historyEvents.append(
            HistoryEvent(
                workItemID:
                    workItemID,
                kind:
                    .discontinued,
                timestamp:
                    discontinuedAt,
                text:
                    "\(taskHistoryTitle(updatedTask)) discontinued — \(reason.displayName)",
                newValue:
                    normalizedNote,
                actorMembershipID:
                    currentEnvironmentMembership?
                        .id,
                timeZoneID:
                    normalizedTimeZoneID,
                valueTimeZoneID:
                    normalizedTimeZoneID
            )
        )

        if
            recordAudit,
            changed
        {
            data.historyEvents.append(
                HistoryEvent(
                    workItemID:
                        workItemID,
                    kind:
                        .edited,
                    timestamp:
                        now,
                    text:
                        "Discontinuation details updated",
                    previousValue:
                        previousReason?
                            .displayName,
                    newValue:
                        reason.displayName,
                    actorMembershipID:
                        currentEnvironmentMembership?
                            .id,
                    timeZoneID:
                        currentTimeZoneID,
                    valueTimeZoneID:
                        normalizedTimeZoneID
                )
            )
        }

        save()

        return nil
    }


    func deleteWorkItem(
        id: UUID
    ) {
        deleteWorkItem(
            id: id,
            saveAfterDeletion: true
        )
    }

    private func deleteWorkItem(
        id: UUID,
        saveAfterDeletion: Bool
    ) {
        let descendants =
            workItemDescendantIDs(of: id)

        let allIDs =
            Set(descendants + [id])

        data.workItems.removeAll {
            allIDs.contains($0.id)
        }

        data.workEntityRelationships.removeAll {
            allIDs.contains(
                $0.workItemID
            )
        }

        data.historyEvents.removeAll {
            allIDs.contains(
                $0.workItemID
            )
        }

        if saveAfterDeletion {
            save()
        }
    }

    func tasks(
        with status: TaskStatus
    ) -> [WorkItem] {
        activeWorkItems
            .filter {
                $0.kind == .task
                && $0.status == status
            }
            .sorted {
                $0.updatedAt > $1.updatedAt
            }
    }

    func todayWorkItems() -> [WorkItem] {
        let calendar =
            Calendar.autoupdatingCurrent

        return activeWorkItems
            .filter { item in
                if calendar.isDateInToday(
                    item.createdAt
                ) {
                    return true
                }

                if
                    let loggedAt =
                        item.loggedAt,
                    calendar.isDateInToday(
                        loggedAt
                    )
                {
                    return true
                }

                if
                    let startedAt =
                        item.startedAt,
                    calendar.isDateInToday(
                        startedAt
                    )
                {
                    return true
                }

                if
                    let completedAt =
                        item.completedAt,
                    calendar.isDateInToday(
                        completedAt
                    )
                {
                    return true
                }

                if
                    let discontinuedAt =
                        item.discontinuedAt,
                    calendar.isDateInToday(
                        discontinuedAt
                    )
                {
                    return true
                }

                return false
            }
            .sorted {
                $0.updatedAt > $1.updatedAt
            }
    }

    @discardableResult
    func createEntity(
        kind: EntityKind,
        name: String,
        initialContainerID: UUID?
    ) -> UUID? {
        let cleaned =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleaned.isEmpty else {
            return nil
        }

        let entity =
            Entity(
                kind: kind,
                name: cleaned
            )

        data.entities.append(entity)

        if kind == .person {
            data.personProfiles.append(
                PersonProfile(
                    entityID: entity.id,
                    firstName: cleaned
                )
            )
        }

        if let initialContainerID {
            data.memberships.append(
                EntityMembership(
                    memberEntityID:
                        entity.id,
                    containerEntityID:
                        initialContainerID,
                    isPrimary: true
                )
            )
        }

        save()

        return entity.id
    }

    @discardableResult
    func createPersonEntity(
        firstName: String,
        lastName: String
    ) -> UUID? {
        let cleanedFirst =
            firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanedLast =
            lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let displayName =
            [
                cleanedFirst,
                cleanedLast
            ]
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator:
                    " "
            )

        guard
            !displayName.isEmpty
        else {
            return nil
        }

        guard
            let entityID =
                createEntity(
                    kind:
                        .person,
                    name:
                        displayName,
                    initialContainerID:
                        nil
                )
        else {
            return nil
        }

        savePersonProfile(
            PersonProfile(
                entityID:
                    entityID,
                firstName:
                    cleanedFirst,
                lastName:
                    cleanedLast
            )
        )

        return entityID
    }


    func removeMembership(
        memberID: UUID,
        containerID: UUID
    ) {
        data.memberships.removeAll {
            $0.memberEntityID == memberID
            && $0.containerEntityID == containerID
        }

        save()
    }

    func addMembership(
        memberID: UUID,
        containerID: UUID
    ) {
        guard memberID != containerID else {
            return
        }

        let exists =
            data.memberships.contains {
                $0.memberEntityID
                    == memberID
                && $0.containerEntityID
                    == containerID
            }

        guard !exists else {
            return
        }

        data.memberships.append(
            EntityMembership(
                memberEntityID:
                    memberID,
                containerEntityID:
                    containerID
            )
        )

        save()
    }

    func deleteEntity(
        id: UUID
    ) {
        data.entities.removeAll {
            $0.id == id
        }

        data.memberships.removeAll {
            $0.memberEntityID == id
            || $0.containerEntityID == id
        }

        data.workEntityRelationships.removeAll {
            $0.entityID == id
        }

        data.themeEntityRelationships.removeAll {
            $0.entityID == id
        }

        save()
    }

    func memberships(
        for entityID: UUID
    ) -> [EntityMembership] {
        data.memberships.filter {
            $0.memberEntityID
            == entityID
        }
    }

    func containers(
        for entityID: UUID
    ) -> [Entity] {
        let ids =
            Set(
                memberships(
                    for: entityID
                )
                .map(\.containerEntityID)
            )

        return data.entities
            .filter {
                ids.contains($0.id)
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }

    func entity(
        id: UUID
    ) -> Entity? {
        data.entities.first {
            $0.id == id
        }
    }

    func entities(
        of kind: EntityKind
    ) -> [Entity] {
        data.entities
            .filter {
                $0.kind == kind
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }

    func possibleContainers(
        for kind: EntityKind
    ) -> [Entity] {
        data.entities
            .filter { entity in
                switch kind {
                case .organization:
                    return
                        entity.kind
                        == .organization

                case .group,
                     .person:
                    return
                        entity.kind
                            == .organization
                        || entity.kind
                            == .group
                }
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }
}


extension TestudoStore {
    func personProfile(
        for entityID: UUID
    ) -> PersonProfile? {
        data.personProfiles.first {
            $0.entityID == entityID
        }
    }

    @discardableResult
    private func createPersonForUser(
        firstName: String,
        lastName: String,
        avatarData: Data?
    ) -> UUID {
        let cleanedFirst =
            firstName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanedLast =
            lastName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let name =
            [cleanedFirst, cleanedLast]
                .filter {
                    !$0.isEmpty
                }
                .joined(separator: " ")

        let entity =
            Entity(
                kind: .person,
                name:
                    name.isEmpty
                    ? "Unnamed Person"
                    : name
            )

        data.entities.append(entity)

        data.personProfiles.append(
            PersonProfile(
                entityID: entity.id,
                firstName:
                    cleanedFirst,
                lastName:
                    cleanedLast,
                avatarData:
                    avatarData
            )
        )

        return entity.id
    }

    func savePersonProfile(
        _ profile: PersonProfile
    ) {
        guard
            let entityIndex =
                data.entities.firstIndex(
                    where: {
                        $0.id == profile.entityID
                        && $0.kind == .person
                    }
                )
        else {
            return
        }

        var updated = profile

        updated.timeZone =
            TestudoTime
                .validTimeZoneIdentifier(
                    updated.timeZone
                )
        updated.updatedAt = Date()

        let cleanedName =
            updated.displayName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if !cleanedName.isEmpty {
            data.entities[entityIndex].name =
                cleanedName

            data.entities[entityIndex].updatedAt =
                Date()
        }

        if let index =
            data.personProfiles.firstIndex(
                where: {
                    $0.entityID
                        == updated.entityID
                }
            )
        {
            data.personProfiles[index] =
                updated
        } else {
            data.personProfiles.append(
                updated
            )
        }

        for membershipIndex in
            data.environmentMemberships.indices
        {
            guard
                data.environmentMemberships[
                    membershipIndex
                ]
                .personEntityID
                    == updated.entityID
            else {
                continue
            }

            data.environmentMemberships[
                membershipIndex
            ]
            .firstName =
                updated.firstName

            data.environmentMemberships[
                membershipIndex
            ]
            .lastName =
                updated.lastName
        }

        save()
    }

    private func ensureAllPeopleHaveProfiles() {
        var changed = false

        let people =
            data.entities.filter {
                $0.kind == .person
            }

        for person in people {
            let exists =
                data.personProfiles.contains {
                    $0.entityID == person.id
                }

            if !exists {
                data.personProfiles.append(
                    PersonProfile(
                        entityID: person.id,
                        firstName: person.name
                    )
                )

                changed = true
            }
        }

        if changed {
            save()
        }
    }

}


extension TestudoStore {
}


extension TestudoStore {
}


extension TestudoStore {

    // ========================================================
    // MARK: Reset local application state
    //
    // This concerns the installed application only.
    //
    // It deliberately does NOT delete any Environment database.
    // Managed or external Environment directories remain intact
    // and may be loaded again later.
    // ========================================================

    func resetApplication() {

        signOutApplicationAndRemoveLocalData()
    }
}

extension TestudoStore {
    func updateWorkItemDetails(
        itemID: UUID,
        title: String,
        body: String,
        themeID: UUID?,
        parentWorkItemID: UUID?,
        status: TaskStatus?,
        deadlineAt: Date?,
        reminderAt: Date?,
        scheduledAt: Date?,
        loggedAt: Date? = nil,
        deadlineTimeZoneID: String? = nil,
        reminderTimeZoneID: String? = nil,
        loggedTimeZoneID: String? = nil
    ) -> String? {
        guard
            let index =
                data.workItems.firstIndex(
                    where: {
                        $0.id == itemID
                    }
                )
        else {
            return "Work item not found."
        }

        if status == .closed {
            return
                "Closed is an archive lifecycle state, not a Task status."
        }

        if
            data.workItems[index]
                .closedAt != nil
        {
            if
                parentWorkItemID
                    != data.workItems[index]
                        .parentWorkItemID
            {
                return
                    "Reopen this Task before changing its Parent Task."
            }

            if
                status
                    != data.workItems[index]
                        .status
            {
                return
                    "Reopen this Task before changing its workflow status."
            }
        }

        if let themeID {
            guard
                data.themes.contains(
                    where: {
                        $0.id == themeID
                    }
                )
            else {
                return "Theme not found."
            }
        }

        if let parentWorkItemID {
            guard
                parentWorkItemID
                    != itemID
            else {
                return
                    "An item cannot be its own parent."
            }

            guard
                let parent =
                    data.workItems.first(
                        where: {
                            $0.id
                                == parentWorkItemID
                        }
                    ),
                parent.kind == .task
            else {
                return
                    "The parent must be a Task."
            }

            var current =
                parent.parentWorkItemID

            var visited =
                Set<UUID>()

            while let currentID =
                current
            {
                if currentID == itemID {
                    return
                        "This parent would create a circular hierarchy."
                }

                if visited.contains(
                    currentID
                ) {
                    break
                }

                visited.insert(
                    currentID
                )

                current =
                    data.workItems.first(
                        where: {
                            $0.id
                                == currentID
                        }
                    )?
                    .parentWorkItemID
            }
        }

        let now = Date()

        let currentTimeZoneID =
            TestudoTime
                .deviceTimeZoneID

        let oldStatus =
            data.workItems[index]
                .status

        let oldDeadline =
            data.workItems[index]
                .deadlineAt

        let hadStarted =
            data.workItems[index]
                .startedAt != nil

        let cleanedTitle =
            title.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        data.workItems[index].title =
            cleanedTitle.isEmpty
            ? nil
            : cleanedTitle

        data.workItems[index].body =
            body

        data.workItems[index].themeID =
            themeID

        data.workItems[index]
            .parentWorkItemID =
            parentWorkItemID

        switch
            data.workItems[index].kind
        {
        case .task:
            let newStatus =
                status ?? .todo

            data.workItems[index].status =
                newStatus

            data.workItems[index]
                .deadlineAt =
                deadlineAt

            data.workItems[index]
                .deadlineTimeZoneID =
                deadlineAt == nil
                ? nil
                : (
                    TestudoTime
                        .validTimeZoneIdentifier(
                            deadlineTimeZoneID
                        )
                    ?? data.workItems[index]
                        .deadlineTimeZoneID
                    ?? currentTimeZoneID
                )

            data.workItems[index]
                .reminderAt =
                nil

            data.workItems[index]
                .scheduledAt =
                nil

            if
                newStatus
                    == .inProgress,
                oldStatus
                    != .inProgress,
                data.workItems[index]
                    .startedAt == nil
            {
                data.workItems[index]
                    .startedAt =
                    now

                data.workItems[index]
                    .startedTimeZoneID =
                    currentTimeZoneID
            }

            if
                newStatus
                    == .completed,
                oldStatus
                    != .completed
            {
                data.workItems[index]
                    .completedAt =
                    now

                data.workItems[index]
                    .completedTimeZoneID =
                    currentTimeZoneID
            }

            if
                newStatus
                    != .completed,
                oldStatus
                    == .completed
            {
                data.workItems[index]
                    .completedAt =
                    nil

                data.workItems[index]
                    .completedTimeZoneID =
                    nil
            }

            if
                newStatus
                    == .discontinued,
                oldStatus
                    != .discontinued
            {
                data.workItems[index]
                    .discontinuedAt =
                    now

                data.workItems[index]
                    .discontinuedTimeZoneID =
                    currentTimeZoneID

                data.workItems[index]
                    .discontinuationReason =
                    nil

                data.workItems[index]
                    .discontinuationNote =
                    nil
            }

            // Leaving Discontinued clears its current
            // outcome metadata while historical lifecycle
            // records remain intact.
            if
                newStatus
                    != .discontinued,
                data.workItems[index]
                    .discontinuedAt
                    != nil
            {
                data.workItems[index]
                    .discontinuedAt =
                    nil

                data.workItems[index]
                    .discontinuedTimeZoneID =
                    nil

                data.workItems[index]
                    .discontinuationReason =
                    nil

                data.workItems[index]
                    .discontinuationNote =
                    nil
            }

        case .note:
            data.workItems[index].status =
                nil

            data.workItems[index]
                .deadlineAt =
                nil

            data.workItems[index]
                .scheduledAt =
                nil

            data.workItems[index]
                .reminderAt =
                reminderAt

            data.workItems[index]
                .reminderTimeZoneID =
                reminderAt == nil
                ? nil
                : (
                    TestudoTime
                        .validTimeZoneIdentifier(
                            reminderTimeZoneID
                        )
                    ?? data.workItems[index]
                        .reminderTimeZoneID
                    ?? currentTimeZoneID
                )

        case .activity:
            data.workItems[index].status =
                nil

            data.workItems[index]
                .deadlineAt =
                nil

            data.workItems[index]
                .scheduledAt =
                nil

            data.workItems[index]
                .reminderAt =
                nil

            data.workItems[index]
                .loggedAt =
                loggedAt
                ?? data.workItems[index].loggedAt
                ?? now

            data.workItems[index]
                .loggedTimeZoneID =
                TestudoTime
                    .validTimeZoneIdentifier(
                        loggedTimeZoneID
                    )
                ?? data.workItems[index]
                    .loggedTimeZoneID
                ?? currentTimeZoneID
        }

        if
            data.workItems[index].kind
                == .task
        {
            let updatedTask =
                data.workItems[index]

            let historyTitle =
                taskHistoryTitle(
                    updatedTask
                )

            if
                oldDeadline
                    != updatedTask
                        .deadlineAt,
                let newDeadline =
                    updatedTask
                        .deadlineAt
            {
                appendTaskLifecycleHistory(
                    workItemID:
                        updatedTask.id,
                    kind:
                        .scheduled,
                    timestamp:
                        now,
                    text:
                        "\(historyTitle) scheduled",
                    previousValue:
                        oldDeadline.map {
                            TestudoTime
                                .utcString(
                                    $0
                                )
                        },
                    newValue:
                        TestudoTime
                            .utcString(
                                newDeadline
                            ),
                    valueTimeZoneID:
                        updatedTask
                            .deadlineTimeZoneID
                )
            }

            if
                updatedTask.status
                    == .inProgress,
                oldStatus
                    != .inProgress,
                !hadStarted
            {
                appendTaskLifecycleHistory(
                    workItemID:
                        updatedTask.id,
                    kind:
                        .started,
                    timestamp:
                        now,
                    text:
                        "\(historyTitle) started"
                )
            }

            if
                updatedTask.status
                    == .completed,
                oldStatus
                    != .completed
            {
                appendTaskLifecycleHistory(
                    workItemID:
                        updatedTask.id,
                    kind:
                        .completed,
                    timestamp:
                        now,
                    text:
                        "\(historyTitle) completed"
                )
            }

            if
                updatedTask.status
                    == .discontinued,
                oldStatus
                    != .discontinued
            {
                appendTaskLifecycleHistory(
                    workItemID:
                        updatedTask.id,
                    kind:
                        .discontinued,
                    timestamp:
                        now,
                    text:
                        "\(historyTitle) discontinued"
                )
            }

            if
                oldStatus
                    != updatedTask.status
            {
                data.historyEvents.append(
                    HistoryEvent(
                        workItemID:
                            updatedTask.id,
                        kind:
                            .statusChanged,
                        timestamp:
                            now,
                        text:
                            "Status changed to \(updatedTask.status?.displayName ?? "Unknown")",
                        previousValue:
                            oldStatus?
                                .rawValue,
                        newValue:
                            updatedTask.status?
                                .rawValue,
                        actorMembershipID:
                            currentEnvironmentMembership?
                                .id,
                        timeZoneID:
                            currentTimeZoneID
                    )
                )
            }
        }

        data.workItems[index].updatedAt =
            now

        data.workItems[index]
            .updatedTimeZoneID =
            currentTimeZoneID

        data.workItems[index]
            .updatedByMembershipID =
            currentEnvironmentMembership?.id

        save()

        return nil
    }
}


extension TestudoStore {
    @discardableResult
    func addWorkRelationship(
        workItemID: UUID,
        entityID: UUID,
        role: WorkRelationshipRole,
        inheritedByChildren: Bool = true
    ) -> String? {
        guard
            let workIndex =
                data.workItems.firstIndex(
                    where: {
                        $0.id == workItemID
                    }
                )
        else {
            return "Work item not found."
        }

        guard
            let entity =
                data.entities.first(
                    where: {
                        $0.id == entityID
                    }
                )
        else {
            return "Related entity not found."
        }

        let duplicate =
            data.workEntityRelationships
                .contains {
                    $0.workItemID
                        == workItemID
                    && $0.entityID
                        == entityID
                    && $0.role
                        == role
                }

        guard !duplicate else {
            return
                "That relationship already exists."
        }

        let now =
            Date()

        let timeZoneID =
            TestudoTime
                .deviceTimeZoneID

        let relationship =
            WorkEntityRelationship(
                workItemID:
                    workItemID,
                entityID:
                    entityID,
                role:
                    role,
                inheritedByChildren:
                    inheritedByChildren,
                createdAt:
                    now
            )

        data.workEntityRelationships
            .append(
                relationship
            )

        data.workItems[workIndex]
            .updatedAt =
            now

        data.workItems[workIndex]
            .updatedTimeZoneID =
            timeZoneID

        data.workItems[workIndex]
            .updatedByMembershipID =
            currentEnvironmentMembership?.id

        data.historyEvents
            .append(
                HistoryEvent(
                    workItemID:
                        workItemID,
                    kind:
                        .relationshipAdded,
                    timestamp:
                        now,
                    text:
                        "\(role.displayName): \(entity.name)",
                    actorMembershipID:
                        currentEnvironmentMembership?.id,
                    timeZoneID:
                        timeZoneID
                )
            )

        save()

        return nil
    }

    func updateWorkRelationshipDetails(
        relationshipID: UUID,
        entityID: UUID,
        role: WorkRelationshipRole,
        inheritedByChildren: Bool? = nil
    ) -> String? {
        guard
            let index =
                data.workEntityRelationships
                    .firstIndex(
                        where: {
                            $0.id
                                == relationshipID
                        }
                    )
        else {
            return "Relationship not found."
        }

        guard
            data.entities.contains(
                where: {
                    $0.id == entityID
                }
            )
        else {
            return "Related entity not found."
        }

        data.workEntityRelationships[index]
            .entityID =
            entityID

        data.workEntityRelationships[index]
            .role =
            role

        if let inheritedByChildren {
            data.workEntityRelationships[index]
                .inheritedByChildren =
                inheritedByChildren
        }

        save()

        return nil
    }

    func removeWorkRelationship(
        relationshipID: UUID
    ) {
        data.workEntityRelationships
            .removeAll {
                $0.id
                    == relationshipID
            }

        save()
    }
}


// ============================================================
// MARK: - Parent relationship inheritance
//
// A child receives independent copies of the immediate Parent
// Task's relationships that are explicitly marked
// inheritedByChildren.
//
// The copied records are ordinary WorkEntityRelationships.
// They remain fully editable inside the child and are never
// live-linked back to the Parent Task.
// ============================================================

extension TestudoStore {

    @discardableResult
    func copyInheritedWorkRelationships(
        fromParentTaskID parentTaskID:
            UUID,
        toWorkItemID childWorkItemID:
            UUID,
        replacingExisting:
            Bool
    ) -> String? {

        guard
            let parent =
                data.workItems
                    .first(
                        where: {
                            $0.id
                                == parentTaskID
                        }
                    ),
            parent.kind
                == .task
        else {
            return
                "Parent Task not found."
        }


        guard
            let childIndex =
                data.workItems
                    .firstIndex(
                        where: {
                            $0.id
                                == childWorkItemID
                        }
                    )
        else {
            return
                "Child work item not found."
        }


        guard
            parentTaskID
                != childWorkItemID
        else {
            return
                "A Task cannot inherit relationships from itself."
        }


        let parentRelationships =
            data.workEntityRelationships
                .filter {
                    relationship in

                    relationship.workItemID
                        == parentTaskID
                    &&
                    relationship
                        .inheritedByChildren
                    &&
                    data.entities
                        .contains(
                            where: {
                                $0.id
                                    == relationship
                                        .entityID
                            }
                        )
                }


        let now =
            Date()

        let timeZoneID =
            TestudoTime
                .deviceTimeZoneID


        var changed =
            false


        // ----------------------------------------------------
        // When a pre-existing Task is attached to a Parent and
        // the user chooses "Copy Parent Relationships", its old
        // relationship set is replaced completely.
        // ----------------------------------------------------

        if replacingExisting {

            let existing =
                data.workEntityRelationships
                    .filter {
                        $0.workItemID
                            == childWorkItemID
                    }


            if !existing.isEmpty {
                for relationship in
                    existing
                {
                    let entityName =
                        data.entities
                            .first(
                                where: {
                                    $0.id
                                        == relationship
                                            .entityID
                                }
                            )?
                            .name
                        ?? "Related entity"

                    data.historyEvents
                        .append(
                            HistoryEvent(
                                workItemID:
                                    childWorkItemID,
                                kind:
                                    .relationshipRemoved,
                                timestamp:
                                    now,
                                text:
                                    "\(relationship.role.displayName): \(entityName)",
                                actorMembershipID:
                                    currentEnvironmentMembership?
                                        .id,
                                timeZoneID:
                                    timeZoneID
                            )
                        )
                }

                data.workEntityRelationships
                    .removeAll {
                        $0.workItemID
                            == childWorkItemID
                    }

                changed =
                    true
            }
        }


        // ----------------------------------------------------
        // Copy only relationships missing from the child.
        //
        // This makes automatic inheritance during creation a
        // merge operation, so a relationship explicitly entered
        // in the creation form takes precedence.
        // ----------------------------------------------------

        for parentRelationship in
            parentRelationships
        {
            let duplicate =
                data.workEntityRelationships
                    .contains {
                        relationship in

                        relationship.workItemID
                            == childWorkItemID
                        &&
                        relationship.entityID
                            == parentRelationship.entityID
                        &&
                        relationship.role
                            == parentRelationship.role
                    }

            if duplicate {
                continue
            }


            let copied =
                WorkEntityRelationship(
                    workItemID:
                        childWorkItemID,
                    entityID:
                        parentRelationship
                            .entityID,
                    role:
                        parentRelationship
                            .role,
                    inheritedByChildren:
                        parentRelationship
                            .inheritedByChildren,
                    createdAt:
                        now
                )


            data.workEntityRelationships
                .append(
                    copied
                )


            let entityName =
                data.entities
                    .first(
                        where: {
                            $0.id
                                == copied
                                    .entityID
                        }
                    )?
                    .name
                ?? "Related entity"


            data.historyEvents
                .append(
                    HistoryEvent(
                        workItemID:
                            childWorkItemID,
                        kind:
                            .relationshipAdded,
                        timestamp:
                            now,
                        text:
                            "\(copied.role.displayName): \(entityName)",
                        actorMembershipID:
                            currentEnvironmentMembership?
                                .id,
                        timeZoneID:
                            timeZoneID
                    )
                )


            changed =
                true
        }


        if changed {
            data.workItems[
                childIndex
            ]
            .updatedAt =
                now

            data.workItems[
                childIndex
            ]
            .updatedTimeZoneID =
                timeZoneID

            data.workItems[
                childIndex
            ]
            .updatedByMembershipID =
                currentEnvironmentMembership?
                    .id

            save()
        }


        return nil
    }
}


extension TestudoStore {
    func createChildWorkItem(
        parentTaskID: UUID,
        kind: WorkItemKind,
        title: String,
        body: String,
        deadlineAt: Date?,
        reminderAt: Date?,
        occurredAt: Date?,
        deadlineTimeZoneID: String? = nil,
        reminderTimeZoneID: String? = nil,
        occurredTimeZoneID: String? = nil
    ) -> (
        id: UUID?,
        error: String?
    ) {
        guard
            let parent =
                data.workItems.first(
                    where: {
                        $0.id == parentTaskID
                    }
                )
        else {
            return (
                nil,
                "Parent task not found."
            )
        }

        guard parent.kind == .task else {
            return (
                nil,
                "Only Tasks can contain child items."
            )
        }

        guard
            !isArchivedWorkItem(
                parent
            )
        else {
            return (
                nil,
                "Reopen the Parent Task before adding child work."
            )
        }

        let cleanedTitle =
            title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanedBody =
            body.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !cleanedTitle.isEmpty
            || !cleanedBody.isEmpty
        else {
            return (
                nil,
                "Enter a title or description."
            )
        }

        let now = Date()

        let currentTimeZoneID =
            TestudoTime
                .deviceTimeZoneID

        let item =
            WorkItem(
                themeID:
                    parent.themeID,
                parentWorkItemID:
                    parentTaskID,
                kind:
                    kind,
                title:
                    cleanedTitle.isEmpty
                    ? nil
                    : cleanedTitle,
                body:
                    cleanedBody,
                status:
                    kind == .task
                    ? .todo
                    : nil,
                createdAt:
                    now,
                updatedAt:
                    now,
                scheduledAt:
                    nil,
                deadlineAt:
                    kind == .task
                    ? deadlineAt
                    : nil,
                reminderAt:
                    kind == .note
                    ? reminderAt
                    : nil,
                startedAt:
                    nil,
                completedAt:
                    nil,
                loggedAt:
                    kind == .activity
                    ? occurredAt
                    : nil,
                createdByMembershipID:
                    currentEnvironmentMembership?.id,
                updatedByMembershipID:
                    currentEnvironmentMembership?.id,
                createdTimeZoneID:
                    currentTimeZoneID,
                updatedTimeZoneID:
                    currentTimeZoneID,
                deadlineTimeZoneID:
                    kind == .task
                    && deadlineAt != nil
                    ? (
                        TestudoTime
                            .validTimeZoneIdentifier(
                                deadlineTimeZoneID
                            )
                        ?? currentTimeZoneID
                    )
                    : nil,
                reminderTimeZoneID:
                    kind == .note
                    && reminderAt != nil
                    ? (
                        TestudoTime
                            .validTimeZoneIdentifier(
                                reminderTimeZoneID
                            )
                        ?? currentTimeZoneID
                    )
                    : nil,
                loggedTimeZoneID:
                    kind == .activity
                    ? (
                        TestudoTime
                            .validTimeZoneIdentifier(
                                occurredTimeZoneID
                            )
                        ?? currentTimeZoneID
                    )
                    : nil
            )

        data.workItems.append(
            item
        )

        data.historyEvents.append(
            HistoryEvent(
                workItemID:
                    item.id,
                kind:
                    .created,
                timestamp:
                    now,
                text:
                    kind == .activity
                    ? "Logged activity"
                    : "Created \(kind.displayName.lowercased())",
                actorMembershipID:
                    currentEnvironmentMembership?.id,
                timeZoneID:
                    currentTimeZoneID            )
        )

        if
            kind == .task,
            let deadlineAt
        {
            appendTaskLifecycleHistory(
                workItemID:
                    item.id,
                kind:
                    .scheduled,
                timestamp:
                    now,
                text:
                    "\(taskHistoryTitle(item)) scheduled",
                newValue:
                    TestudoTime
                        .utcString(
                            deadlineAt
                        ),
                valueTimeZoneID:
                    TestudoTime
                        .validTimeZoneIdentifier(
                            deadlineTimeZoneID
                        )
                    ?? currentTimeZoneID
            )
        }

        save()


        // A newly created Sub-task automatically receives
        // inheritable relationships from its immediate Parent.
        if kind == .task {
            _ =
                copyInheritedWorkRelationships(
                    fromParentTaskID:
                        parentTaskID,
                    toWorkItemID:
                        item.id,
                    replacingExisting:
                        false
                )
        }


        return (
            item.id,
            nil
        )
    }
}

extension TestudoStore {
    func taskHistoryTitle(
        _ item: WorkItem
    ) -> String {
        if
            let title =
                item.title?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !title.isEmpty
        {
            return title
        }

        let body =
            item.body
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !body.isEmpty {
            return body
        }

        return "Task"
    }

    func appendTaskLifecycleHistory(
        workItemID: UUID,
        kind: HistoryEventKind,
        timestamp: Date,
        text: String,
        previousValue: String? = nil,
        newValue: String? = nil,
        valueTimeZoneID: String? = nil
    ) {
        data.historyEvents.append(
            HistoryEvent(
                workItemID:
                    workItemID,
                kind:
                    kind,
                timestamp:
                    timestamp,
                text:
                    text,
                previousValue:
                    previousValue,
                newValue:
                    newValue,
                actorMembershipID:
                    currentEnvironmentMembership?.id,
                timeZoneID:
                    TestudoTime
                        .deviceTimeZoneID,
                valueTimeZoneID:
                    valueTimeZoneID
            )
        )
    }
}

extension TestudoStore {
    func updateThemeDetails(
        themeID: UUID,
        name: String,
        parentThemeID: UUID?,
        notes: String
    ) -> String? {
        guard
            let index =
                data.themes.firstIndex(
                    where: {
                        $0.id == themeID
                    }
                )
        else {
            return "Theme not found."
        }

        let cleanedName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanedName.isEmpty
        else {
            return "Theme name cannot be empty."
        }

        if let parentThemeID {
            guard parentThemeID != themeID
            else {
                return "A Theme cannot be its own parent."
            }

            let descendants =
                Set(
                    themeDescendantIDs(
                        of: themeID
                    )
                )

            guard
                !descendants.contains(
                    parentThemeID
                )
            else {
                return "A Theme cannot be moved inside one of its descendants."
            }

            guard
                data.themes.contains(
                    where: {
                        $0.id
                            == parentThemeID
                    }
                )
            else {
                return "Parent Theme not found."
            }
        }

        data.themes[index].name =
            cleanedName

        data.themes[index].parentThemeID =
            parentThemeID

        data.themes[index].notes =
            notes.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        data.themes[index].updatedAt =
            Date()

        save()

        return nil
    }

    func updateEntityDetails(
        entityID: UUID,
        name: String,
        notes: String
    ) -> String? {
        guard
            let index =
                data.entities.firstIndex(
                    where: {
                        $0.id == entityID
                    }
                )
        else {
            return "Entity not found."
        }

        let cleanedName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanedName.isEmpty
        else {
            return "Name cannot be empty."
        }

        data.entities[index].name =
            cleanedName

        data.entities[index].notes =
            notes.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        data.entities[index].updatedAt =
            Date()

        save()

        return nil
    }

    func entityDescendantIDs(
        of containerID: UUID
    ) -> [UUID] {
        let direct =
            data.memberships
                .filter {
                    $0.containerEntityID
                        == containerID
                }
                .map(
                    \.memberEntityID
                )

        var result =
            direct

        for childID in direct {
            result.append(
                contentsOf:
                    entityDescendantIDs(
                        of: childID
                    )
            )
        }

        return Array(
            Set(result)
        )
    }

    func updateEntityMemberships(
        entityID: UUID,
        containerIDs: Set<UUID>
    ) -> String? {
        guard
            let entity =
                data.entities.first(
                    where: {
                        $0.id == entityID
                    }
                )
        else {
            return "Entity not found."
        }

        let allowed =
            Set(
                possibleContainers(
                    for: entity.kind
                )
                .map(
                    \.id
                )
            )

        let descendants =
            Set(
                entityDescendantIDs(
                    of: entityID
                )
            )

        for containerID in
            containerIDs
        {
            guard
                containerID
                    != entityID
            else {
                return "An item cannot contain itself."
            }

            guard
                allowed.contains(
                    containerID
                )
            else {
                return "Invalid container."
            }

            guard
                !descendants.contains(
                    containerID
                )
            else {
                return "That relationship would create a cycle."
            }
        }

        data.memberships.removeAll {
            $0.memberEntityID
                == entityID
        }

        let ordered =
            containerIDs.sorted {
                $0.uuidString
                    < $1.uuidString
            }

        for (
            index,
            containerID
        ) in ordered.enumerated() {
            data.memberships.append(
                EntityMembership(
                    memberEntityID:
                        entityID,
                    containerEntityID:
                        containerID,
                    isPrimary:
                        index == 0
                )
            )
        }

        if
            let index =
                data.entities.firstIndex(
                    where: {
                        $0.id == entityID
                    }
                )
        {
            data.entities[index]
                .updatedAt =
                Date()
        }

        save()

        return nil
    }
}


// ============================================================
// MARK: - Rich Structure Metadata
// ============================================================

extension TestudoStore {
    func saveThemeMetadata(
        _ theme: Theme
    ) -> String? {
        guard
            let index =
                data.themes.firstIndex(
                    where: {
                        $0.id == theme.id
                    }
                )
        else {
            return "Theme not found."
        }

        var updated =
            theme

        updated.name =
            updated.name
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !updated.name.isEmpty
        else {
            return "Theme name cannot be empty."
        }

        if
            let parentID =
                updated.parentThemeID
        {
            guard
                parentID != updated.id
            else {
                return
                    "A Theme cannot be its own parent."
            }

            guard
                data.themes.contains(
                    where: {
                        $0.id == parentID
                    }
                )
            else {
                return
                    "Parent Theme not found."
            }

            let descendants =
                Set(
                    themeDescendantIDs(
                        of:
                            updated.id
                    )
                )

            guard
                !descendants.contains(
                    parentID
                )
            else {
                return
                    "A Theme cannot be moved inside one of its descendants."
            }
        }

        if
            let ownerID =
                updated.ownerEntityID,
            !data.entities.contains(
                where: {
                    $0.id == ownerID
                }
            )
        {
            return "Owner not found."
        }

        if
            let start =
                updated.startDate,
            let target =
                updated.targetDate,
            target < start
        {
            return
                "Target date cannot be earlier than start date."
        }

        updated.summary =
            cleanedOptional(
                updated.summary
            )

        updated.code =
            cleanedOptional(
                updated.code
            )

        updated.tags =
            cleanedOptional(
                updated.tags
            )

        updated.url =
            cleanedOptional(
                updated.url
            )

        updated.symbolName =
            cleanedOptional(
                updated.symbolName
            )

        updated.notes =
            updated.notes
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        updated.updatedAt =
            Date()

        data.themes[index] =
            updated

        save()

        return nil
    }


    func saveEntityMetadata(
        _ entity: Entity
    ) -> String? {
        guard
            let index =
                data.entities.firstIndex(
                    where: {
                        $0.id == entity.id
                    }
                )
        else {
            return "Entity not found."
        }

        var updated =
            entity

        updated.name =
            updated.name
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !updated.name.isEmpty
        else {
            return "Name cannot be empty."
        }

        // Entity kind is structural identity, not editable metadata.
        updated.kind =
            data.entities[index]
                .kind

        if
            let ownerID =
                updated.ownerEntityID,
            !data.entities.contains(
                where: {
                    $0.id == ownerID
                }
            )
        {
            return "Owner not found."
        }

        if
            let start =
                updated.startDate,
            let target =
                updated.targetDate,
            target < start
        {
            return
                "Target date cannot be earlier than start date."
        }

        updated.shortName =
            cleanedOptional(
                updated.shortName
            )

        updated.code =
            cleanedOptional(
                updated.code
            )

        updated.website =
            cleanedOptional(
                updated.website
            )

        updated.email =
            cleanedOptional(
                updated.email
            )

        updated.phone =
            cleanedOptional(
                updated.phone
            )

        updated.address =
            cleanedOptional(
                updated.address
            )

        updated.city =
            cleanedOptional(
                updated.city
            )

        updated.postalCode =
            cleanedOptional(
                updated.postalCode
            )

        updated.country =
            cleanedOptional(
                updated.country
            )

        updated.tags =
            cleanedOptional(
                updated.tags
            )

        updated.symbolName =
            cleanedOptional(
                updated.symbolName
            )

        updated.notes =
            updated.notes
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        updated.updatedAt =
            Date()

        data.entities[index] =
            updated

        save()

        return nil
    }


    private func cleanedOptional(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let cleaned =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return
            cleaned.isEmpty
            ? nil
            : cleaned
    }
}



extension TestudoStore {

}



extension TestudoStore {
    @discardableResult
    func deleteEntityProtected(
        id: UUID
    ) -> String? {
        guard
            let entity =
                data.entities.first(
                    where: {
                        $0.id == id
                    }
                )
        else {
            return "Item not found."
        }

        if
            entity.kind == .person,
            environmentMembership(
                linkedToPerson:
                    id
            ) != nil
        {
            return
                "This Person is linked to an Environment membership. Unlink that membership before deleting the Person."
        }


        let now =
            Date()

        // Remove a Person's extended profile as well.
        data.personProfiles.removeAll {
            $0.entityID == id
        }

        // Remove the entity itself.
        data.entities.removeAll {
            $0.id == id
        }

        // Remove all structural memberships involving it.
        data.memberships.removeAll {
            $0.memberEntityID == id
            || $0.containerEntityID == id
        }

        // Remove Work relationships involving it.
        data.workEntityRelationships.removeAll {
            $0.entityID == id
        }

        data.themeEntityRelationships.removeAll {
            $0.entityID == id
        }

        // Clear Theme ownership references.
        for index in data.themes.indices {
            if
                data.themes[index]
                    .ownerEntityID
                    == id
            {
                data.themes[index]
                    .ownerEntityID =
                    nil

                data.themes[index]
                    .updatedAt =
                    now
            }
        }

        // Clear ownership references from remaining
        // Organizations / Groups / People.
        for index in data.entities.indices {
            if
                data.entities[index]
                    .ownerEntityID
                    == id
            {
                data.entities[index]
                    .ownerEntityID =
                    nil

                data.entities[index]
                    .updatedAt =
                    now
            }
        }

        save()

        return nil
    }
}


// ============================================================
// MARK: - Organization / Group ↔ People affiliations
// ============================================================

extension TestudoStore {
    func affiliatedPeople(
        to containerID: UUID
    ) -> [Entity] {
        let personIDs =
            Set(
                data.memberships
                    .filter {
                        $0.containerEntityID
                            == containerID
                    }
                    .map(
                        \.memberEntityID
                    )
            )

        return data.entities
            .filter {
                $0.kind == .person
                && personIDs.contains(
                    $0.id
                )
            }
            .sorted {
                personSurnameSort(
                    $0,
                    $1
                )
            }
    }


    private func personSurnameSort(
        _ lhs: Entity,
        _ rhs: Entity
    ) -> Bool {
        let lhsProfile =
            personProfile(
                for:
                    lhs.id
            )

        let rhsProfile =
            personProfile(
                for:
                    rhs.id
            )

        let lhsLast =
            lhsProfile?
                .lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let rhsLast =
            rhsProfile?
                .lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        if
            !lhsLast.isEmpty
            || !rhsLast.isEmpty
        {
            let comparison =
                lhsLast
                    .localizedCaseInsensitiveCompare(
                        rhsLast
                    )

            if comparison != .orderedSame {
                return comparison
                    == .orderedAscending
            }
        }

        let lhsFirst =
            lhsProfile?
                .firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let rhsFirst =
            rhsProfile?
                .firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        if
            !lhsFirst.isEmpty
            || !rhsFirst.isEmpty
        {
            let comparison =
                lhsFirst
                    .localizedCaseInsensitiveCompare(
                        rhsFirst
                    )

            if comparison != .orderedSame {
                return comparison
                    == .orderedAscending
            }
        }

        return lhs.name
            .localizedCaseInsensitiveCompare(
                rhs.name
            )
            == .orderedAscending
    }


    func updateAffiliatedPeople(
        containerID: UUID,
        personIDs: Set<UUID>
    ) -> String? {
        guard
            let container =
                data.entities.first(
                    where: {
                        $0.id == containerID
                    }
                )
        else {
            return "Organization or Group not found."
        }

        guard
            container.kind == .organization
            || container.kind == .group
        else {
            return
                "People can only be affiliated with Organizations or Groups."
        }

        let validPeople =
            Set(
                data.entities
                    .filter {
                        $0.kind == .person
                    }
                    .map(\.id)
            )

        guard
            personIDs.isSubset(
                of:
                    validPeople
            )
        else {
            return "One or more People could not be found."
        }

        let oldPersonIDs =
            Set(
                data.memberships
                    .filter {
                        membership in

                        guard
                            membership
                                .containerEntityID
                                == containerID
                        else {
                            return false
                        }

                        return validPeople
                            .contains(
                                membership
                                    .memberEntityID
                            )
                    }
                    .map(
                        \.memberEntityID
                    )
            )

        let removed =
            oldPersonIDs
                .subtracting(
                    personIDs
                )

        let added =
            personIDs
                .subtracting(
                    oldPersonIDs
                )

        // Remove only Person affiliations to this container.
        // Group / Organization structure memberships are untouched.
        data.memberships.removeAll {
            membership in

            removed.contains(
                membership.memberEntityID
            )
            && membership.containerEntityID
                == containerID
        }

        for personID in added {
            let alreadyExists =
                data.memberships.contains {
                    $0.memberEntityID
                        == personID
                    && $0.containerEntityID
                        == containerID
                }

            if !alreadyExists {
                let hasAnyAffiliation =
                    data.memberships.contains {
                        $0.memberEntityID
                            == personID
                    }

                data.memberships.append(
                    EntityMembership(
                        memberEntityID:
                            personID,
                        containerEntityID:
                            containerID,
                        isPrimary:
                            !hasAnyAffiliation
                    )
                )
            }
        }

        let changedPeople =
            removed.union(
                added
            )

        for personID in changedPeople {
            normalizePrimaryMembership(
                for:
                    personID
            )

            if
                let index =
                    data.entities.firstIndex(
                        where: {
                            $0.id
                                == personID
                        }
                    )
            {
                data.entities[index]
                    .updatedAt =
                    Date()
            }
        }

        if
            let index =
                data.entities.firstIndex(
                    where: {
                        $0.id
                            == containerID
                    }
                )
        {
            data.entities[index]
                .updatedAt =
                Date()
        }

        save()

        return nil
    }


    func updatePersonAffiliations(
        personID: UUID,
        containerKind: EntityKind,
        containerIDs: Set<UUID>
    ) -> String? {
        guard
            data.entities.contains(
                where: {
                    $0.id == personID
                    && $0.kind == .person
                }
            )
        else {
            return "Person not found."
        }

        guard
            containerKind == .organization
            || containerKind == .group
        else {
            return "Invalid affiliation type."
        }

        let validContainerIDs =
            Set(
                data.entities
                    .filter {
                        $0.kind
                            == containerKind
                    }
                    .map(\.id)
            )

        guard
            containerIDs.isSubset(
                of:
                    validContainerIDs
            )
        else {
            return
                "One or more affiliations could not be found."
        }

        let preservedPrimaryID =
            data.memberships
                .first {
                    membership in

                    guard
                        membership
                            .memberEntityID
                            == personID,
                        membership
                            .isPrimary,
                        let container =
                            data.entities
                                .first(
                                    where: {
                                        $0.id
                                            == membership
                                                .containerEntityID
                                    }
                                )
                    else {
                        return false
                    }

                    return
                        container.kind
                            == containerKind
                }?
                .containerEntityID


        // Remove only affiliations of the requested kind.
        // The other kind remains untouched.
        data.memberships.removeAll {
            membership in

            guard
                membership.memberEntityID
                    == personID,
                let container =
                    data.entities.first(
                        where: {
                            $0.id
                                == membership
                                    .containerEntityID
                        }
                    )
            else {
                return false
            }

            return
                container.kind
                == containerKind
        }

        let ordered =
            containerIDs.sorted {
                $0.uuidString
                    < $1.uuidString
            }

        for containerID in ordered {
            data.memberships.append(
                EntityMembership(
                    memberEntityID:
                        personID,
                    containerEntityID:
                        containerID,
                    isPrimary:
                        preservedPrimaryID
                            == containerID
                )
            )
        }

        normalizePrimaryMembership(
            for:
                personID
        )

        if
            let index =
                data.entities.firstIndex(
                    where: {
                        $0.id
                            == personID
                    }
                )
        {
            data.entities[index]
                .updatedAt =
                Date()
        }

        save()

        return nil
    }


    private func normalizePrimaryMembership(
        for memberID: UUID
    ) {
        let indices =
            data.memberships.indices
                .filter {
                    data.memberships[$0]
                        .memberEntityID
                        == memberID
                }

        let primaryIndices =
            indices.filter {
                data.memberships[$0]
                    .isPrimary
            }

        // Zero Primary affiliations is now a valid state.
        // In that case the UI uses the hierarchy-based
        // automatic Organization fallback.
        guard
            let firstPrimary =
                primaryIndices.first
        else {
            return
        }

        // Defensive normalization: at most one explicit
        // Primary affiliation may exist.
        for index in indices {
            data.memberships[index]
                .isPrimary =
                    index
                    == firstPrimary
        }
    }
}



// ============================================================
// MARK: - Person Primary Affiliation
// ============================================================

extension TestudoStore
{
    func primaryAffiliation(
        for personID:
            UUID
    ) -> Entity?
    {
        guard
            let membership =
                data.memberships
                    .first(
                        where: {
                            $0.memberEntityID
                                == personID
                            && $0.isPrimary
                        }
                    )
        else {
            return nil
        }

        guard
            let entity =
                entity(
                    id:
                        membership
                            .containerEntityID
                ),
            entity.kind
                == .organization
            || entity.kind
                == .group
        else {
            return nil
        }

        return entity
    }


    func displayAffiliation(
        for personID:
            UUID
    ) -> Entity?
    {
        // ----------------------------------------------------
        // 1. Explicit Primary always wins.
        // ----------------------------------------------------

        if
            let explicit =
                primaryAffiliation(
                    for:
                        personID
                )
        {
            return explicit
        }


        let affiliations =
            containers(
                for:
                    personID
            )


        // ----------------------------------------------------
        // 2. Automatic fallback:
        //    choose the directly affiliated Organization that
        //    is highest in the Organization hierarchy.
        //
        //    Example:
        //
        //      IPGP
        //      ├── PSS
        //      └── SNO
        //
        //    If the Person is directly affiliated with all
        //    three, IPGP wins because its hierarchy depth is 0.
        // ----------------------------------------------------

        let organizations =
            affiliations
                .filter {
                    $0.kind
                        == .organization
                }

        if !organizations.isEmpty {
            return
                organizations
                    .sorted {
                        lhs,
                        rhs in

                        let lhsDepth =
                            organizationHierarchyDepth(
                                lhs.id
                            )

                        let rhsDepth =
                            organizationHierarchyDepth(
                                rhs.id
                            )

                        if
                            lhsDepth
                                != rhsDepth
                        {
                            return
                                lhsDepth
                                < rhsDepth
                        }

                        return
                            lhs.name
                                .localizedCaseInsensitiveCompare(
                                    rhs.name
                                )
                            == .orderedAscending
                    }
                    .first
        }


        // ----------------------------------------------------
        // 3. No Organization exists:
        //    retain useful behaviour by falling back to a Group.
        // ----------------------------------------------------

        return
            affiliations
                .filter {
                    $0.kind
                        == .group
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                    == .orderedAscending
                }
                .first
    }


    func affiliationDisplayName(
        _ affiliation:
            Entity
    ) -> String
    {
        let short =
            affiliation
                .shortName?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        if !short.isEmpty {
            return short
        }

        return affiliation.name
    }


    @discardableResult
    func setPrimaryAffiliation(
        personID:
            UUID,
        containerID:
            UUID?
    ) -> String?
    {
        guard
            data.entities
                .contains(
                    where: {
                        $0.id
                            == personID
                        && $0.kind
                            == .person
                    }
                )
        else {
            return
                "Person not found."
        }


        if
            let containerID
        {
            guard
                let affiliation =
                    entity(
                        id:
                            containerID
                    ),
                affiliation.kind
                    == .organization
                || affiliation.kind
                    == .group
            else {
                return
                    "Primary affiliation not found."
            }


            guard
                data.memberships
                    .contains(
                        where: {
                            $0.memberEntityID
                                == personID
                            && $0.containerEntityID
                                == containerID
                        }
                    )
            else {
                return
                    "The selected Primary must already be an affiliation of this Person."
            }
        }


        for index in
            data.memberships.indices
        {
            guard
                data.memberships[
                    index
                ]
                .memberEntityID
                    == personID
            else {
                continue
            }

            data.memberships[
                index
            ]
            .isPrimary =
                containerID != nil
                && data.memberships[
                    index
                ]
                .containerEntityID
                    == containerID
        }


        if
            let personIndex =
                data.entities
                    .firstIndex(
                        where: {
                            $0.id
                                == personID
                        }
                    )
        {
            data.entities[
                personIndex
            ]
            .updatedAt =
                Date()
        }

        save()

        return nil
    }


    private func organizationHierarchyDepth(
        _ organizationID:
            UUID,
        visited:
            Set<UUID> = []
    ) -> Int
    {
        if
            visited.contains(
                organizationID
            )
        {
            // Cycle protection. A malformed cyclic branch should
            // never outrank a valid top-level Organization.
            return 100_000
        }


        var nextVisited =
            visited

        nextVisited.insert(
            organizationID
        )


        let parentOrganizationIDs =
            data.memberships
                .filter {
                    $0.memberEntityID
                        == organizationID
                }
                .compactMap {
                    membership
                    -> UUID?
                    in

                    guard
                        let parent =
                            entity(
                                id:
                                    membership
                                        .containerEntityID
                            ),
                        parent.kind
                            == .organization
                    else {
                        return nil
                    }

                    return parent.id
                }


        guard
            !parentOrganizationIDs
                .isEmpty
        else {
            return 0
        }


        let parentDepth =
            parentOrganizationIDs
                .map {
                    organizationHierarchyDepth(
                        $0,
                        visited:
                            nextVisited
                    )
                }
                .min()
            ?? 0

        return
            parentDepth
            + 1
    }
}


// MARK: - Calendar Domain

extension TestudoStore {

    func calendarAccount(
        id: UUID?
    ) -> CalendarAccount? {
        guard let id else {
            return nil
        }

        return data.calendarAccounts.first {
            $0.id == id
        }
    }


    func dReportCalendar(
        id: UUID?
    ) -> TestudoCalendar? {
        guard let id else {
            return nil
        }

        return data.calendars.first {
            $0.id == id
        }
    }


    func calendarEvent(
        id: UUID?
    ) -> CalendarEvent? {
        guard let id else {
            return nil
        }

        return data.calendarEvents.first {
            $0.id == id
        }
    }


    func calendarEvents(
        overlapping start: Date,
        end: Date
    ) -> [CalendarEvent] {
        guard end > start else {
            return []
        }

        return data.calendarEvents
            .filter { event in
                guard
                    event.syncState != .pendingDelete,
                    event.status != .cancelled
                else {
                    return false
                }

                let effectiveEnd =
                    max(
                        event.endAt,
                        event.startAt
                            .addingTimeInterval(1)
                    )

                return
                    event.startAt < end
                    && effectiveEnd > start
            }
            .sorted {
                if $0.startAt != $1.startAt {
                    return $0.startAt < $1.startAt
                }

                return
                    $0.title
                        .localizedCaseInsensitiveCompare(
                            $1.title
                        )
                        == .orderedAscending
            }
    }


    func calendarEvents(
        on date: Date
    ) -> [CalendarEvent] {
        let calendar =
            Calendar.autoupdatingCurrent

        let start =
            calendar.startOfDay(
                for: date
            )

        guard
            let end =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: start
                )
        else {
            return []
        }

        return calendarEvents(
            overlapping: start,
            end: end
        )
    }


    func calendarEvents(
        forWorkItemID workItemID: UUID
    ) -> [CalendarEvent] {
        let eventIDs =
            Set(
                data.calendarEventWorkLinks
                    .filter {
                        $0.workItemID
                            == workItemID
                    }
                    .map(\.calendarEventID)
            )

        return data.calendarEvents
            .filter {
                eventIDs.contains($0.id)
                && $0.syncState
                    != .pendingDelete
            }
            .sorted {
                $0.startAt < $1.startAt
            }
    }


    func calendarEvents(
        forThemeID themeID: UUID
    ) -> [CalendarEvent] {
        let eventIDs =
            Set(
                data.calendarEventThemeLinks
                    .filter {
                        $0.themeID
                            == themeID
                    }
                    .map(\.calendarEventID)
            )

        return data.calendarEvents
            .filter {
                eventIDs.contains($0.id)
                && $0.syncState
                    != .pendingDelete
            }
            .sorted {
                $0.startAt < $1.startAt
            }
    }


    func linkedWorkItems(
        forCalendarEventID eventID: UUID
    ) -> [WorkItem] {
        let ids =
            Set(
                data.calendarEventWorkLinks
                    .filter {
                        $0.calendarEventID
                            == eventID
                    }
                    .map(\.workItemID)
            )

        return data.workItems
            .filter {
                ids.contains($0.id)
            }
    }


    func linkedThemes(
        forCalendarEventID eventID: UUID
    ) -> [Theme] {
        let ids =
            Set(
                data.calendarEventThemeLinks
                    .filter {
                        $0.calendarEventID
                            == eventID
                    }
                    .map(\.themeID)
            )

        return data.themes
            .filter {
                ids.contains($0.id)
            }
    }


    @discardableResult
    func createCalendarAccount(
        provider: CalendarProvider,
        displayName: String,
        email: String? = nil
    ) -> UUID? {
        let name =
            displayName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !name.isEmpty else {
            return nil
        }

        let account =
            CalendarAccount(
                provider: provider,
                displayName: name,
                email: email
            )

        data.calendarAccounts.append(
            account
        )

        save()

        return account.id
    }


    @discardableResult
    func createCalendar(
        name: String,
        accountID: UUID? = nil,
        externalID: String? = nil,
        timeZoneID: String? = nil
    ) -> UUID? {
        let cleaned =
            name
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleaned.isEmpty else {
            return nil
        }

        if
            let accountID,
            !data.calendarAccounts.contains(
                where: {
                    $0.id == accountID
                }
            )
        {
            return nil
        }

        let calendar =
            TestudoCalendar(
                accountID: accountID,
                externalID: externalID,
                name: cleaned,
                timeZoneID: timeZoneID
            )

        data.calendars.append(
            calendar
        )

        save()

        return calendar.id
    }


    @discardableResult
    func createCalendarEvent(
        calendarID: UUID? = nil,
        title: String,
        notes: String = "",
        location: String? = nil,
        startAt: Date,
        endAt: Date,
        isAllDay: Bool = false,
        startTimeZoneID: String? = nil,
        endTimeZoneID: String? = nil
    ) -> UUID? {
        let cleanedTitle =
            title
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanedTitle.isEmpty,
            endAt >= startAt
        else {
            return nil
        }

        if let calendarID {
            guard
                let targetCalendar =
                    data.calendars.first(
                        where: {
                            $0.id
                                == calendarID
                        }
                    ),
                !targetCalendar.isReadOnly
            else {
                return nil
            }
        }

        let syncState:
            CalendarSyncState

        if
            let calendarID,
            let calendar =
                dReportCalendar(
                    id: calendarID
                ),
            calendar.accountID != nil
        {
            syncState = .pendingCreate
        } else {
            syncState = .localOnly
        }

        let event =
            CalendarEvent(
                calendarID: calendarID,
                title: cleanedTitle,
                notes: notes,
                location: location,
                startAt: startAt,
                endAt: endAt,
                isAllDay: isAllDay,
                startTimeZoneID:
                    startTimeZoneID,
                endTimeZoneID:
                    endTimeZoneID,
                syncState: syncState
            )

        data.calendarEvents.append(
            event
        )

        save()

        return event.id
    }


    @discardableResult
    func updateCalendarEvent(
        _ event: CalendarEvent
    ) -> String? {
        guard
            let index =
                data.calendarEvents
                    .firstIndex(
                        where: {
                            $0.id == event.id
                        }
                    )
        else {
            return "Calendar Event not found."
        }

        var updated = event

        updated.title =
            updated.title
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !updated.title.isEmpty else {
            return "Calendar Event title cannot be empty."
        }

        guard
            updated.endAt >= updated.startAt
        else {
            return "End time cannot be earlier than start time."
        }

        if
            let calendarID =
                updated.calendarID,
            !data.calendars.contains(
                where: {
                    $0.id == calendarID
                }
            )
        {
            return "Calendar not found."
        }

        let existing =
            data.calendarEvents[index]


        if
            let calendarID =
                existing.calendarID,
            let calendar =
                dReportCalendar(
                    id:
                        calendarID
                ),
            calendar.isReadOnly
        {
            return
                "This Calendar Event comes from a read-only calendar."
        }

        guard
            existing.syncState
                != .pendingDelete
        else {
            return "This Calendar Event is pending deletion."
        }

        if updated.externalID != nil {
            updated.syncState =
                .pendingUpdate
        } else if
            let calendarID =
                updated.calendarID,
            let calendar =
                dReportCalendar(
                    id: calendarID
                ),
            calendar.accountID != nil
        {
            updated.syncState =
                .pendingCreate
        } else {
            updated.syncState =
                .localOnly
        }

        updated.updatedAt =
            Date()

        data.calendarEvents[index] =
            updated

        save()

        return nil
    }


    func deleteCalendarEvent(
        id: UUID
    ) {
        guard
            let index =
                data.calendarEvents
                    .firstIndex(
                        where: {
                            $0.id == id
                        }
                    )
        else {
            return
        }

        let event =
            data.calendarEvents[index]


        if
            let calendarID =
                event.calendarID,
            let calendar =
                dReportCalendar(
                    id:
                        calendarID
                ),
            calendar.isReadOnly
        {
            return
        }

        let remoteCalendar =
            event.calendarID
                .flatMap {
                    dReportCalendar(
                        id: $0
                    )
                }

        if
            event.externalID != nil,
            remoteCalendar?.accountID != nil
        {
            data.calendarEvents[index]
                .syncState =
                .pendingDelete

            data.calendarEvents[index]
                .updatedAt =
                Date()
        } else {
            data.calendarEvents.remove(
                at: index
            )

            data.calendarEventWorkLinks
                .removeAll {
                    $0.calendarEventID == id
                }

            data.calendarEventThemeLinks
                .removeAll {
                    $0.calendarEventID == id
                }
        }

        save()
    }


    @discardableResult
    func addCalendarEventWorkLink(
        calendarEventID: UUID,
        workItemID: UUID
    ) -> String? {
        guard
            calendarEvent(
                id: calendarEventID
            ) != nil
        else {
            return "Calendar Event not found."
        }

        guard
            workItem(
                id: workItemID
            ) != nil
        else {
            return "Work item not found."
        }

        let duplicate =
            data.calendarEventWorkLinks
                .contains {
                    $0.calendarEventID
                        == calendarEventID
                    && $0.workItemID
                        == workItemID
                }

        guard !duplicate else {
            return nil
        }

        data.calendarEventWorkLinks
            .append(
                CalendarEventWorkLink(
                    calendarEventID:
                        calendarEventID,
                    workItemID:
                        workItemID
                )
            )

        save()

        return nil
    }


    func removeCalendarEventWorkLink(
        calendarEventID: UUID,
        workItemID: UUID
    ) {
        data.calendarEventWorkLinks
            .removeAll {
                $0.calendarEventID
                    == calendarEventID
                && $0.workItemID
                    == workItemID
            }

        save()
    }


    @discardableResult
    func addCalendarEventThemeLink(
        calendarEventID: UUID,
        themeID: UUID
    ) -> String? {
        guard
            calendarEvent(
                id: calendarEventID
            ) != nil
        else {
            return "Calendar Event not found."
        }

        guard
            theme(
                id: themeID
            ) != nil
        else {
            return "Theme not found."
        }

        let duplicate =
            data.calendarEventThemeLinks
                .contains {
                    $0.calendarEventID
                        == calendarEventID
                    && $0.themeID
                        == themeID
                }

        guard !duplicate else {
            return nil
        }

        data.calendarEventThemeLinks
            .append(
                CalendarEventThemeLink(
                    calendarEventID:
                        calendarEventID,
                    themeID:
                        themeID
                )
            )

        save()

        return nil
    }


    func removeCalendarEventThemeLink(
        calendarEventID: UUID,
        themeID: UUID
    ) {
        data.calendarEventThemeLinks
            .removeAll {
                $0.calendarEventID
                    == calendarEventID
                && $0.themeID
                    == themeID
            }

        save()
    }
}


// MARK: - Calendar Event batch links

extension TestudoStore {
    @discardableResult
    func setCalendarEventWorkLinks(
        calendarEventID: UUID,
        workItemIDs: Set<UUID>
    ) -> String? {
        guard
            calendarEvent(
                id: calendarEventID
            ) != nil
        else {
            return "Calendar Event not found."
        }

        let validIDs =
            Set(
                data.workItems
                    .map(\.id)
            )

        guard
            workItemIDs.isSubset(
                of: validIDs
            )
        else {
            return "One or more Work items could not be found."
        }

        data.calendarEventWorkLinks
            .removeAll {
                $0.calendarEventID
                    == calendarEventID
            }

        for id in workItemIDs {
            data.calendarEventWorkLinks
                .append(
                    CalendarEventWorkLink(
                        calendarEventID:
                            calendarEventID,
                        workItemID:
                            id
                    )
                )
        }

        save()

        return nil
    }


    @discardableResult
    func setCalendarEventThemeLinks(
        calendarEventID: UUID,
        themeIDs: Set<UUID>
    ) -> String? {
        guard
            calendarEvent(
                id: calendarEventID
            ) != nil
        else {
            return "Calendar Event not found."
        }

        let validIDs =
            Set(
                data.themes
                    .map(\.id)
            )

        guard
            themeIDs.isSubset(
                of: validIDs
            )
        else {
            return "One or more Themes could not be found."
        }

        data.calendarEventThemeLinks
            .removeAll {
                $0.calendarEventID
                    == calendarEventID
            }

        for id in themeIDs {
            data.calendarEventThemeLinks
                .append(
                    CalendarEventThemeLink(
                        calendarEventID:
                            calendarEventID,
                        themeID:
                            id
                    )
                )
        }

        save()

        return nil
    }
}


// ============================================================
// MARK: - Read-only iCal subscriptions
// ============================================================

@MainActor
extension TestudoStore {

    func isReadOnlyCalendarEvent(
        _ event: CalendarEvent
    ) -> Bool {
        guard
            let calendar =
                dReportCalendar(
                    id:
                        event.calendarID
                )
        else {
            return false
        }

        return calendar.isReadOnly
    }


    func connectICalSubscription(
        name: String,
        secretAddress: String
    ) async -> (
        calendarID: UUID?,
        error: String?
    ) {
        let cleanedAddress =
            secretAddress
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            let url =
                URL(
                    string:
                        cleanedAddress
                ),
            let scheme =
                url.scheme?
                    .lowercased(),
            scheme == "https"
                || scheme == "http"
        else {
            return (
                nil,
                "Please enter a valid iCal URL."
            )
        }

        do {
            let (
                downloadedData,
                response
            ) =
                try await URLSession
                    .shared
                    .data(
                        from: url
                    )

            if
                let http =
                    response
                        as? HTTPURLResponse,
                !(200..<300)
                    .contains(
                        http.statusCode
                    )
            {
                return (
                    nil,
                    "The calendar server returned HTTP \(http.statusCode)."
                )
            }

            let parsed =
                try ICalendarParser
                    .parse(
                        data:
                            downloadedData
                    )

            let suppliedName =
                name
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            let calendarName =
                !suppliedName.isEmpty
                ? suppliedName
                : (
                    parsed.calendarName?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .nonEmpty
                    ?? "Subscribed Calendar"
                )

            let id =
                UUID()

            let keychainAccount =
                "ical-\(id.uuidString)"

            try CalendarSecretStore
                .save(
                    secret:
                        cleanedAddress,
                    account:
                        keychainAccount
                )

            let subscribedCalendar =
                TestudoCalendar(
                    id:
                        id,
                    sourceKind:
                        .iCalSubscription,
                    secretURLKeychainAccount:
                        keychainAccount,
                    name:
                        calendarName,
                    isEnabled:
                        true,
                    isReadOnly:
                        true,
                    lastSyncAt:
                        Date()
                )

            data.calendars.append(
                subscribedCalendar
            )

            mergeICalEvents(
                parsed.events,
                into:
                    id
            )

            save()

            return (
                id,
                nil
            )

        } catch {
            return (
                nil,
                error.localizedDescription
            )
        }
    }


    func syncICalCalendar(
        id: UUID
    ) async -> String? {
        guard
            let index =
                data.calendars
                    .firstIndex(
                        where: {
                            $0.id == id
                        }
                    )
        else {
            return "Calendar not found."
        }

        let calendar =
            data.calendars[index]

        guard
            calendar.sourceKind
                == .iCalSubscription,
            calendar.isReadOnly,
            let keychainAccount =
                calendar
                    .secretURLKeychainAccount
        else {
            return "This is not an iCal subscription."
        }

        guard
            let secretAddress =
                CalendarSecretStore
                    .read(
                        account:
                            keychainAccount
                    ),
            let url =
                URL(
                    string:
                        secretAddress
                )
        else {
            data.calendars[index]
                .lastSyncError =
                "The Secret iCal address is missing from Keychain."

            save()

            return
                data.calendars[index]
                    .lastSyncError
        }

        do {
            let (
                downloaded,
                response
            ) =
                try await URLSession
                    .shared
                    .data(
                        from: url
                    )

            if
                let http =
                    response
                        as? HTTPURLResponse,
                !(200..<300)
                    .contains(
                        http.statusCode
                    )
            {
                throw NSError(
                    domain:
                        "Testudo.iCal",
                    code:
                        http.statusCode,
                    userInfo:
                        [
                            NSLocalizedDescriptionKey:
                                "Calendar server returned HTTP \(http.statusCode)."
                        ]
                )
            }

            let parsed =
                try ICalendarParser
                    .parse(
                        data:
                            downloaded
                    )

            mergeICalEvents(
                parsed.events,
                into:
                    id
            )

            if
                let freshIndex =
                    data.calendars
                        .firstIndex(
                            where: {
                                $0.id == id
                            }
                        )
            {
                data.calendars[
                    freshIndex
                ]
                .lastSyncAt =
                    Date()

                data.calendars[
                    freshIndex
                ]
                .lastSyncError =
                    nil
            }

            save()

            return nil

        } catch {
            if
                let freshIndex =
                    data.calendars
                        .firstIndex(
                            where: {
                                $0.id == id
                            }
                        )
            {
                data.calendars[
                    freshIndex
                ]
                .lastSyncError =
                    error.localizedDescription
            }

            save()

            return error.localizedDescription
        }
    }


    func syncAllICalCalendars()
        async -> [String]
    {
        let ids =
            data.calendars
                .filter {
                    $0.sourceKind
                        == .iCalSubscription
                    && $0.isEnabled
                }
                .map(\.id)

        var errors:
            [String] = []

        for id in ids {
            if
                let error =
                    await syncICalCalendar(
                        id: id
                    )
            {
                errors.append(
                    error
                )
            }
        }

        return errors
    }


    func disconnectICalCalendar(
        id: UUID
    ) {
        guard
            let calendar =
                dReportCalendar(
                    id: id
                ),
            calendar.sourceKind
                == .iCalSubscription
        else {
            return
        }

        if
            let key =
                calendar
                    .secretURLKeychainAccount
        {
            CalendarSecretStore
                .delete(
                    account: key
                )
        }

        let eventIDs =
            Set(
                data.calendarEvents
                    .filter {
                        $0.calendarID
                            == id
                    }
                    .map(\.id)
            )

        data.calendarEventWorkLinks
            .removeAll {
                eventIDs.contains(
                    $0.calendarEventID
                )
            }

        data.calendarEventThemeLinks
            .removeAll {
                eventIDs.contains(
                    $0.calendarEventID
                )
            }

        data.calendarEvents
            .removeAll {
                $0.calendarID == id
            }

        data.calendars
            .removeAll {
                $0.id == id
            }

        save()
    }


    private func mergeICalEvents(
        _ imported:
            [ParsedICalendarEvent],
        into calendarID:
            UUID
    ) {
        let incomingIDs =
            Set(
                imported.map {
                    $0.externalIdentity
                }
            )

        let staleEvents =
            data.calendarEvents
                .filter {
                    $0.calendarID
                        == calendarID
                    && $0.externalID
                        != nil
                    && !incomingIDs
                        .contains(
                            $0.externalID!
                        )
                }

        let staleIDs =
            Set(
                staleEvents.map(\.id)
            )

        if !staleIDs.isEmpty {
            data.calendarEventWorkLinks
                .removeAll {
                    staleIDs.contains(
                        $0.calendarEventID
                    )
                }

            data.calendarEventThemeLinks
                .removeAll {
                    staleIDs.contains(
                        $0.calendarEventID
                    )
                }

            data.calendarEvents
                .removeAll {
                    staleIDs.contains(
                        $0.id
                    )
                }
        }

        for source in imported {
            if
                let index =
                    data.calendarEvents
                        .firstIndex(
                            where: {
                                $0.calendarID
                                    == calendarID
                                && $0.externalID
                                    == source
                                        .externalIdentity
                            }
                        )
            {
                var existing =
                    data.calendarEvents[index]

                existing.iCalUID =
                    source.uid

                existing.title =
                    source.title

                existing.notes =
                    source.notes

                existing.location =
                    source.location

                existing.startAt =
                    source.startAt

                existing.endAt =
                    source.endAt

                existing.isAllDay =
                    source.isAllDay

                existing.startTimeZoneID =
                    source
                        .startTimeZoneID

                existing.endTimeZoneID =
                    source
                        .endTimeZoneID

                existing.status =
                    source.status

                existing.recurrenceRules =
                    source.recurrenceRules

                existing.externalURL =
                    source.externalURL

                existing.externalCreatedAt =
                    source.createdAt

                existing.externalUpdatedAt =
                    source.updatedAt

                existing.syncState =
                    .synced

                existing.lastSyncedAt =
                    Date()

                existing.updatedAt =
                    Date()

                data.calendarEvents[index] =
                    existing

            } else {
                data.calendarEvents
                    .append(
                        CalendarEvent(
                            calendarID:
                                calendarID,
                            externalID:
                                source
                                    .externalIdentity,
                            iCalUID:
                                source.uid,
                            externalURL:
                                source.externalURL,
                            title:
                                source.title,
                            notes:
                                source.notes,
                            location:
                                source.location,
                            startAt:
                                source.startAt,
                            endAt:
                                source.endAt,
                            isAllDay:
                                source.isAllDay,
                            startTimeZoneID:
                                source
                                    .startTimeZoneID,
                            endTimeZoneID:
                                source
                                    .endTimeZoneID,
                            status:
                                source.status,
                            recurrenceRules:
                                source
                                    .recurrenceRules,
                            syncState:
                                .synced,
                            externalCreatedAt:
                                source.createdAt,
                            externalUpdatedAt:
                                source.updatedAt,
                            lastSyncedAt:
                                Date()
                        )
                    )
            }
        }
    }
}

// ============================================================
// MARK: - Work Item Theme Membership
// ============================================================

extension TestudoStore {

    func workThemes(
        for workItemID: UUID
    ) -> [Theme] {
        guard
            let item =
                workItem(
                    id:
                        workItemID
                )
        else {
            return []
        }

        let ids:
            [UUID]

        if let explicit =
            item.themeIDs
        {
            ids =
                explicit

        } else if let legacy =
            item.themeID
        {
            ids =
                [legacy]

        } else {
            ids =
                []
        }

        let idSet =
            Set(ids)

        return data.themes
            .filter {
                idSet.contains(
                    $0.id
                )
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }


    func workItem(
        _ item: WorkItem,
        belongsToThemeID themeID: UUID
    ) -> Bool {
        if let explicit =
            item.themeIDs
        {
            return explicit
                .contains(
                    themeID
                )
        }

        return
            item.themeID
            == themeID
    }


    @discardableResult
    func setWorkThemes(
        workItemID: UUID,
        themeIDs: Set<UUID>
    ) -> String? {
        guard
            let index =
                data.workItems
                    .firstIndex(
                        where: {
                            $0.id
                                == workItemID
                        }
                    )
        else {
            return
                "Work item not found."
        }

        let validIDs =
            Set(
                data.themes
                    .map(\.id)
            )

        guard
            themeIDs
                .isSubset(
                    of:
                        validIDs
                )
        else {
            return
                "One or more Themes no longer exist."
        }

        let orderedIDs =
            data.themes
                .filter {
                    themeIDs
                        .contains(
                            $0.id
                        )
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }
                .map(\.id)

        data.workItems[index]
            .themeIDs =
            orderedIDs

        /*
         Keep the old single-theme field populated
         with one selected Theme for compatibility
         with code that has not yet migrated to
         multi-Theme membership.

         It is NOT the authoritative membership
         once themeIDs is non-nil.
        */
        data.workItems[index]
            .themeID =
            orderedIDs.first

        data.workItems[index]
            .updatedAt =
            Date()

        save()

        return nil
    }
}




// ============================================================
// MARK: - Work Archive Semantics
// ============================================================

extension TestudoStore {

    @discardableResult
    func closeTopLevelTask(
        workItemID:
            UUID
    ) -> String? {

        guard
            let index =
                data.workItems
                    .firstIndex(
                        where: {
                            $0.id
                                == workItemID
                        }
                    ),
            data.workItems[index].kind
                == .task
        else {
            return
                "Task not found."
        }

        guard
            data.workItems[index]
                .parentWorkItemID == nil
        else {
            return
                "Only top-level Tasks can be Closed."
        }

        guard
            data.workItems[index]
                .closedAt == nil
        else {
            return
                "This Task is already Closed."
        }

        guard
            data.workItems[index].status
                == .completed
            || data.workItems[index].status
                == .discontinued
        else {
            return
                "Complete or Discontinue this Task before closing it."
        }

        let now =
            Date()

        let timeZoneID =
            TestudoTime
                .deviceTimeZoneID

        data.workItems[index]
            .closedAt =
            now

        data.workItems[index]
            .closedTimeZoneID =
            timeZoneID

        data.workItems[index]
            .updatedAt =
            now

        data.workItems[index]
            .updatedByMembershipID =
            currentEnvironmentMembership?
                .id

        data.workItems[index]
            .updatedTimeZoneID =
            timeZoneID

        let task =
            data.workItems[index]

        appendTaskLifecycleHistory(
            workItemID:
                workItemID,
            kind:
                .closed,
            timestamp:
                now,
            text:
                "\(taskHistoryTitle(task)) closed and moved to Archive",
            newValue:
                "closed",
            valueTimeZoneID:
                timeZoneID
        )

        save()

        return nil
    }


    @discardableResult
    func reopenTopLevelTask(
        workItemID:
            UUID
    ) -> String? {

        guard
            let index =
                data.workItems
                    .firstIndex(
                        where: {
                            $0.id
                                == workItemID
                        }
                    ),
            data.workItems[index].kind
                == .task,
            data.workItems[index]
                .parentWorkItemID == nil
        else {
            return
                "Only a top-level Task can be reopened."
        }

        guard
            data.workItems[index]
                .closedAt != nil
        else {
            return
                "This Task is not Closed."
        }

        let now =
            Date()

        let timeZoneID =
            TestudoTime
                .deviceTimeZoneID

        let retainedStatus =
            data.workItems[index]
                .status

        data.workItems[index]
            .closedAt =
            nil

        data.workItems[index]
            .closedTimeZoneID =
            nil

        data.workItems[index]
            .updatedAt =
            now

        data.workItems[index]
            .updatedByMembershipID =
            currentEnvironmentMembership?
                .id

        data.workItems[index]
            .updatedTimeZoneID =
            timeZoneID

        let task =
            data.workItems[index]

        appendTaskLifecycleHistory(
            workItemID:
                workItemID,
            kind:
                .reopened,
            timestamp:
                now,
            text:
                "\(taskHistoryTitle(task)) reopened from Archive",
            previousValue:
                "closed",
            newValue:
                retainedStatus?
                    .rawValue
        )

        save()

        return nil
    }


    func archivedRootTasks()
        -> [WorkItem]
    {
        data.workItems
            .filter {
                $0.kind == .task
                && $0.parentWorkItemID == nil
                && $0.closedAt != nil
            }
            .sorted {
                (
                    $0.closedAt
                    ?? .distantPast
                )
                >
                (
                    $1.closedAt
                    ?? .distantPast
                )
            }
    }


    func archivedRootID(
        for item:
            WorkItem
    ) -> UUID? {

        var current:
            WorkItem? =
            item

        var visited =
            Set<UUID>()

        while let work = current {

            guard
                !visited.contains(
                    work.id
                )
            else {
                return nil
            }

            visited.insert(
                work.id
            )

            if
                work.kind == .task,
                work.parentWorkItemID == nil,
                work.closedAt != nil
            {
                return
                    work.id
            }

            guard
                let parentID =
                    work.parentWorkItemID
            else {
                return nil
            }

            current =
                workItem(
                    id:
                        parentID
                )
        }

        return nil
    }


    func isArchivedWorkItem(
        _ item:
            WorkItem
    ) -> Bool {

        archivedRootID(
            for:
                item
        ) != nil
    }


    var activeWorkItems:
        [WorkItem]
    {
        data.workItems
            .filter {
                !isArchivedWorkItem(
                    $0
                )
            }
    }
}


// ============================================================
// MARK: - Theme ↔ People / Groups / Organizations
// ============================================================

extension TestudoStore {

    func relatedEntities(
        forThemeID themeID: UUID
    ) -> [Entity] {
        let ids =
            Set(
                data
                    .themeEntityRelationships
                    .filter {
                        $0.themeID
                            == themeID
                    }
                    .map(
                        \.entityID
                    )
            )

        return data.entities
            .filter {
                ids.contains(
                    $0.id
                )
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }


    @discardableResult
    func setThemeRelatedEntities(
        themeID: UUID,
        entityIDs: Set<UUID>
    ) -> String? {
        guard
            let themeIndex =
                data.themes
                    .firstIndex(
                        where: {
                            $0.id
                                == themeID
                        }
                    )
        else {
            return
                "Theme not found."
        }

        let knownEntityIDs =
            Set(
                data.entities
                    .map(
                        \.id
                    )
            )

        guard
            entityIDs
                .isSubset(
                    of:
                        knownEntityIDs
                )
        else {
            return
                "One or more related entities could not be found."
        }

        let existing =
            data
                .themeEntityRelationships
                .filter {
                    $0.themeID
                        == themeID
                }

        let now =
            Date()

        var rebuilt:
            [ThemeEntityRelationship] = []

        let orderedEntities =
            data.entities
                .filter {
                    entityIDs
                        .contains(
                            $0.id
                        )
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }

        for entity in orderedEntities {
            if
                let old =
                    existing.first(
                        where: {
                            $0.entityID
                                == entity.id
                        }
                    )
            {
                rebuilt.append(
                    old
                )
            } else {
                rebuilt.append(
                    ThemeEntityRelationship(
                        themeID:
                            themeID,
                        entityID:
                            entity.id,
                        createdAt:
                            now
                    )
                )
            }
        }

        data
            .themeEntityRelationships
            .removeAll {
                $0.themeID
                    == themeID
            }

        data
            .themeEntityRelationships
            .append(
                contentsOf:
                    rebuilt
            )

        data.themes[themeIndex]
            .updatedAt =
            now

        save()

        return nil
    }
}



extension TestudoStore {

    var peopleAvailableForEnvironmentMembershipLink:
        [Entity]
    {
        guard
            let environmentID =
                activeEnvironmentID
        else {
            return []
        }

        let linkedPersonIDs =
            Set(
                data.environmentMemberships
                    .filter {
                        $0.environmentID
                            == environmentID
                    }
                    .compactMap {
                        $0.personEntityID
                    }
            )

        return
            data.entities
                .filter {
                    $0.kind
                        == .person
                    && !linkedPersonIDs
                        .contains(
                            $0.id
                        )
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }
    }


    @discardableResult
    func addEnvironmentMembership(
        firstName:
            String,
        lastName:
            String,
        directoryUserIdentifier:
            String,
        personEntityID:
            UUID?,
        role:
            EnvironmentRole,
        isActive:
            Bool
    ) -> (
        membershipID:
            UUID?,
        error:
            String?
    ) {
        guard
            currentEnvironmentUserIsAdministrator
        else {
            return (
                nil,
                "Environment Administrator rights are required."
            )
        }

        guard
            let environmentID =
                activeEnvironmentID
        else {
            return (
                nil,
                "No Work Environment is active."
            )
        }


        let cleanedIdentifier =
            directoryUserIdentifier
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanedIdentifier.isEmpty
        else {
            return (
                nil,
                "Username is required."
            )
        }


        if !cleanedIdentifier.isEmpty {
            let duplicateIdentifier =
                data.environmentMemberships
                    .contains {
                        guard
                            $0.environmentID
                                == environmentID,
                            let existing =
                                $0.directoryUserIdentifier
                        else {
                            return false
                        }

                        return
                            existing
                                .caseInsensitiveCompare(
                                    cleanedIdentifier
                                )
                                == .orderedSame
                    }

            guard
                !duplicateIdentifier
            else {
                return (
                    nil,
                    "That username is already used by another Environment membership."
                )
            }
        }


        var resolvedFirstName =
            firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        var resolvedLastName =
            lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        if let personEntityID {
            guard
                let person =
                    data.entities.first(
                        where: {
                            $0.id
                                == personEntityID
                            && $0.kind
                                == .person
                        }
                    )
            else {
                return (
                    nil,
                    "The selected Person no longer exists."
                )
            }

            let alreadyLinked =
                data.environmentMemberships
                    .contains {
                        $0.environmentID
                            == environmentID
                        && $0.personEntityID
                            == personEntityID
                    }

            guard
                !alreadyLinked
            else {
                return (
                    nil,
                    "That Person is already linked to an Environment membership."
                )
            }


            if
                let profile =
                    data.personProfiles.first(
                        where: {
                            $0.entityID
                                == personEntityID
                        }
                    )
            {
                resolvedFirstName =
                    profile.firstName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                resolvedLastName =
                    profile.lastName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
            }


            if
                resolvedFirstName.isEmpty
                && resolvedLastName.isEmpty
            {
                resolvedFirstName =
                    person.name
            }
        }


        guard
            !resolvedFirstName.isEmpty
            || !resolvedLastName.isEmpty
        else {
            return (
                nil,
                "A member name is required."
            )
        }


        let membership =
            EnvironmentMembership(
                environmentID:
                    environmentID,
                localUserProfileID:
                    nil,
                personEntityID:
                    personEntityID,
                directoryUserIdentifier:
                    cleanedIdentifier.isEmpty
                    ? nil
                    : cleanedIdentifier,
                firstName:
                    resolvedFirstName,
                lastName:
                    resolvedLastName,
                role:
                    role,
                isActive:
                    isActive,
                createdAt:
                    Date(),
                lastAccessAt:
                    nil
            )

        data.environmentMemberships
            .append(
                membership
            )

        save()

        return (
            membership.id,
            nil
        )
    }
}


// ============================================================
// MARK: - Environment-scoped local credentials
// ============================================================

extension TestudoStore {

    private var environmentCredentialStoreURL:
        URL?
    {
        guard
            fileURL.lastPathComponent
                == "EnvironmentData.json"
        else {
            return nil
        }

        return
            fileURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "EnvironmentCredentials.json"
                )
    }


    private func loadEnvironmentCredentialStore()
        -> EnvironmentCredentialStore
    {
        guard
            let environmentID =
                activeEnvironmentID
        else {
            return
                EnvironmentCredentialStore(
                    environmentID:
                        UUID()
                )
        }

        guard
            let url =
                environmentCredentialStoreURL,
            FileManager.default
                .fileExists(
                    atPath:
                        url.path
                )
        else {
            return
                EnvironmentCredentialStore(
                    environmentID:
                        environmentID
                )
        }


        do {
            let raw =
                try Data(
                    contentsOf:
                        url
                )

            let decoded =
                try JSONDecoder()
                    .decode(
                        EnvironmentCredentialStore.self,
                        from:
                            raw
                    )

            guard
                decoded.environmentID
                    == environmentID
            else {
                return
                    EnvironmentCredentialStore(
                        environmentID:
                            environmentID
                    )
            }

            return decoded

        } catch {
            return
                EnvironmentCredentialStore(
                    environmentID:
                        environmentID
                )
        }
    }


    @discardableResult
    private func saveEnvironmentCredentialStore(
        _ credentialStore:
            EnvironmentCredentialStore
    ) -> String? {
        guard
            let url =
                environmentCredentialStoreURL
        else {
            return
                "The Environment credential store is unavailable."
        }

        do {
            let encoder =
                JSONEncoder()

            encoder.outputFormatting =
                [
                    .prettyPrinted,
                    .sortedKeys
                ]

            let raw =
                try encoder.encode(
                    credentialStore
                )

            try FileManager.default
                .createDirectory(
                    at:
                        url.deletingLastPathComponent(),
                    withIntermediateDirectories:
                        true
                )

            try raw.write(
                to:
                    url,
                options:
                    .atomic
            )

            return nil

        } catch {
            return
                "The Environment credential store could not be saved."
        }
    }


    func environmentMembershipHasPassword(
        id membershipID:
            UUID
    ) -> Bool {

        return
            loadEnvironmentCredentialStore()
                .credentials
                .contains {
                    $0.membershipID
                        == membershipID
                }
    }


    private func environmentCredential(
        for membershipID:
            UUID
    ) -> EnvironmentCredential? {

        return
            loadEnvironmentCredentialStore()
                .credentials
                .first {
                    $0.membershipID
                        == membershipID
                }
    }


    @discardableResult
    func setEnvironmentMembershipPassword(
        membershipID:
            UUID,
        newPassword:
            String
    ) -> String? {
        guard
            currentEnvironmentUserIsAdministrator
        else {
            return
                "Environment Administrator rights are required."
        }

        guard
            let environmentID =
                activeEnvironmentID,
            data.environmentMemberships
                .contains(
                    where: {
                        $0.id
                            == membershipID
                        && $0.environmentID
                            == environmentID
                    }
                )
        else {
            return
                "Environment membership not found."
        }


        guard
            newPassword.count
                >= 8
        else {
            return
                "Password must contain at least 8 characters."
        }


        let hash:
            (
                saltBase64:
                    String,
                hashBase64:
                    String,
                iterations:
                    Int
            )

        do {
            hash =
                try PasswordHasher
                    .createHash(
                        password:
                            newPassword
                    )

        } catch {
            return
                "The password could not be secured."
        }


        var credentialStore =
            loadEnvironmentCredentialStore()

        let now =
            Date()


        if
            let index =
                credentialStore
                    .credentials
                    .firstIndex(
                        where: {
                            $0.membershipID
                                == membershipID
                        }
                    )
        {
            credentialStore
                .credentials[index]
                .passwordSaltBase64 =
                    hash.saltBase64

            credentialStore
                .credentials[index]
                .passwordHashBase64 =
                    hash.hashBase64

            credentialStore
                .credentials[index]
                .passwordIterations =
                    hash.iterations

            credentialStore
                .credentials[index]
                .updatedAt =
                    now

        } else {
            credentialStore
                .credentials
                .append(
                    EnvironmentCredential(
                        membershipID:
                            membershipID,
                        passwordSaltBase64:
                            hash.saltBase64,
                        passwordHashBase64:
                            hash.hashBase64,
                        passwordIterations:
                            hash.iterations,
                        createdAt:
                            now,
                        updatedAt:
                            now
                    )
                )
        }


        return
            saveEnvironmentCredentialStore(
                credentialStore
            )
    }
}


// ============================================================
// MARK: - Environment manifest architecture migration
// ============================================================

extension TestudoStore {

    private func migrateActiveEnvironmentManifestIdentityIfNeeded() {
        guard
            fileURL.lastPathComponent
                == "EnvironmentData.json",
            let environmentID =
                applicationData.activeEnvironmentID,
            let environment =
                applicationData
                    .workEnvironments
                    .first(
                        where: {
                            $0.id
                                == environmentID
                        }
                    )
        else {
            return
        }


        let manifestURL =
            fileURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )


        guard
            FileManager.default
                .fileExists(
                    atPath:
                        manifestURL.path
                )
        else {
            return
        }


        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601


        guard
            let raw =
                try? Data(
                    contentsOf:
                        manifestURL
                ),
            var manifest =
                try? decoder.decode(
                    EnvironmentManifest.self,
                    from:
                        raw
                ),
            manifest.environmentID
                == environmentID
        else {
            return
        }


        var changed =
            false


        if manifest.schemaVersion < 2 {
            manifest.schemaVersion =
                2

            changed =
                true
        }


        if manifest.identityProvider == nil {
            manifest.identityProvider =
                environment.identityProvider

            manifest.updatedAt =
                Date()

            changed =
                true
        }


        guard changed else {
            return
        }


        let encoder =
            JSONEncoder()

        encoder.outputFormatting =
            [
                .prettyPrinted,
                .sortedKeys
            ]

        encoder.dateEncodingStrategy =
            .iso8601


        if
            let encoded =
                try? encoder.encode(
                    manifest
                )
        {
            try? encoded.write(
                to:
                    manifestURL,
                options:
                    .atomic
            )
        }
    }
}



// ============================================================
// MARK: - Known Environment manifest migration
//
// ApplicationData knows the storage location of every registered
// Environment. Portable manifest migrations therefore do not
// depend on that Environment already being open.
// ============================================================

extension TestudoStore {

    private func migrateKnownEnvironmentManifestsIfNeeded() {
        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601


        let encoder =
            JSONEncoder()

        encoder.outputFormatting =
            [
                .prettyPrinted,
                .sortedKeys
            ]

        encoder.dateEncodingStrategy =
            .iso8601


        for environment in
            applicationData
                .workEnvironments
        {
            guard
                let rawPath =
                    environment
                        .storage?
                        .path?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                !rawPath.isEmpty
            else {
                continue
            }


            let manifestURL =
                URL(
                    fileURLWithPath:
                        rawPath,
                    isDirectory:
                        true
                )
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )


            guard
                FileManager.default
                    .fileExists(
                        atPath:
                            manifestURL.path
                    ),
                let raw =
                    try? Data(
                        contentsOf:
                            manifestURL
                    ),
                var manifest =
                    try? decoder.decode(
                        EnvironmentManifest.self,
                        from:
                            raw
                    ),
                manifest.environmentID
                    == environment.id
            else {
                continue
            }


            var changed =
                false


            if manifest.schemaVersion < 2 {
                manifest.schemaVersion =
                    2

                changed =
                    true
            }


            if manifest.identityProvider == nil {
                manifest.identityProvider =
                    environment
                        .identityProvider

                changed =
                    true
            }


            guard changed else {
                continue
            }


            manifest.updatedAt =
                Date()


            guard
                let encoded =
                    try? encoder.encode(
                        manifest
                    )
            else {
                continue
            }


            try? encoded.write(
                to:
                    manifestURL,
                options:
                    .atomic
            )
        }
    }
}



// ============================================================
// MARK: - Person / Environment Membership bridge
// ============================================================

extension TestudoStore {

    func environmentMembership(
        linkedToPerson personEntityID:
            UUID
    ) -> EnvironmentMembership? {
        guard
            let environmentID =
                activeEnvironmentID
        else {
            return nil
        }

        return
            data
                .environmentMemberships
                .first {
                    $0.environmentID
                        == environmentID
                    && $0.personEntityID
                        == personEntityID
                }
    }
}


// ============================================================
// MARK: - Environment schema 7 -> 8 identity migration
//
// Schema 8 permanently removes the legacy users array and the
// legacy account audit UUIDs.
//
// The migration operates on raw JSON before TestudoData is decoded,
// so the legacy Swift account model no longer needs to exist.
// ============================================================

extension TestudoStore {

    private static func migrateEnvironmentIdentityToSchema8IfNeeded(
        at fileURL:
            URL
    ) throws {

        guard
            fileURL.lastPathComponent
                == "EnvironmentData.json",
            FileManager.default
                .fileExists(
                    atPath:
                        fileURL.path
                )
        else {
            return
        }


        let raw =
            try Data(
                contentsOf:
                    fileURL
            )


        guard
            var root =
                try JSONSerialization
                    .jsonObject(
                        with:
                            raw
                    )
                    as? [String: Any]
        else {
            return
        }


        let schemaVersion =
            (
                root[
                    "schemaVersion"
                ]
                as? NSNumber
            )?
            .intValue
            ?? 1


        guard schemaVersion < 8 else {
            return
        }


        guard schemaVersion >= 7 else {
            throw NSError(
                domain:
                    "Testudo.SchemaMigration",
                code:
                    8,
                userInfo:
                    [
                        NSLocalizedDescriptionKey:
                            "This Environment predates schema 7 and must first be migrated by an earlier Testudo build."
                    ]
            )
        }


        let memberships =
            root[
                "environmentMemberships"
            ]
            as? [[String: Any]]
            ?? []


        let legacyUsers =
            root[
                "users"
            ]
            as? [[String: Any]]
            ?? []


        var membershipByIdentifier:
            [String: String] = [:]

        var membershipByPerson:
            [String: String] = [:]


        for membership in memberships {

            guard
                let membershipID =
                    membership["id"]
                    as? String
            else {
                continue
            }


            if
                let identifier =
                    membership[
                        "directoryUserIdentifier"
                    ]
                    as? String
            {
                let key =
                    identifier
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .lowercased()

                if !key.isEmpty {
                    membershipByIdentifier[
                        key
                    ] =
                        membershipID
                }
            }


            if
                let personID =
                    membership[
                        "personEntityID"
                    ]
                    as? String
            {
                membershipByPerson[
                    personID
                ] =
                    membershipID
            }
        }


        var legacyUserToMembership:
            [String: String] = [:]


        for legacyUser in legacyUsers {

            guard
                let legacyUserID =
                    legacyUser["id"]
                    as? String
            else {
                continue
            }


            let username =
                (
                    legacyUser[
                        "username"
                    ]
                    as? String
                    ?? ""
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()


            let personID =
                legacyUser[
                    "personEntityID"
                ]
                as? String


            let membershipID =
                membershipByIdentifier[
                    username
                ]
                ?? (
                    personID.flatMap {
                        membershipByPerson[
                            $0
                        ]
                    }
                )


            guard let membershipID else {
                throw NSError(
                    domain:
                        "Testudo.SchemaMigration",
                    code:
                        81,
                    userInfo:
                        [
                            NSLocalizedDescriptionKey:
                                "A legacy Environment user cannot be mapped to an Environment membership."
                        ]
                )
            }


            legacyUserToMembership[
                legacyUserID
            ] =
                membershipID
        }


        func membershipID(
            forLegacyUserID legacyUserID:
                String?
        ) throws -> String? {

            guard
                let legacyUserID
            else {
                return nil
            }


            guard
                let membershipID =
                    legacyUserToMembership[
                        legacyUserID
                    ]
            else {
                throw NSError(
                    domain:
                        "Testudo.SchemaMigration",
                    code:
                        82,
                    userInfo:
                        [
                            NSLocalizedDescriptionKey:
                                "A historical user identity cannot be mapped to an Environment membership."
                        ]
                )
            }


            return membershipID
        }


        // ----------------------------------------------------
        // WorkItem audit migration
        // ----------------------------------------------------

        var workItems =
            root[
                "workItems"
            ]
            as? [[String: Any]]
            ?? []


        for index in workItems.indices {

            let createdLegacyID =
                workItems[index][
                    "createdByUserID"
                ]
                as? String

            let updatedLegacyID =
                workItems[index][
                    "updatedByUserID"
                ]
                as? String


            if
                workItems[index][
                    "createdByMembershipID"
                ]
                == nil,
                let migrated =
                    try membershipID(
                        forLegacyUserID:
                            createdLegacyID
                    )
            {
                workItems[index][
                    "createdByMembershipID"
                ] =
                    migrated
            }


            if
                workItems[index][
                    "updatedByMembershipID"
                ]
                == nil,
                let migrated =
                    try membershipID(
                        forLegacyUserID:
                            updatedLegacyID
                    )
            {
                workItems[index][
                    "updatedByMembershipID"
                ] =
                    migrated
            }


            workItems[index]
                .removeValue(
                    forKey:
                        "createdByUserID"
                )

            workItems[index]
                .removeValue(
                    forKey:
                        "updatedByUserID"
                )
        }


        root[
            "workItems"
        ] =
            workItems


        // ----------------------------------------------------
        // History audit migration
        // ----------------------------------------------------

        var historyEvents =
            root[
                "historyEvents"
            ]
            as? [[String: Any]]
            ?? []


        for index in historyEvents.indices {

            let legacyID =
                historyEvents[index][
                    "actorUserID"
                ]
                as? String


            if
                historyEvents[index][
                    "actorMembershipID"
                ]
                == nil,
                let migrated =
                    try membershipID(
                        forLegacyUserID:
                            legacyID
                    )
            {
                historyEvents[index][
                    "actorMembershipID"
                ] =
                    migrated
            }


            historyEvents[index]
                .removeValue(
                    forKey:
                        "actorUserID"
                )
        }


        root[
            "historyEvents"
        ] =
            historyEvents


        // ----------------------------------------------------
        // Credential migration
        //
        // Existing Environment credentials always win.
        // Missing credentials can still be copied from schema-7
        // user hashes before the legacy users array disappears.
        // ----------------------------------------------------

        if !legacyUsers.isEmpty {

            let credentialURL =
                fileURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(
                        "EnvironmentCredentials.json"
                    )


            let environmentID =
                memberships
                    .compactMap {
                        $0[
                            "environmentID"
                        ]
                        as? String
                    }
                    .first


            if let environmentID {

                var credentialRoot:
                    [String: Any]


                if
                    FileManager.default
                        .fileExists(
                            atPath:
                                credentialURL.path
                        ),
                    let credentialRaw =
                        try? Data(
                            contentsOf:
                                credentialURL
                        ),
                    let decoded =
                        try? JSONSerialization
                            .jsonObject(
                                with:
                                    credentialRaw
                            )
                            as? [String: Any]
                {
                    credentialRoot =
                        decoded

                } else {
                    credentialRoot =
                        [
                            "schemaVersion":
                                1,
                            "environmentID":
                                environmentID,
                            "credentials":
                                []
                        ]
                }


                var credentials =
                    credentialRoot[
                        "credentials"
                    ]
                    as? [[String: Any]]
                    ?? []


                var existingMembershipIDs =
                    Set(
                        credentials
                            .compactMap {
                                $0[
                                    "membershipID"
                                ]
                                as? String
                            }
                    )


                for legacyUser in legacyUsers {

                    guard
                        let legacyUserID =
                            legacyUser["id"]
                            as? String,
                        let membershipID =
                            legacyUserToMembership[
                                legacyUserID
                            ],
                        !existingMembershipIDs
                            .contains(
                                membershipID
                            )
                    else {
                        continue
                    }


                    guard
                        let salt =
                            legacyUser[
                                "passwordSaltBase64"
                            ]
                            as? String,
                        let hash =
                            legacyUser[
                                "passwordHashBase64"
                            ]
                            as? String,
                        let iterations =
                            legacyUser[
                                "passwordIterations"
                            ]
                            as? NSNumber
                    else {
                        throw NSError(
                            domain:
                                "Testudo.SchemaMigration",
                            code:
                                83,
                            userInfo:
                                [
                                    NSLocalizedDescriptionKey:
                                        "A legacy credential is incomplete and cannot be migrated safely."
                                ]
                        )
                    }


                    let now =
                        Date()
                            .timeIntervalSinceReferenceDate


                    credentials.append(
                        [
                            "membershipID":
                                membershipID,
                            "passwordSaltBase64":
                                salt,
                            "passwordHashBase64":
                                hash,
                            "passwordIterations":
                                iterations,
                            "createdAt":
                                (
                                    legacyUser[
                                        "createdAt"
                                    ]
                                    as? NSNumber
                                )
                                ?? NSNumber(
                                    value:
                                        now
                                ),
                            "updatedAt":
                                NSNumber(
                                    value:
                                        now
                                )
                        ]
                    )


                    existingMembershipIDs
                        .insert(
                            membershipID
                        )
                }


                credentialRoot[
                    "schemaVersion"
                ] =
                    1

                credentialRoot[
                    "environmentID"
                ] =
                    environmentID

                credentialRoot[
                    "credentials"
                ] =
                    credentials


                let encodedCredentials =
                    try JSONSerialization
                        .data(
                            withJSONObject:
                                credentialRoot,
                            options:
                                [
                                    .prettyPrinted,
                                    .sortedKeys
                                ]
                        )


                try encodedCredentials
                    .write(
                        to:
                            credentialURL,
                        options:
                            .atomic
                    )
            }
        }


        // ----------------------------------------------------
        // Schema 8 no longer persists legacy users.
        // ----------------------------------------------------

        root.removeValue(
            forKey:
                "users"
        )

        root[
            "schemaVersion"
        ] =
            8


        let migrated =
            try JSONSerialization
                .data(
                    withJSONObject:
                        root,
                    options:
                        [
                            .prettyPrinted,
                            .sortedKeys
                        ]
                )


        try migrated.write(
            to:
                fileURL,
            options:
                .atomic
        )
    }
}


// ============================================================
// MARK: - Portable Testudo Environment package storage
// ============================================================

extension TestudoStore {

    private static func securityScopedBookmarkData(
        for url:
            URL
    ) -> Data? {

        try? url.bookmarkData(
            options:
                [
                    .withSecurityScope
                ],
            includingResourceValuesForKeys:
                nil,
            relativeTo:
                nil
        )
    }


    private func resolvedStorageURL(
        for environment:
            WorkEnvironment
    ) -> URL? {

        guard
            let storage =
                environment.storage
        else {
            return nil
        }


        // ----------------------------------------------------
        // Persistent bookmark is canonical when available.
        // ----------------------------------------------------

        if
            let bookmarkData =
                storage.bookmarkData
        {
            var isStale =
                false

            if
                let resolved =
                    try? URL(
                        resolvingBookmarkData:
                            bookmarkData,
                        options:
                            [
                                .withSecurityScope
                            ],
                        relativeTo:
                            nil,
                        bookmarkDataIsStale:
                            &isStale
                    )
            {
                _ =
                    resolved
                        .startAccessingSecurityScopedResource()

                return
                    resolved
                        .standardizedFileURL
            }
        }


        // ----------------------------------------------------
        // Path remains a human-readable / unsandboxed fallback
        // for this installation's explicitly registered storage.
        //
        // It is never synthesized from Application Support.
        // ----------------------------------------------------

        guard
            let configuredPath =
                storage.path?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !configuredPath.isEmpty
        else {
            return nil
        }


        return
            URL(
                fileURLWithPath:
                    configuredPath,
                isDirectory:
                    true
            )
            .standardizedFileURL
    }


    @discardableResult
    func saveWorkEnvironmentAsPackage(
        id environmentID:
            UUID,
        destinationURL:
            URL
    ) -> String? {

        guard
            let environmentIndex =
                applicationData
                    .workEnvironments
                    .firstIndex(
                        where: {
                            $0.id
                                == environmentID
                        }
                    )
        else {
            return
                "Work Environment not found."
        }


        let environment =
            applicationData
                .workEnvironments[
                    environmentIndex
                ]


        guard
            let sourceDataURL =
                environmentDataURL(
                    for:
                        environment
                )
        else {
            return
                "The current Environment storage location is unavailable."
        }


        let sourceRoot =
            sourceDataURL
                .deletingLastPathComponent()
                .standardizedFileURL


        let destination =
            TestudoEnvironmentPackage
                .normalizedURL(
                    destinationURL
                )
                .standardizedFileURL


        if
            destination
                .pathExtension
                .caseInsensitiveCompare(
                    TestudoEnvironmentPackage
                        .filenameExtension
                )
                != .orderedSame
        {
            return
                "The destination must be a .testudoenv package."
        }


        if
            sourceRoot.path
                != destination.path
        {
            guard
                !FileManager.default
                    .fileExists(
                        atPath:
                            destination.path
                    )
            else {
                return
                    "A file or Work Environment already exists at that location."
            }


            if
                activeEnvironmentID
                    == environmentID
            {
                save()
            }


            do {
                try FileManager.default
                    .copyItem(
                        at:
                            sourceRoot,
                        to:
                            destination
                    )

            } catch {
                return
                    "The Work Environment could not be copied: \(error.localizedDescription)"
            }
        }


        _ =
            destination
                .startAccessingSecurityScopedResource()


        let now =
            Date()


        var storage =
            environment.storage
            ?? EnvironmentStorageConfiguration()


        storage.kind =
            .testudoPackage

        storage.displayName =
            destination
                .lastPathComponent

        storage.path =
            destination.path

        storage.bookmarkData =
            Self
                .securityScopedBookmarkData(
                    for:
                        destination
                )

        storage.updatedAt =
            now

        storage.lastConnectedAt =
            now


        applicationData
            .workEnvironments[
                environmentIndex
            ]
            .storage =
            storage

        applicationData
            .workEnvironments[
                environmentIndex
            ]
            .updatedAt =
            now


        if
            activeEnvironmentID
                == environmentID
        {
            fileURL =
                destination
                    .appendingPathComponent(
                        "EnvironmentData.json"
                    )
        }


        saveApplicationData()


        return nil
    }
}


// ============================================================
// MARK: - Work Environment local registration
// ============================================================

extension TestudoStore {

    /// Removes a Work Environment only from this installation's
    /// local registry.
    ///
    /// The Environment package/folder itself is deliberately
    /// left completely untouched so it can be opened again later.
    @discardableResult
    func unregisterWorkEnvironment(
        id environmentID:
            UUID
    ) -> String? {

        guard
            applicationData
                .workEnvironments
                .contains(
                    where: {
                        $0.id
                            == environmentID
                    }
                )
        else {
            return
                "Work Environment not found."
        }


        let removingActiveEnvironment =
            applicationData
                .activeEnvironmentID
                == environmentID


        // If an Environment is genuinely open, persist its current
        // state before forgetting the local registration.
        //
        // This writes to the existing Environment package but does
        // not move, rename or delete it.
        if
            removingActiveEnvironment,
            environmentSessionIsOpen
        {
            save()
        }


        applicationData
            .workEnvironments
            .removeAll {
                $0.id
                    == environmentID
            }


        applicationData
            .environmentAccesses
            .removeAll {
                $0.environmentID
                    == environmentID
            }


        if removingActiveEnvironment {

            applicationData
                .activeEnvironmentID =
                nil

            environmentSessionIsOpen =
                false

            // Do not retain Environment-owned data as the active
            // in-memory model after the local registration is gone.
            data =
                TestudoData()
        }


        saveApplicationData()


        return nil
    }
}


// ============================================================
// MARK: - Import local profile into current Environment Person
// ============================================================

extension TestudoStore {

    @discardableResult
    func importLocalProfileIntoCurrentEnvironmentPerson(
        fields:
            Set<LocalProfileImportField>
    ) -> String? {

        guard
            !fields.isEmpty
        else {
            return
                "Choose at least one field to import."
        }


        guard
            let source =
                localUserProfile
        else {
            return
                "No local Testudo profile is available."
        }


        guard
            let membership =
                currentEnvironmentMembership
        else {
            return
                "No Environment membership is currently active."
        }


        guard
            let personID =
                membership.personEntityID
        else {
            return
                "Your Environment membership is not linked to a Person."
        }


        guard
            let person =
                entity(
                    id:
                        personID
                ),
            person.kind
                == .person
        else {
            return
                "The Person linked to your Environment membership could not be found."
        }


        var target =
            personProfile(
                for:
                    personID
            )
            ?? PersonProfile(
                entityID:
                    personID
            )


        // ----------------------------------------------------
        // Identity
        // ----------------------------------------------------

        if fields.contains(
            .avatar
        ) {
            target.avatarData =
                source.avatarData
        }


        if fields.contains(
            .firstName
        ) {
            target.firstName =
                source.firstName
        }


        if fields.contains(
            .middleName
        ) {
            target.middleName =
                source.middleName
        }


        if fields.contains(
            .lastName
        ) {
            target.lastName =
                source.lastName
        }


        if fields.contains(
            .preferredName
        ) {
            target.preferredName =
                source.preferredName
        }


        // ----------------------------------------------------
        // Professional information
        // ----------------------------------------------------

        if fields.contains(
            .academicTitle
        ) {
            target.academicTitle =
                source.academicTitle
        }


        if fields.contains(
            .jobTitle
        ) {
            target.jobTitle =
                source.jobTitle
        }


        if fields.contains(
            .office
        ) {
            target.office =
                source.office
        }


        if fields.contains(
            .employeeID
        ) {
            target.employeeID =
                source.employeeID
        }


        // ----------------------------------------------------
        // Contact
        // ----------------------------------------------------

        if fields.contains(
            .professionalEmail
        ) {
            target.professionalEmail =
                source.professionalEmail
        }


        if fields.contains(
            .secondaryProfessionalEmail
        ) {
            target.secondaryProfessionalEmail =
                source.secondaryProfessionalEmail
        }


        if fields.contains(
            .professionalPhone
        ) {
            target.professionalPhone =
                source.professionalPhone
        }


        if fields.contains(
            .secondaryPhone
        ) {
            target.secondaryPhone =
                source.secondaryPhone
        }


        if fields.contains(
            .assistantContact
        ) {
            target.assistantContact =
                source.assistantContact
        }


        // ----------------------------------------------------
        // Online & research identity
        // ----------------------------------------------------

        if fields.contains(
            .website
        ) {
            target.website =
                source.website
        }


        if fields.contains(
            .orcid
        ) {
            target.orcid =
                source.orcid
        }


        if fields.contains(
            .linkedIn
        ) {
            target.linkedIn =
                source.linkedIn
        }


        if fields.contains(
            .github
        ) {
            target.github =
                source.github
        }


        if fields.contains(
            .researcherID
        ) {
            target.researcherID =
                source.researcherID
        }


        if fields.contains(
            .scopusAuthorID
        ) {
            target.scopusAuthorID =
                source.scopusAuthorID
        }


        if fields.contains(
            .googleScholarURL
        ) {
            target.googleScholarURL =
                source.googleScholarURL
        }


        // ----------------------------------------------------
        // Location
        // ----------------------------------------------------

        if fields.contains(
            .professionalAddress
        ) {
            target.professionalAddress =
                source.professionalAddress
        }


        if fields.contains(
            .city
        ) {
            target.city =
                source.city
        }


        if fields.contains(
            .postalCode
        ) {
            target.postalCode =
                source.postalCode
        }


        if fields.contains(
            .country
        ) {
            target.country =
                source.country
        }


        // ----------------------------------------------------
        // Additional information
        // ----------------------------------------------------

        if fields.contains(
            .professionalFields
        ) {
            target.professionalFields =
                source.professionalFields
        }


        if fields.contains(
            .responsibilities
        ) {
            target.responsibilities =
                source.responsibilities
        }


        if fields.contains(
            .preferredLanguage
        ) {
            target.preferredLanguage =
                source.preferredLanguage
        }


        if fields.contains(
            .timeZone
        ) {
            target.timeZone =
                source.timeZone
        }


        if fields.contains(
            .tags
        ) {
            target.tags =
                source.tags
        }


        if fields.contains(
            .notes
        ) {
            target.notes =
                source.notes
        }


        target.updatedAt =
            Date()


        // Use the canonical PersonProfile save path so Person
        // naming / membership snapshot behavior remains identical
        // to normal People-profile editing.
        savePersonProfile(
            target
        )


        return nil
    }
}


// ============================================================
// MARK: - Local application authentication
// ============================================================

extension TestudoStore {

    var applicationCredentialIsConfigured:
        Bool
    {
        applicationData
            .applicationCredential
            != nil
    }


    @discardableResult
    func configureApplicationPassword(
        _ password:
            String
    ) -> String? {

        guard
            applicationData
                .localUserProfile
                != nil
        else {
            return
                "Create your local Testudo profile first."
        }


        guard
            !password.isEmpty
        else {
            return
                "Application password is required."
        }


        do {

            let hash =
                try PasswordHasher
                    .createHash(
                        password:
                            password
                    )

            let now =
                Date()


            applicationData
                .applicationCredential =
                ApplicationCredential(
                    passwordSaltBase64:
                        hash.saltBase64,
                    passwordHashBase64:
                        hash.hashBase64,
                    passwordIterations:
                        hash.iterations,
                    createdAt:
                        applicationData
                            .applicationCredential?
                            .createdAt
                        ?? now,
                    updatedAt:
                        now
                )


            applicationData
                .applicationIsLoggedOut =
                false

            applicationData
                .schemaVersion =
                max(
                    applicationData
                        .schemaVersion,
                    4
                )


            applicationSessionIsOpen =
                true


            saveApplicationData()


            return nil

        } catch {

            return
                "The application password could not be created."
        }
    }


    @discardableResult
    func unlockApplication(
        password:
            String
    ) -> String? {

        guard
            let credential =
                applicationData
                    .applicationCredential
        else {
            return
                "No application password is configured."
        }


        guard
            PasswordHasher.verify(
                password:
                    password,
                saltBase64:
                    credential
                        .passwordSaltBase64,
                expectedHashBase64:
                    credential
                        .passwordHashBase64,
                iterations:
                    credential
                        .passwordIterations
            )
        else {
            return
                "Incorrect password."
        }


        applicationData
            .applicationIsLoggedOut =
            false

        applicationSessionIsOpen =
            true


        saveApplicationData()


        // If the app was restarted while logged out, the in-memory
        // Environment session no longer exists.
        //
        // Restore it automatically only when that Environment had
        // explicitly enabled Stay signed in.
        if
            !environmentSessionIsOpen,
            let environmentID =
                applicationData
                    .activeEnvironmentID
        {
            _ =
                openWorkEnvironment(
                    id:
                        environmentID
                )
        }


        return nil
    }


    func logOutApplication() {

        if environmentSessionIsOpen {
            save()
        }


        applicationData
            .applicationIsLoggedOut =
            true


        saveApplicationData()


        // Deliberately do NOT destroy:
        //
        // • LocalUserProfile
        // • Work Environment registry
        // • bookmarks
        // • EnvironmentAccess mappings
        // • Stay signed in states
        // • the currently open in-memory Environment session
        //
        // Therefore logging back in during this run returns the
        // user to the state they just left.
        applicationSessionIsOpen =
            false
    }


    func signOutApplicationAndRemoveLocalData() {

        // Preserve external Environment data before forgetting it.
        if environmentSessionIsOpen {
            save()
        }


        applicationSessionIsOpen =
            false

        environmentSessionIsOpen =
            false


        // Remove all application-owned identity/registry state
        // from memory first.
        applicationData =
            ApplicationData()

        data =
            TestudoData()


        let applicationDirectory =
            applicationFileURL
                .deletingLastPathComponent()


        // The following are old/application-owned local files.
        //
        // IMPORTANT:
        // We intentionally do NOT enumerate and delete arbitrary
        // filesystem contents and we never delete .testudoenv
        // packages. A user may have stored one anywhere, including
        // theoretically inside Application Support.
        let localOwnedPaths:
            [URL] =
            [
                applicationFileURL,

                applicationDirectory
                    .appendingPathComponent(
                        "TestudoData.json"
                    ),

                applicationDirectory
                    .appendingPathComponent(
                        "Environments",
                        isDirectory:
                            true
                    ),

                applicationDirectory
                    .appendingPathComponent(
                        "TestDataBackups",
                        isDirectory:
                            true
                    ),

                applicationDirectory
                    .appendingPathComponent(
                        "TestDatasetManifest.json"
                    ),
            ]


        for url in localOwnedPaths {

            guard
                FileManager.default
                    .fileExists(
                        atPath:
                            url.path
                    )
            else {
                continue
            }


            try?
                FileManager.default
                    .removeItem(
                        at:
                            url
                    )
        }


        ApplicationLocalDataCleanup
            .removeOwnedKeychainItems()


        // Return the transient Environment database pointer to the
        // application-owned legacy/default location.
        fileURL =
            applicationDirectory
                .appendingPathComponent(
                    "TestudoData.json"
                )


        // Recreate only an EMPTY ApplicationData.json so the
        // running application has a valid backing file.
        //
        // It contains no profile, Environment registry, bookmarks
        // or remembered identity.
        saveApplicationData()
    }
}


// ============================================================
// MARK: - Portable Testudo user profile
// ============================================================

extension TestudoStore {

    @discardableResult
    func exportLocalUserProfile(
        to destinationURL:
            URL
    ) -> String? {

        guard
            let profile =
                applicationData
                    .localUserProfile
        else {
            return
                "No local Testudo profile exists."
        }


        let destinationURL =
            TestudoUserProfileFile
                .normalizedURL(
                    destinationURL
                )


        let document =
            TestudoUserProfileDocument(
                profile:
                    profile
            )


        do {

            let encoder =
                JSONEncoder()

            encoder.outputFormatting =
                [
                    .prettyPrinted,
                    .sortedKeys,
                ]

            encoder.dateEncodingStrategy =
                .iso8601


            let encoded =
                try encoder
                    .encode(
                        document
                    )


            try encoded
                .write(
                    to:
                        destinationURL,
                    options:
                        .atomic
                )


            return nil

        } catch {

            return
                "The Testudo user profile could not be exported."
        }
    }


    @discardableResult
    func importLocalUserProfile(
        from sourceURL:
            URL
    ) -> String? {

        guard
            applicationData
                .localUserProfile
                == nil
        else {
            return
                "A local Testudo profile already exists."
        }


        guard
            sourceURL
                .pathExtension
                .caseInsensitiveCompare(
                    TestudoUserProfileFile
                        .filenameExtension
                )
                == .orderedSame
        else {
            return
                "Select a .testudouser file."
        }


        do {

            let raw =
                try Data(
                    contentsOf:
                        sourceURL
                )


            let decoder =
                JSONDecoder()

            decoder.dateDecodingStrategy =
                .iso8601


            let document =
                try decoder
                    .decode(
                        TestudoUserProfileDocument.self,
                        from:
                            raw
                    )


            guard
                document.schemaVersion
                    == 1
            else {
                return
                    "This .testudouser file uses an unsupported profile format."
            }


            let importedProfile =
                document.profile


            guard
                !importedProfile
                    .firstName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            else {
                return
                    "The imported profile does not contain a first name."
            }


            guard
                !importedProfile
                    .lastName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            else {
                return
                    "The imported profile does not contain a last name."
            }


            // Preserve the exported profile exactly.
            //
            // The application credential is deliberately NOT
            // imported. AccountGate will therefore immediately
            // request creation of a new application password.
            applicationData
                .localUserProfile =
                importedProfile

            applicationData
                .applicationCredential =
                nil

            applicationData
                .applicationIsLoggedOut =
                false

            applicationData
                .schemaVersion =
                max(
                    applicationData
                        .schemaVersion,
                    4
                )


            // A .testudouser file NEVER restores Environment state.
            applicationData
                .workEnvironments =
                []

            applicationData
                .environmentAccesses =
                []

            applicationData
                .activeEnvironmentID =
                nil


            environmentSessionIsOpen =
                false

            applicationSessionIsOpen =
                false

            data =
                TestudoData()


            saveApplicationData()


            return nil

        } catch {

            return
                "The .testudouser file could not be read."
        }
    }
}



// ============================================================
// MARK: - Portable Work Environment appearance
//
// A custom Environment icon is an Environment-owned asset:
//
//     <Environment>.testudoenv/EnvironmentIcon.png
//
// It therefore travels with the package.
//
// Absence of EnvironmentIcon.png means the application should
// render its bundled default Testudo Environment icon.
// ============================================================

extension TestudoStore {

    func environmentIconData(
        for environmentID:
            UUID
    ) -> Data? {

        guard
            let environment =
                applicationData
                    .workEnvironments
                    .first(
                        where: {
                            $0.id
                                == environmentID
                        }
                    ),
            environment
                .storage?
                .kind
                == .testudoPackage,
            let packageURL =
                resolvedStorageURL(
                    for:
                        environment
                )
        else {
            return nil
        }


        let iconURL =
            packageURL
                .appendingPathComponent(
                    TestudoEnvironmentPackage
                        .customIconFileName
                )


        guard
            FileManager
                .default
                .fileExists(
                    atPath:
                        iconURL.path
                )
        else {
            return nil
        }


        return
            try? Data(
                contentsOf:
                    iconURL
            )
    }


    var activeEnvironmentIconData:
        Data?
    {
        guard
            let environmentID =
                activeEnvironmentID
        else {
            return nil
        }


        return
            environmentIconData(
                for:
                    environmentID
            )
    }


    @discardableResult
    func setActiveEnvironmentIcon(
        from sourceURL:
            URL
    ) -> String? {

        guard
            currentEnvironmentUserIsAdministrator
        else {
            return
                "Environment Administrator rights are required."
        }


        guard
            let environmentID =
                activeEnvironmentID,
            let environmentIndex =
                applicationData
                    .workEnvironments
                    .firstIndex(
                        where: {
                            $0.id
                                == environmentID
                        }
                    )
        else {
            return
                "No Work Environment is active."
        }


        let environment =
            applicationData
                .workEnvironments[
                    environmentIndex
                ]


        guard
            environment
                .storage?
                .kind
                == .testudoPackage
        else {
            return
                "Save this Environment as a .testudoenv package before assigning a custom icon."
        }


        guard
            let packageURL =
                resolvedStorageURL(
                    for:
                        environment
                )
        else {
            return
                "The Work Environment package is unavailable."
        }


        guard
            let pngData =
                normalizedEnvironmentIconPNG(
                    from:
                        sourceURL
                )
        else {
            return
                "The selected image could not be converted to a PNG icon."
        }


        let iconURL =
            packageURL
                .appendingPathComponent(
                    TestudoEnvironmentPackage
                        .customIconFileName
                )


        do {

            try pngData
                .write(
                    to:
                        iconURL,
                    options:
                        .atomic
                )

        } catch {

            return
                "The Environment icon could not be saved: \(error.localizedDescription)"
        }


        let now =
            Date()


        applicationData
            .workEnvironments[
                environmentIndex
            ]
            .updatedAt =
            now


        saveApplicationData()


        return nil
    }


    @discardableResult
    func restoreActiveEnvironmentDefaultIcon()
        -> String?
    {
        guard
            currentEnvironmentUserIsAdministrator
        else {
            return
                "Environment Administrator rights are required."
        }


        guard
            let environmentID =
                activeEnvironmentID,
            let environmentIndex =
                applicationData
                    .workEnvironments
                    .firstIndex(
                        where: {
                            $0.id
                                == environmentID
                        }
                    )
        else {
            return
                "No Work Environment is active."
        }


        let environment =
            applicationData
                .workEnvironments[
                    environmentIndex
                ]


        guard
            environment
                .storage?
                .kind
                == .testudoPackage,
            let packageURL =
                resolvedStorageURL(
                    for:
                        environment
                )
        else {
            return
                "The Work Environment package is unavailable."
        }


        let iconURL =
            packageURL
                .appendingPathComponent(
                    TestudoEnvironmentPackage
                        .customIconFileName
                )


        if
            FileManager
                .default
                .fileExists(
                    atPath:
                        iconURL.path
                )
        {
            do {

                try FileManager
                    .default
                    .removeItem(
                        at:
                            iconURL
                    )

            } catch {

                return
                    "The custom Environment icon could not be removed: \(error.localizedDescription)"
            }
        }


        applicationData
            .workEnvironments[
                environmentIndex
            ]
            .updatedAt =
            Date()


        saveApplicationData()


        return nil
    }


    private func normalizedEnvironmentIconPNG(
        from sourceURL:
            URL
    ) -> Data? {

        guard
            let sourceImage =
                NSImage(
                    contentsOf:
                        sourceURL
                )
        else {
            return nil
        }


        let sourceSize =
            sourceImage.size


        guard
            sourceSize.width > 0,
            sourceSize.height > 0
        else {
            return nil
        }


        let maximumDimension:
            CGFloat =
            1024


        let scale =
            min(
                1,
                maximumDimension
                    / max(
                        sourceSize.width,
                        sourceSize.height
                    )
            )


        let targetSize =
            NSSize(
                width:
                    max(
                        1,
                        sourceSize.width
                            * scale
                    ),
                height:
                    max(
                        1,
                        sourceSize.height
                            * scale
                    )
            )


        let normalized =
            NSImage(
                size:
                    targetSize
            )


        normalized.lockFocus()

        NSGraphicsContext
            .current?
            .imageInterpolation =
            .high


        sourceImage.draw(
            in:
                NSRect(
                    origin:
                        .zero,
                    size:
                        targetSize
                ),
            from:
                NSRect(
                    origin:
                        .zero,
                    size:
                        sourceSize
                ),
            operation:
                .copy,
            fraction:
                1
        )

        normalized.unlockFocus()


        guard
            let tiff =
                normalized
                    .tiffRepresentation,
            let bitmap =
                NSBitmapImageRep(
                    data:
                        tiff
                ),
            let png =
                bitmap
                    .representation(
                        using:
                            .png,
                        properties:
                            [:]
                    )
        else {
            return nil
        }


        return png
    }
}


// ============================================================
// MARK: - Application password management and recovery
// ============================================================

extension TestudoStore {

    var applicationRecoveryQuestionPrompts:
        [SecurityQuestionPrompt]
    {
        SecurityRecovery
            .prompts(
                from:
                    applicationData
                        .applicationCredential?
                        .recoveryQuestions
            )
    }


    var applicationRecoveryQuestionsAreConfigured:
        Bool
    {
        applicationRecoveryQuestionPrompts
            .count
            == 3
    }


    // --------------------------------------------------------
    // Initial setup:
    // create password + all three recovery questions.
    // --------------------------------------------------------

    @discardableResult
    func configureApplicationPassword(
        _ password:
            String,
        recoveryQuestions drafts:
            [SecurityQuestionDraft]
    ) -> String? {

        guard
            password.count
                >= 8
        else {
            return
                "Password must contain at least 8 characters."
        }


        let recovery:
            [SecurityQuestionCredential]


        do {

            recovery =
                try SecurityRecovery
                    .createCredentials(
                        from:
                            drafts
                    )

        } catch {

            return
                error.localizedDescription
        }


        if
            let error =
                configureApplicationPassword(
                    password
                )
        {
            return error
        }


        applicationData
            .applicationCredential?
            .recoveryQuestions =
            recovery


        applicationData
            .applicationCredential?
            .updatedAt =
            Date()


        applicationData
            .schemaVersion =
            max(
                applicationData
                    .schemaVersion,
                5
            )


        saveApplicationData()


        return nil
    }


    @discardableResult
    func changeApplicationPassword(
        currentPassword:
            String,
        newPassword:
            String
    ) -> String? {

        guard
            let credential =
                applicationData
                    .applicationCredential
        else {
            return
                "No application password is configured."
        }


        guard
            PasswordHasher
                .verify(
                    password:
                        currentPassword,
                    saltBase64:
                        credential
                            .passwordSaltBase64,
                    expectedHashBase64:
                        credential
                            .passwordHashBase64,
                    iterations:
                        credential
                            .passwordIterations
                )
        else {
            return
                "The current password is incorrect."
        }


        guard
            newPassword.count
                >= 8
        else {
            return
                "Password must contain at least 8 characters."
        }


        do {

            let hash =
                try PasswordHasher
                    .createHash(
                        password:
                            newPassword
                    )


            applicationData
                .applicationCredential =
                ApplicationCredential(
                    passwordSaltBase64:
                        hash.saltBase64,
                    passwordHashBase64:
                        hash.hashBase64,
                    passwordIterations:
                        hash.iterations,
                    createdAt:
                        credential.createdAt,
                    updatedAt:
                        Date(),
                    recoveryQuestions:
                        credential
                            .recoveryQuestions
                )


            applicationData
                .schemaVersion =
                max(
                    applicationData
                        .schemaVersion,
                    5
                )


            saveApplicationData()


            return nil

        } catch {

            return
                "The new application password could not be secured."
        }
    }


    @discardableResult
    func setApplicationRecoveryQuestions(
        currentPassword:
            String,
        drafts:
            [SecurityQuestionDraft]
    ) -> String? {

        guard
            let credential =
                applicationData
                    .applicationCredential
        else {
            return
                "No application password is configured."
        }


        guard
            PasswordHasher
                .verify(
                    password:
                        currentPassword,
                    saltBase64:
                        credential
                            .passwordSaltBase64,
                    expectedHashBase64:
                        credential
                            .passwordHashBase64,
                    iterations:
                        credential
                            .passwordIterations
                )
        else {
            return
                "The current password is incorrect."
        }


        do {

            let recovery =
                try SecurityRecovery
                    .createCredentials(
                        from:
                            drafts
                    )


            applicationData
                .applicationCredential?
                .recoveryQuestions =
                recovery


            applicationData
                .applicationCredential?
                .updatedAt =
                Date()


            applicationData
                .schemaVersion =
                max(
                    applicationData
                        .schemaVersion,
                    5
                )


            saveApplicationData()


            return nil

        } catch {

            return
                error.localizedDescription
        }
    }


    @discardableResult
    func resetApplicationPasswordUsingRecovery(
        questionID:
            UUID,
        answer:
            String,
        newPassword:
            String
    ) -> String? {

        guard
            let credential =
                applicationData
                    .applicationCredential,
            let recoveryQuestions =
                credential
                    .recoveryQuestions,
            let question =
                recoveryQuestions
                    .first(
                        where: {
                            $0.id
                                == questionID
                        }
                    )
        else {
            return
                "Password recovery is not configured for this Testudo account."
        }


        guard
            SecurityRecovery
                .verify(
                    answer:
                        answer,
                    against:
                        question
                )
        else {
            return
                "The security answer is incorrect."
        }


        guard
            newPassword.count
                >= 8
        else {
            return
                "Password must contain at least 8 characters."
        }


        do {

            let hash =
                try PasswordHasher
                    .createHash(
                        password:
                            newPassword
                    )


            applicationData
                .applicationCredential =
                ApplicationCredential(
                    passwordSaltBase64:
                        hash.saltBase64,
                    passwordHashBase64:
                        hash.hashBase64,
                    passwordIterations:
                        hash.iterations,
                    createdAt:
                        credential.createdAt,
                    updatedAt:
                        Date(),
                    recoveryQuestions:
                        recoveryQuestions
                )


            applicationData
                .schemaVersion =
                max(
                    applicationData
                        .schemaVersion,
                    5
                )


            // Recovery does not silently create an authenticated
            // application session. The user logs in explicitly
            // with the newly chosen password.
            applicationSessionIsOpen =
                false

            applicationData
                .applicationIsLoggedOut =
                true


            saveApplicationData()


            return nil

        } catch {

            return
                "The new application password could not be secured."
        }
    }
}


// ============================================================
// MARK: - Environment self-service password management
// ============================================================

extension TestudoStore {

    var currentEnvironmentRecoveryQuestionPrompts:
        [SecurityQuestionPrompt]
    {
        guard
            let membershipID =
                currentEnvironmentMembership?
                    .id,
            let credential =
                environmentCredential(
                    for:
                        membershipID
                )
        else {
            return []
        }


        return
            SecurityRecovery
                .prompts(
                    from:
                        credential
                            .recoveryQuestions
                )
    }


    var currentEnvironmentRecoveryQuestionsAreConfigured:
        Bool
    {
        currentEnvironmentRecoveryQuestionPrompts
            .count
            == 3
    }


    func environmentRecoveryQuestionPrompts(
        environmentID:
            UUID,
        username:
            String
    ) -> [SecurityQuestionPrompt] {

        guard
            activeEnvironmentID
                == environmentID
        else {
            return []
        }


        let cleanedUsername =
            username
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            !cleanedUsername.isEmpty,
            let membership =
                data
                    .environmentMemberships
                    .first(
                        where: {
                            guard
                                $0.environmentID
                                    == environmentID,
                                $0.isActive,
                                let identifier =
                                    $0.directoryUserIdentifier?
                                        .trimmingCharacters(
                                            in:
                                                .whitespacesAndNewlines
                                        )
                            else {
                                return false
                            }


                            return
                                identifier
                                    .caseInsensitiveCompare(
                                        cleanedUsername
                                    )
                                    == .orderedSame
                        }
                    ),
            let credential =
                environmentCredential(
                    for:
                        membership.id
                )
        else {
            return []
        }


        return
            SecurityRecovery
                .prompts(
                    from:
                        credential
                            .recoveryQuestions
                )
    }


    @discardableResult
    func changeCurrentEnvironmentPassword(
        currentPassword:
            String,
        newPassword:
            String
    ) -> String? {

        guard
            let membership =
                currentEnvironmentMembership
        else {
            return
                "No Environment membership is currently signed in."
        }


        guard
            let credential =
                environmentCredential(
                    for:
                        membership.id
                )
        else {
            return
                "This Environment account does not have a password."
        }


        guard
            PasswordHasher
                .verify(
                    password:
                        currentPassword,
                    saltBase64:
                        credential
                            .passwordSaltBase64,
                    expectedHashBase64:
                        credential
                            .passwordHashBase64,
                    iterations:
                        credential
                            .passwordIterations
                )
        else {
            return
                "The current Environment password is incorrect."
        }


        return
            writeEnvironmentMembershipPassword(
                membershipID:
                    membership.id,
                newPassword:
                    newPassword
            )
    }


    @discardableResult
    func setCurrentEnvironmentRecoveryQuestions(
        currentPassword:
            String,
        drafts:
            [SecurityQuestionDraft]
    ) -> String? {

        guard
            let membership =
                currentEnvironmentMembership
        else {
            return
                "No Environment membership is currently signed in."
        }


        guard
            let credential =
                environmentCredential(
                    for:
                        membership.id
                )
        else {
            return
                "This Environment account does not have a password."
        }


        guard
            PasswordHasher
                .verify(
                    password:
                        currentPassword,
                    saltBase64:
                        credential
                            .passwordSaltBase64,
                    expectedHashBase64:
                        credential
                            .passwordHashBase64,
                    iterations:
                        credential
                            .passwordIterations
                )
        else {
            return
                "The current Environment password is incorrect."
        }


        let recovery:
            [SecurityQuestionCredential]


        do {

            recovery =
                try SecurityRecovery
                    .createCredentials(
                        from:
                            drafts
                    )

        } catch {

            return
                error.localizedDescription
        }


        var credentialStore =
            loadEnvironmentCredentialStore()


        guard
            let index =
                credentialStore
                    .credentials
                    .firstIndex(
                        where: {
                            $0.membershipID
                                == membership.id
                        }
                    )
        else {
            return
                "The Environment credential could not be found."
        }


        credentialStore
            .credentials[index]
            .recoveryQuestions =
            recovery


        credentialStore
            .credentials[index]
            .updatedAt =
            Date()


        credentialStore
            .schemaVersion =
            max(
                credentialStore
                    .schemaVersion,
                2
            )


        return
            saveEnvironmentCredentialStore(
                credentialStore
            )
    }


    @discardableResult
    func resetEnvironmentPasswordUsingRecovery(
        environmentID:
            UUID,
        username:
            String,
        questionID:
            UUID,
        answer:
            String,
        newPassword:
            String
    ) -> String? {

        guard
            activeEnvironmentID
                == environmentID
        else {
            return
                "The selected Work Environment is not active."
        }


        let cleanedUsername =
            username
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard
            let membership =
                data
                    .environmentMemberships
                    .first(
                        where: {
                            guard
                                $0.environmentID
                                    == environmentID,
                                $0.isActive,
                                let identifier =
                                    $0.directoryUserIdentifier?
                                        .trimmingCharacters(
                                            in:
                                                .whitespacesAndNewlines
                                        )
                            else {
                                return false
                            }


                            return
                                identifier
                                    .caseInsensitiveCompare(
                                        cleanedUsername
                                    )
                                    == .orderedSame
                        }
                    )
        else {
            return
                "The Environment account could not be found."
        }


        guard
            let credential =
                environmentCredential(
                    for:
                        membership.id
                ),
            let recoveryQuestions =
                credential
                    .recoveryQuestions,
            let question =
                recoveryQuestions
                    .first(
                        where: {
                            $0.id
                                == questionID
                        }
                    )
        else {
            return
                "Security-question recovery is not configured for this Environment account. Contact an Environment Administrator to set a new password."
        }


        guard
            SecurityRecovery
                .verify(
                    answer:
                        answer,
                    against:
                        question
                )
        else {
            return
                "The security answer is incorrect."
        }


        return
            writeEnvironmentMembershipPassword(
                membershipID:
                    membership.id,
                newPassword:
                    newPassword
            )
    }


    // --------------------------------------------------------
    // Internal writer used by authenticated self-service and
    // recovery. Administrator password reset remains a separate
    // authorization path in setEnvironmentMembershipPassword().
    // --------------------------------------------------------

    private func writeEnvironmentMembershipPassword(
        membershipID:
            UUID,
        newPassword:
            String
    ) -> String? {

        guard
            newPassword.count
                >= 8
        else {
            return
                "Password must contain at least 8 characters."
        }


        let hash:
            (
                saltBase64:
                    String,
                hashBase64:
                    String,
                iterations:
                    Int
            )


        do {

            hash =
                try PasswordHasher
                    .createHash(
                        password:
                            newPassword
                    )

        } catch {

            return
                "The password could not be secured."
        }


        var credentialStore =
            loadEnvironmentCredentialStore()

        let now =
            Date()


        if
            let index =
                credentialStore
                    .credentials
                    .firstIndex(
                        where: {
                            $0.membershipID
                                == membershipID
                        }
                    )
        {
            credentialStore
                .credentials[index]
                .passwordSaltBase64 =
                hash.saltBase64

            credentialStore
                .credentials[index]
                .passwordHashBase64 =
                hash.hashBase64

            credentialStore
                .credentials[index]
                .passwordIterations =
                hash.iterations

            credentialStore
                .credentials[index]
                .updatedAt =
                now

        } else {

            credentialStore
                .credentials
                .append(
                    EnvironmentCredential(
                        membershipID:
                            membershipID,
                        passwordSaltBase64:
                            hash.saltBase64,
                        passwordHashBase64:
                            hash.hashBase64,
                        passwordIterations:
                            hash.iterations,
                        createdAt:
                            now,
                        updatedAt:
                            now,
                        recoveryQuestions:
                            nil
                    )
                )
        }


        credentialStore
            .schemaVersion =
            max(
                credentialStore
                    .schemaVersion,
                2
            )


        return
            saveEnvironmentCredentialStore(
                credentialStore
            )
    }
}


// ============================================================
// MARK: - Managed Demo Environments
// ============================================================

extension TestudoStore {

    private var managedDemoEnvironmentDirectory:
        URL
    {
        applicationFileURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Demo Environments",
                isDirectory:
                    true
            )
    }


    private func nextDemoEnvironmentName()
        -> String
    {
        let usedNames =
            Set(
                applicationData
                    .workEnvironments
                    .map {
                        $0.name
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .lowercased()
                    }
            )


        if
            !usedNames
                .contains(
                    "demo"
                )
        {
            return
                "Demo"
        }


        var index =
            2


        while
            usedNames
                .contains(
                    "demo-\(index)"
                )
        {
            index += 1
        }


        return
            "Demo-\(index)"
    }


    private func uniqueManagedDemoPackageURL(
        displayName:
            String
    ) -> URL {

        let root =
            managedDemoEnvironmentDirectory


        let normalURL =
            root
                .appendingPathComponent(
                    "\(displayName).testudoenv",
                    isDirectory:
                        true
                )


        if
            !FileManager
                .default
                .fileExists(
                    atPath:
                        normalURL.path
                )
        {
            return
                normalURL
        }


        var index =
            2


        while true {

            let candidate =
                root
                    .appendingPathComponent(
                        "\(displayName)-instance-\(index).testudoenv",
                        isDirectory:
                            true
                    )


            if
                !FileManager
                    .default
                    .fileExists(
                        atPath:
                            candidate.path
                    )
            {
                return
                    candidate
            }


            index += 1
        }
    }


    @discardableResult
    func createDemoEnvironment()
        -> String?
    {
        guard
            let localProfile =
                applicationData
                    .localUserProfile
        else {
            return
                "Create your Testudo application profile first."
        }


        let displayName =
            nextDemoEnvironmentName()


        let destinationURL =
            uniqueManagedDemoPackageURL(
                displayName:
                    displayName
            )


        let environmentID =
            UUID()

        let now =
            Date()


        let payload =
            DemoEnvironmentGenerator
                .make(
                    environmentID:
                        environmentID,
                    localProfile:
                        localProfile,
                    generatedAt:
                        now
                )


        let identityProvider =
            EnvironmentIdentityProviderConfiguration(
                kind:
                    .localAccounts,
                displayName:
                    "Local Environment Accounts",
                createdAt:
                    now,
                updatedAt:
                    now
            )


        let manifest =
            EnvironmentManifest(
                schemaVersion:
                    2,
                environmentID:
                    environmentID,
                name:
                    displayName,
                identityProvider:
                    identityProvider,
                createdAt:
                    now,
                updatedAt:
                    now
            )


        // Intentionally empty.
        //
        // Demo memberships have no passwords and no recovery
        // credentials until the Administrator explicitly sets
        // them while exploring the Demo.
        let credentialStore =
            EnvironmentCredentialStore(
                environmentID:
                    environmentID,
                credentials:
                    []
            )


        let marker =
            DemoEnvironmentMarker(
                generatedAt:
                    now,
                rangeStart:
                    payload.rangeStart,
                rangeEnd:
                    payload.rangeEnd,
                displayName:
                    displayName
            )


        let dataURL =
            destinationURL
                .appendingPathComponent(
                    "EnvironmentData.json"
                )

        let manifestURL =
            destinationURL
                .appendingPathComponent(
                    "EnvironmentManifest.json"
                )

        let credentialsURL =
            destinationURL
                .appendingPathComponent(
                    "EnvironmentCredentials.json"
                )

        let markerURL =
            destinationURL
                .appendingPathComponent(
                    "DemoEnvironment.json"
                )


        let encoder =
            JSONEncoder()

        encoder.outputFormatting =
            [
                .prettyPrinted,
                .sortedKeys,
            ]

        encoder.dateEncodingStrategy =
            .iso8601


        do {

            try FileManager
                .default
                .createDirectory(
                    at:
                        managedDemoEnvironmentDirectory,
                    withIntermediateDirectories:
                        true
                )


            try FileManager
                .default
                .createDirectory(
                    at:
                        destinationURL,
                    withIntermediateDirectories:
                        false
                )


            try encoder
                .encode(
                    payload.data
                )
                .write(
                    to:
                        dataURL,
                    options:
                        .atomic
                )


            try encoder
                .encode(
                    manifest
                )
                .write(
                    to:
                        manifestURL,
                    options:
                        .atomic
                )


            try encoder
                .encode(
                    credentialStore
                )
                .write(
                    to:
                        credentialsURL,
                    options:
                        .atomic
                )


            try encoder
                .encode(
                    marker
                )
                .write(
                    to:
                        markerURL,
                    options:
                        .atomic
                )

        } catch {

            try?
                FileManager
                    .default
                    .removeItem(
                        at:
                            destinationURL
                    )


            return
                "The Demo Environment could not be created: \(error.localizedDescription)"
        }


        let storage =
            EnvironmentStorageConfiguration(
                kind:
                    .testudoPackage,
                displayName:
                    destinationURL
                        .lastPathComponent,
                path:
                    destinationURL.path,
                bookmarkData:
                    nil,
                createdAt:
                    now,
                updatedAt:
                    now,
                lastConnectedAt:
                    now
            )


        let environment =
            WorkEnvironment(
                id:
                    environmentID,
                name:
                    displayName,
                storage:
                    storage,
                identityProvider:
                    identityProvider,
                createdAt:
                    now,
                updatedAt:
                    now
            )


        applicationData
            .workEnvironments
            .append(
                environment
            )


        applicationData
            .environmentAccesses
            .append(
                EnvironmentAccess(
                    environmentID:
                        environmentID,
                    membershipID:
                        payload
                            .administratorMembershipID,
                    staySignedIn:
                        true,
                    lastOpenedAt:
                        now
                )
            )


        applicationData
            .activeEnvironmentID =
            environmentID


        fileURL =
            dataURL

        data =
            payload.data

        environmentSessionIsOpen =
            true


        saveApplicationData()


        return nil
    }


    // --------------------------------------------------------
    // Demo packages are credential-free by design.
    //
    // Only packages generated inside Testudo's own managed Demo
    // directory qualify. A random external .testudoenv cannot
    // bypass authentication merely by adding a marker file.
    // --------------------------------------------------------

    private func openManagedDemoEnvironmentSessionIfAvailable(
        environmentID:
            UUID
    ) -> Bool {

        guard
            let environment =
                applicationData
                    .workEnvironments
                    .first(
                        where: {
                            $0.id
                                == environmentID
                        }
                    ),
            let packageURL =
                resolvedStorageURL(
                    for:
                        environment
                )
        else {
            return false
        }


        let normalizedPackage =
            packageURL
                .standardizedFileURL

        let normalizedRoot =
            managedDemoEnvironmentDirectory
                .standardizedFileURL


        guard
            normalizedPackage
                .deletingLastPathComponent()
                == normalizedRoot
        else {
            return false
        }


        let markerURL =
            normalizedPackage
                .appendingPathComponent(
                    "DemoEnvironment.json"
                )


        guard
            let markerData =
                try? Data(
                    contentsOf:
                        markerURL
                )
        else {
            return false
        }


        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601


        guard
            (
                try?
                    decoder.decode(
                        DemoEnvironmentMarker.self,
                        from:
                            markerData
                    )
            )
            != nil
        else {
            return false
        }


        let existingAccess =
            applicationData
                .environmentAccesses
                .first(
                    where: {
                        $0.environmentID
                            == environmentID
                    }
                )


        let preferredMembership =
            existingAccess?
                .membershipID
                .flatMap {
                    membershipID
                    in

                    data
                        .environmentMemberships
                        .first(
                            where: {
                                $0.id
                                    == membershipID
                                && $0.environmentID
                                    == environmentID
                                && $0.isActive
                            }
                        )
                }


        guard
            let membership =
                preferredMembership
                ?? data
                    .environmentMemberships
                    .first(
                        where: {
                            $0.environmentID
                                == environmentID
                            && $0.isActive
                            && $0.role
                                == .administrator
                        }
                    )
        else {
            return false
        }


        let now =
            Date()


        if
            let accessIndex =
                applicationData
                    .environmentAccesses
                    .firstIndex(
                        where: {
                            $0.environmentID
                                == environmentID
                        }
                    )
        {
            applicationData
                .environmentAccesses[
                    accessIndex
                ]
                .membershipID =
                membership.id

            applicationData
                .environmentAccesses[
                    accessIndex
                ]
                .staySignedIn =
                true

            applicationData
                .environmentAccesses[
                    accessIndex
                ]
                .lastOpenedAt =
                now

        } else {

            applicationData
                .environmentAccesses
                .append(
                    EnvironmentAccess(
                        environmentID:
                            environmentID,
                        membershipID:
                            membership.id,
                        staySignedIn:
                            true,
                        lastOpenedAt:
                            now
                    )
                )
        }


        if
            let membershipIndex =
                data
                    .environmentMemberships
                    .firstIndex(
                        where: {
                            $0.id
                                == membership.id
                        }
                    )
        {
            data
                .environmentMemberships[
                    membershipIndex
                ]
                .lastAccessAt =
                now

            save()
        }


        saveApplicationData()


        environmentSessionIsOpen =
            true


        return true
    }
}


// ============================================================
// MARK: - Read-only Apple Calendar / iCloud integration
// ============================================================

@MainActor
extension TestudoStore
{
    func connectAppleCalendar(
        calendarIdentifier:
            String
    ) async -> (
        calendarID:
            UUID?,
        error:
            String?
    ) {
        do {
            let available =
                try await
                    AppleCalendarEventKitBridge
                        .shared
                        .availableCalendars()

            guard
                let candidate =
                    available.first(
                        where: {
                            $0.identifier
                                == calendarIdentifier
                        }
                    )
            else {
                return (
                    nil,
                    AppleCalendarEventKitError
                        .calendarNotFound
                        .localizedDescription
                )
            }


            if
                let existing =
                    data.calendars
                        .first(
                            where: {
                                $0.sourceKind
                                    == .appleEventKit
                                && $0.externalID
                                    == calendarIdentifier
                            }
                        )
            {
                let error =
                    await
                        syncAppleCalendar(
                            id:
                                existing.id
                        )

                return (
                    existing.id,
                    error
                )
            }


            let calendar =
                TestudoCalendar(
                    externalID:
                        candidate
                            .identifier,
                    sourceKind:
                        .appleEventKit,
                    name:
                        candidate
                            .displayName,
                    isEnabled:
                        true,
                    isReadOnly:
                        true
                )

            data.calendars.append(
                calendar
            )

            save()


            let error =
                await
                    syncAppleCalendar(
                        id:
                            calendar.id
                    )

            return (
                calendar.id,
                error
            )

        } catch {
            return (
                nil,
                error.localizedDescription
            )
        }
    }


    func syncAppleCalendar(
        id:
            UUID
    ) async -> String?
    {
        guard
            let index =
                data.calendars
                    .firstIndex(
                        where: {
                            $0.id == id
                        }
                    )
        else {
            return
                "Calendar not found."
        }


        let calendar =
            data.calendars[
                index
            ]

        guard
            calendar.sourceKind
                == .appleEventKit,
            calendar.isReadOnly
        else {
            return
                "This is not an Apple Calendar connection."
        }


        guard
            calendar.isEnabled
        else {
            return nil
        }


        guard
            let identifier =
                calendar
                    .externalID,
            !identifier.isEmpty
        else {
            return
                "The Apple Calendar identifier is missing."
        }


        do {
            let result =
                try await
                    AppleCalendarEventKitBridge
                        .shared
                        .fetchEvents(
                            calendarIdentifier:
                                identifier
                        )

            mergeAppleCalendarEvents(
                result.events,
                into:
                    id,
                windowStart:
                    result
                        .windowStart,
                windowEnd:
                    result
                        .windowEnd
            )


            if
                let freshIndex =
                    data.calendars
                        .firstIndex(
                            where: {
                                $0.id == id
                            }
                        )
            {
                data.calendars[
                    freshIndex
                ]
                .name =
                    result
                        .calendar
                        .displayName

                data.calendars[
                    freshIndex
                ]
                .lastSyncAt =
                    Date()

                data.calendars[
                    freshIndex
                ]
                .lastSyncError =
                    nil

                data.calendars[
                    freshIndex
                ]
                .updatedAt =
                    Date()
            }

            save()

            return nil

        } catch {
            if
                let freshIndex =
                    data.calendars
                        .firstIndex(
                            where: {
                                $0.id == id
                            }
                        )
            {
                data.calendars[
                    freshIndex
                ]
                .lastSyncError =
                    error
                        .localizedDescription

                data.calendars[
                    freshIndex
                ]
                .updatedAt =
                    Date()
            }

            save()

            return
                error.localizedDescription
        }
    }


    func syncAllExternalCalendars()
        async -> [String]
    {
        var errors =
            await
                syncAllICalCalendars()


        let appleIDs =
            data.calendars
                .filter {
                    $0.sourceKind
                        == .appleEventKit
                    && $0.isEnabled
                }
                .map(\.id)


        for id in appleIDs {
            if
                let error =
                    await
                        syncAppleCalendar(
                            id:
                                id
                        )
            {
                errors.append(
                    error
                )
            }
        }

        return errors
    }


    private func mergeAppleCalendarEvents(
        _ imported:
            [AppleCalendarEventSnapshot],
        into calendarID:
            UUID,
        windowStart:
            Date,
        windowEnd:
            Date
    ) {
        let now =
            Date()


        // Remember which cached events existed in the fetch window
        // before this sync. If an external event disappears, we keep
        // its Testudo relationships and mark it as a conflict rather
        // than deleting those relationships.
        let previouslyCachedIDs =
            Set(
                data.calendarEvents
                    .filter {
                        $0.calendarID
                            == calendarID
                        && $0.startAt
                            < windowEnd
                        && $0.endAt
                            > windowStart
                    }
                    .map(\.id)
            )


        var matchedIDs:
            Set<UUID> = []


        for source in imported {
            var matchingIndex:
                Int?


            // ----------------------------------------------------
            // Preferred local EventKit event identifier.
            // ----------------------------------------------------

            if
                let eventIdentifier =
                    source
                        .eventIdentifier,
                !eventIdentifier.isEmpty
            {
                matchingIndex =
                    data.calendarEvents
                        .firstIndex(
                            where: {
                                $0.calendarID
                                    == calendarID
                                && $0.externalID
                                    == eventIdentifier
                            }
                        )
            }


            // ----------------------------------------------------
            // Server identifier fallback.
            //
            // Apple documents that recurring occurrences can share
            // the same external identifier, so occurrenceDate is
            // used to distinguish them.
            // ----------------------------------------------------

            if
                matchingIndex == nil,
                let serverIdentifier =
                    source
                        .calendarItemExternalIdentifier,
                !serverIdentifier.isEmpty
            {
                matchingIndex =
                    data.calendarEvents
                        .firstIndex(
                            where: {
                                event in

                                guard
                                    event.calendarID
                                        == calendarID,
                                    event.iCalUID
                                        == serverIdentifier
                                else {
                                    return false
                                }

                                return
                                    appleOccurrenceMatches(
                                        event
                                            .originalStartAt,
                                        source
                                            .occurrenceDate
                                    )
                            }
                        )
            }


            // ----------------------------------------------------
            // Last-resort cached-property recovery.
            //
            // calendarItemIdentifier can change after a complete
            // calendar sync, so title/start/end provide a recovery
            // path when EventKit IDs have changed.
            // ----------------------------------------------------

            if matchingIndex == nil {
                matchingIndex =
                    data.calendarEvents
                        .firstIndex(
                            where: {
                                event in

                                guard
                                    event.calendarID
                                        == calendarID,
                                    event.title
                                        == source.title
                                else {
                                    return false
                                }

                                return
                                    abs(
                                        event
                                            .startAt
                                            .timeIntervalSince(
                                                source
                                                    .startAt
                                            )
                                    )
                                    < 1
                                    && abs(
                                        event
                                            .endAt
                                            .timeIntervalSince(
                                                source
                                                    .endAt
                                            )
                                    )
                                    < 1
                            }
                        )
            }


            if let matchingIndex {
                var existing =
                    data.calendarEvents[
                        matchingIndex
                    ]

                existing.externalID =
                    source
                        .eventIdentifier
                    ?? source
                        .calendarItemIdentifier

                existing.iCalUID =
                    source
                        .calendarItemExternalIdentifier

                existing.title =
                    source.title

                existing.notes =
                    source.notes

                existing.location =
                    source.location

                existing.startAt =
                    source.startAt

                existing.endAt =
                    source.endAt

                existing.isAllDay =
                    source.isAllDay

                existing.startTimeZoneID =
                    source.timeZoneID

                existing.endTimeZoneID =
                    source.timeZoneID

                existing.status =
                    source.status

                existing.recurrenceRules =
                    source
                        .recurrenceRules

                existing.recurringEventExternalID =
                    source
                        .occurrenceDate
                        == nil
                    ? nil
                    : source
                        .calendarItemExternalIdentifier

                existing.originalStartAt =
                    source
                        .occurrenceDate

                existing.organizerName =
                    source
                        .organizerName

                existing.organizerEmail =
                    source
                        .organizerEmail

                existing.attendeeEmails =
                    source
                        .attendeeEmails

                existing.externalURL =
                    source
                        .externalURL

                existing.externalCreatedAt =
                    source
                        .createdAt

                existing.externalUpdatedAt =
                    source
                        .updatedAt

                existing.syncState =
                    .synced

                existing.lastSyncedAt =
                    now

                existing.updatedAt =
                    now

                data.calendarEvents[
                    matchingIndex
                ] =
                    existing

                matchedIDs.insert(
                    existing.id
                )

            } else {
                let newEvent =
                    CalendarEvent(
                        calendarID:
                            calendarID,
                        externalID:
                            source
                                .eventIdentifier
                            ?? source
                                .calendarItemIdentifier,
                        iCalUID:
                            source
                                .calendarItemExternalIdentifier,
                        externalURL:
                            source
                                .externalURL,
                        title:
                            source.title,
                        notes:
                            source.notes,
                        location:
                            source.location,
                        startAt:
                            source.startAt,
                        endAt:
                            source.endAt,
                        isAllDay:
                            source.isAllDay,
                        startTimeZoneID:
                            source
                                .timeZoneID,
                        endTimeZoneID:
                            source
                                .timeZoneID,
                        status:
                            source.status,
                        recurrenceRules:
                            source
                                .recurrenceRules,
                        recurringEventExternalID:
                            source
                                .occurrenceDate
                                == nil
                            ? nil
                            : source
                                .calendarItemExternalIdentifier,
                        originalStartAt:
                            source
                                .occurrenceDate,
                        organizerName:
                            source
                                .organizerName,
                        organizerEmail:
                            source
                                .organizerEmail,
                        attendeeEmails:
                            source
                                .attendeeEmails,
                        syncState:
                            .synced,
                        externalCreatedAt:
                            source
                                .createdAt,
                        externalUpdatedAt:
                            source
                                .updatedAt,
                        lastSyncedAt:
                            now
                    )

                data.calendarEvents.append(
                    newEvent
                )

                matchedIDs.insert(
                    newEvent.id
                )
            }
        }


        // --------------------------------------------------------
        // External event no longer returned by EventKit.
        //
        // Preserve the cached details and, importantly, preserve
        // all Testudo relations. The Sync state communicates that
        // the external item is no longer available.
        // --------------------------------------------------------

        for index in
            data.calendarEvents.indices
        {
            let event =
                data.calendarEvents[
                    index
                ]

            guard
                previouslyCachedIDs
                    .contains(
                        event.id
                    ),
                !matchedIDs
                    .contains(
                        event.id
                    )
            else {
                continue
            }

            data.calendarEvents[
                index
            ]
            .syncState =
                .conflict

            data.calendarEvents[
                index
            ]
            .lastSyncedAt =
                now

            data.calendarEvents[
                index
            ]
            .updatedAt =
                now
        }
    }


    private func appleOccurrenceMatches(
        _ lhs:
            Date?,
        _ rhs:
            Date?
    ) -> Bool
    {
        switch (
            lhs,
            rhs
        ) {
        case (
            nil,
            nil
        ):
            return true

        case let (
            lhs?,
            rhs?
        ):
            return
                abs(
                    lhs
                        .timeIntervalSince(
                            rhs
                        )
                )
                < 1

        default:
            return false
        }
    }
}


// ============================================================
// MARK: - External Calendar Management
// ============================================================

@MainActor
extension TestudoStore
{
    func syncExternalCalendar(
        id:
            UUID
    ) async -> String?
    {
        guard
            let calendar =
                dReportCalendar(
                    id:
                        id
                )
        else {
            return
                "Calendar not found."
        }


        switch calendar.sourceKind {
        case .iCalSubscription:
            return
                await
                    syncICalCalendar(
                        id:
                            id
                    )

        case .appleEventKit:
            return
                await
                    syncAppleCalendar(
                        id:
                            id
                    )

        case .local,
             .none:
            return
                "This is not an external calendar."
        }
    }


    @discardableResult
    func disconnectExternalCalendar(
        id:
            UUID
    ) -> String?
    {
        guard
            let calendar =
                dReportCalendar(
                    id:
                        id
                )
        else {
            return
                "Calendar not found."
        }


        guard
            calendar.sourceKind
                == .iCalSubscription
            || calendar.sourceKind
                == .appleEventKit
        else {
            return
                "This is not an external calendar."
        }


        // ----------------------------------------------------
        // Remove private iCal credential from Keychain.
        //
        // Apple/EventKit connections do not store credentials
        // inside Testudo.
        // ----------------------------------------------------

        if
            calendar.sourceKind
                == .iCalSubscription,
            let key =
                calendar
                    .secretURLKeychainAccount
        {
            CalendarSecretStore
                .delete(
                    account:
                        key
                )
        }


        // ----------------------------------------------------
        // Find every event imported from this calendar.
        // ----------------------------------------------------

        let eventIDs =
            Set(
                data.calendarEvents
                    .filter {
                        $0.calendarID
                            == id
                    }
                    .map(\.id)
            )


        // ----------------------------------------------------
        // Remove Testudo relationships belonging to those
        // imported events.
        // ----------------------------------------------------

        data.calendarEventWorkLinks
            .removeAll {
                eventIDs.contains(
                    $0.calendarEventID
                )
            }

        data.calendarEventThemeLinks
            .removeAll {
                eventIDs.contains(
                    $0.calendarEventID
                )
            }


        // ----------------------------------------------------
        // Remove imported events.
        // ----------------------------------------------------

        data.calendarEvents
            .removeAll {
                $0.calendarID
                    == id
            }


        // ----------------------------------------------------
        // Finally remove the calendar connection metadata.
        // ----------------------------------------------------

        data.calendars
            .removeAll {
                $0.id
                    == id
            }


        save()

        return nil
    }
}
