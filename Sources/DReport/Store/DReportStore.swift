import Foundation
import Combine

@MainActor
final class DReportStore: ObservableObject {
    @Published private(set) var data: DReportData

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
                    "DReport",
                    isDirectory: true
                )

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            print(
                "DReport: could not create storage directory:",
                error
            )
        }

        fileURL =
            directory
                .appendingPathComponent("DReportData.json")

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
            DReportData()


        // ----------------------------------------------------
        // Resolve the database belonging to the active
        // Work Environment.
        //
        // Existing installations still have the historical
        // DReportData.json at the application root. The first
        // Environment migration copies it into:
        //
        //   DReport/
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
                            "DReport: migrated legacy database to Environment:",
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
                    "DReport: could not prepare Environment database:",
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
            data = DReportData()
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

        environmentSessionIsOpen = false
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
                "DReport: could not write Environment manifest:",
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
            URL
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
                    nil,
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
            DReportData()

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
                    "That identity identifier is already used by another Environment membership."
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
                        }
                    ),
            membership.isActive
        else {
            environmentSessionIsOpen =
                false

            return
                .identityRequired
        }


        if
            environmentMembershipNeedsPassword(
                id:
                    membership.id
            )
        {
            environmentSessionIsOpen =
                false

            return
                .identityRequired
        }



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
                Date()

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
        membershipID:
            UUID,
        password:
            String
    ) -> String? {
        guard
            let environmentID =
                activeEnvironmentID
        else {
            return
                "No Work Environment is active."
        }


        guard
            let membershipIndex =
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


        let membership =
            data.environmentMemberships[
                membershipIndex
            ]


        guard membership.isActive else {
            return
                "This Environment membership is disabled."
        }


        if
            let credential =
                environmentCredential(
                    for:
                        membership.id
                )
        {
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

        } else if
            environmentMembershipHasPassword(
                id:
                    membership.id
            )
        {
            return
                "The Environment credential is unavailable."
        }


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
                .environmentAccesses[index]
                .membershipID =
                membershipID

            applicationData
                .environmentAccesses[index]
                .lastOpenedAt =
                Date()
        } else {
            applicationData
                .environmentAccesses
                .append(
                    EnvironmentAccess(
                        environmentID:
                            environmentID,
                        membershipID:
                            membershipID,
                        lastOpenedAt:
                            Date()
                    )
                )
        }


        data.environmentMemberships[
            membershipIndex
        ]
        .lastAccessAt =
            Date()


        environmentSessionIsOpen =
            true



        saveApplicationData()
        save()

        return nil
    }


    func closeWorkEnvironment() {
        environmentSessionIsOpen =
            false

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
                "DReport: could not decode application data:",
                error
            )

            return nil
        }
    }


    private static func decode(
        _ rawData: Data
    ) -> DReportData? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(
                DReportData.self,
                from: rawData
            )
        } catch {
            print(
                "DReport: could not decode stored data:",
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
                "DReport: could not save application data:",
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
                "DReport: could not save data:",
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
            DReportTime
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
                        DReportTime
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
                    DReportTime
                        .utcString(
                            deadlineAt
                        ),
                valueTimeZoneID:
                    DReportTime
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
        data.workItems
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

        if
            status == .closed,
            data.workItems[index]
                .parentWorkItemID != nil
        {
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
            DReportTime
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
        } else if status != .closed {
            data.workItems[index].completedAt =
                nil

            data.workItems[index]
                .completedTimeZoneID =
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
        data.workItems
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

        return data.workItems
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


extension DReportStore {
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
            DReportTime
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


extension DReportStore {
}


extension DReportStore {
}


extension DReportStore {

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

        environmentSessionIsOpen =
            false

        applicationData =
            ApplicationData()

        saveApplicationData()
    }
}

extension DReportStore {
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

        if
            status == .closed,
            parentWorkItemID != nil
        {
            return
                "Only top-level Tasks can be Closed."
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
            DReportTime
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
                    DReportTime
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
                newStatus
                    != .closed,
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
                    DReportTime
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
                DReportTime
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
                            DReportTime
                                .utcString(
                                    $0
                                )
                        },
                    newValue:
                        DReportTime
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


extension DReportStore {
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
            DReportTime
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
        role: WorkRelationshipRole
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

extension DReportStore {
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
            DReportTime
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
                    ? (
                        occurredAt
                        ?? now
                    )
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
                        DReportTime
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
                        DReportTime
                            .validTimeZoneIdentifier(
                                reminderTimeZoneID
                            )
                        ?? currentTimeZoneID
                    )
                    : nil,
                loggedTimeZoneID:
                    kind == .activity
                    ? (
                        DReportTime
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
                    ? "Logged event"
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
                    DReportTime
                        .utcString(
                            deadlineAt
                        ),
                valueTimeZoneID:
                    DReportTime
                        .validTimeZoneIdentifier(
                            deadlineTimeZoneID
                        )
                    ?? currentTimeZoneID
            )
        }

        save()

        return (
            item.id,
            nil
        )
    }
}

extension DReportStore {
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
                    DReportTime
                        .deviceTimeZoneID,
                valueTimeZoneID:
                    valueTimeZoneID
            )
        )
    }
}

extension DReportStore {
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

extension DReportStore {
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



extension DReportStore {

}



extension DReportStore {
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

extension DReportStore {
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
                        false
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

        guard
            !indices.isEmpty
        else {
            return
        }

        if
            let firstPrimary =
                indices.first(
                    where: {
                        data.memberships[$0]
                            .isPrimary
                    }
                )
        {
            for index in indices {
                data.memberships[index]
                    .isPrimary =
                    index
                    == firstPrimary
            }

        } else if
            let first =
                indices.first
        {
            data.memberships[first]
                .isPrimary =
                true
        }
    }
}


// MARK: - Calendar Domain

extension DReportStore {

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
    ) -> DReportCalendar? {
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
            DReportCalendar(
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

extension DReportStore {
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
extension DReportStore {

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
                DReportCalendar(
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
                        "DReport.iCal",
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

extension DReportStore {

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

extension DReportStore {

    func archivedRootTasks()
        -> [WorkItem]
    {
        data.workItems
            .filter {
                $0.kind == .task
                && $0.parentWorkItemID == nil
                && $0.status == .closed
            }
            .sorted {
                $0.updatedAt
                    > $1.updatedAt
            }
    }


    func archivedRootID(
        for item: WorkItem
    ) -> UUID? {
        var current:
            WorkItem? = item

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
                work.status == .closed
            {
                return work.id
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
        _ item: WorkItem
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

extension DReportStore {

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



extension DReportStore {

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
                    "That identity identifier is already used by another Environment membership."
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

extension DReportStore {

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

extension DReportStore {

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

extension DReportStore {

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

extension DReportStore {

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
// The migration operates on raw JSON before DReportData is decoded,
// so the legacy Swift account model no longer needs to exist.
// ============================================================

extension DReportStore {

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
                    "DReport.SchemaMigration",
                code:
                    8,
                userInfo:
                    [
                        NSLocalizedDescriptionKey:
                            "This Environment predates schema 7 and must first be migrated by an earlier DReport build."
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
                        "DReport.SchemaMigration",
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
                        "DReport.SchemaMigration",
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
                                "DReport.SchemaMigration",
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

extension DReportStore {

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

extension DReportStore {

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
                DReportData()
        }


        saveApplicationData()


        return nil
    }
}


// ============================================================
// MARK: - Import local profile into current Environment Person
// ============================================================

extension DReportStore {

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
