import Foundation
import Combine

@MainActor
final class DReportStore: ObservableObject {
    @Published private(set) var data: DReportData

    @Published
    private(set)
    var currentUserID: UUID?

    let fileURL: URL

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

        if
            let storedData = try? Data(contentsOf: fileURL),
            let decoded = Self.decode(storedData)
        {
            data = decoded
        } else {
            data = DReportData()
        }

        migrateUsersToPeopleIfNeeded()
        restorePersistentSessionIfPossible()
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

    func createWorkItem(
        themeID: UUID?,
        parentWorkItemID: UUID?,
        kind: WorkItemKind,
        title: String,
        body: String,
        deadlineAt: Date?
    ) {
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
            return
        }

        let now = Date()

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
                createdByUserID:
                    currentUserID,
                updatedByUserID:
                    currentUserID
            )

        data.workItems.append(item)

        data.historyEvents.append(
            HistoryEvent(
                workItemID: item.id,
                kind: .created,
                timestamp: now,
                text:
                    "Created \(kind.displayName.lowercased())",
                actorUserID:
                    currentUserID
            )
        )

        save()
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

        let previous =
            data.workItems[index].status

        guard previous != status else {
            return
        }

        let now = Date()

        data.workItems[index].status =
            status

        data.workItems[index].updatedAt =
            now

        data.workItems[index].updatedByUserID =
            currentUserID

        if
            status == .inProgress,
            data.workItems[index].startedAt
                == nil
        {
            data.workItems[index].startedAt =
                now
        }

        if status == .completed {
            data.workItems[index].completedAt =
                now
        } else {
            data.workItems[index].completedAt =
                nil
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
                actorUserID:
                    currentUserID
            )
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
            Calendar.current

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

    func createEntity(
        kind: EntityKind,
        name: String,
        initialContainerID: UUID?
    ) {
        let cleaned =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleaned.isEmpty else {
            return
        }

        let entity =
            Entity(
                kind: kind,
                name: cleaned
            )

        data.entities.append(entity)

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

    func personEntity(
        for user: DReportUser
    ) -> Entity? {
        guard
            let personID =
                user.personEntityID
        else {
            return nil
        }

        return data.entities.first {
            $0.id == personID
            && $0.kind == .person
        }
    }

    func user(
        linkedToPerson entityID: UUID
    ) -> DReportUser? {
        data.users.first {
            $0.personEntityID == entityID
        }
    }

    var peopleWithoutUserAccounts:
        [Entity]
    {
        data.entities
            .filter {
                $0.kind == .person
            }
            .filter { person in
                !data.users.contains {
                    $0.personEntityID
                        == person.id
                }
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

    private func migrateUsersToPeopleIfNeeded() {
        var changed = false

        for index in data.users.indices {
            if
                let personID =
                    data.users[index]
                        .personEntityID,
                data.entities.contains(
                    where: {
                        $0.id == personID
                        && $0.kind == .person
                    }
                )
            {
                if !data.personProfiles.contains(
                    where: {
                        $0.entityID
                            == personID
                    }
                ) {
                    data.personProfiles.append(
                        PersonProfile(
                            entityID:
                                personID,
                            firstName:
                                data.users[index]
                                    .firstName,
                            lastName:
                                data.users[index]
                                    .lastName,
                            avatarData:
                                data.users[index]
                                    .avatarData
                        )
                    )

                    changed = true
                }

                continue
            }

            let personID =
                createPersonForUser(
                    firstName:
                        data.users[index]
                            .firstName,
                    lastName:
                        data.users[index]
                            .lastName,
                    avatarData:
                        data.users[index]
                            .avatarData
                )

            data.users[index]
                .personEntityID =
                personID

            changed = true
        }

        if changed {
            data.schemaVersion =
                max(
                    data.schemaVersion,
                    3
                )

            save()
        }
    }
}


extension DReportStore {
    var users: [DReportUser] {
        data.users.sorted {
            $0.displayName
                .localizedCaseInsensitiveCompare(
                    $1.displayName
                )
                == .orderedAscending
        }
    }

    var currentUser: DReportUser? {
        guard
            let currentUserID
        else {
            return nil
        }

        return data.users.first {
            $0.id == currentUserID
        }
    }

    var hasUsers: Bool {
        !data.users.isEmpty
    }

    var currentUserIsAdministrator:
        Bool
    {
        currentUser?.role
            == .administrator
    }

    func createInitialAdministrator(
        username: String,
        firstName: String,
        lastName: String,
        password: String,
        avatarData: Data?,
        staySignedIn: Bool
    ) -> String? {
        guard data.users.isEmpty else {
            return
                "An administrator account already exists."
        }

        return createUser(
            username: username,
            firstName: firstName,
            lastName: lastName,
            password: password,
            avatarData: avatarData,
            role: .administrator,
            signInAfterCreation: true,
            staySignedIn:
                staySignedIn
        )
    }

    func addMember(
        username: String,
        firstName: String,
        lastName: String,
        password: String,
        avatarData: Data?
    ) -> String? {
        guard
            currentUserIsAdministrator
        else {
            return
                "Administrator rights are required."
        }

        return createUser(
            username: username,
            firstName: firstName,
            lastName: lastName,
            password: password,
            avatarData: avatarData,
            role: .member,
            signInAfterCreation: false,
            staySignedIn: false
        )
    }

    func login(
        username: String,
        password: String,
        staySignedIn: Bool
    ) -> String? {
        let cleanedUsername =
            username.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            let index =
                data.users.firstIndex(
                    where: {
                        $0.username
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

        let user =
            data.users[index]

        guard user.isActive else {
            return
                "This account is disabled."
        }

        guard
            PasswordHasher.verify(
                password: password,
                saltBase64:
                    user.passwordSaltBase64,
                expectedHashBase64:
                    user.passwordHashBase64,
                iterations:
                    user.passwordIterations
            )
        else {
            return
                "Incorrect username or password."
        }

        currentUserID =
            user.id

        data.users[index].lastLoginAt =
            Date()

        data.schemaVersion =
            max(
                data.schemaVersion,
                3
            )

        if staySignedIn {
            PersistentSession.save(
                userID: user.id
            )
        } else {
            PersistentSession.clear()
        }

        save()

        return nil
    }

    func signOut() {
        PersistentSession.clear()
        currentUserID = nil
    }

    private func createUser(
        username: String,
        firstName: String,
        lastName: String,
        password: String,
        avatarData: Data?,
        role: UserRole,
        signInAfterCreation: Bool,
        staySignedIn: Bool
    ) -> String? {
        let cleanedUsername =
            username.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanedFirstName =
            firstName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanedLastName =
            lastName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanedUsername.isEmpty else {
            return "Username is required."
        }

        guard
            cleanedUsername.rangeOfCharacter(
                from: .whitespacesAndNewlines
            ) == nil
        else {
            return
                "Username cannot contain spaces."
        }

        guard !cleanedFirstName.isEmpty else {
            return
                "First name is required."
        }

        guard password.count >= 8 else {
            return
                "Password must contain at least 8 characters."
        }

        let usernameExists =
            data.users.contains {
                $0.username
                    .caseInsensitiveCompare(
                        cleanedUsername
                    )
                    == .orderedSame
            }

        guard !usernameExists else {
            return
                "That username already exists."
        }

        let hash:
            (
                saltBase64: String,
                hashBase64: String,
                iterations: Int
            )

        do {
            hash =
                try PasswordHasher
                    .createHash(
                        password:
                            password
                    )
        } catch {
            return
                "The password could not be secured."
        }

        let now = Date()

        let personEntityID =
            createPersonForUser(
                firstName:
                    cleanedFirstName,
                lastName:
                    cleanedLastName,
                avatarData:
                    avatarData
            )

        let user =
            DReportUser(
                personEntityID:
                    personEntityID,
                username:
                    cleanedUsername,
                firstName:
                    cleanedFirstName,
                lastName:
                    cleanedLastName,
                role:
                    role,
                passwordSaltBase64:
                    hash.saltBase64,
                passwordHashBase64:
                    hash.hashBase64,
                passwordIterations:
                    hash.iterations,
                avatarData:
                    avatarData,
                createdAt:
                    now,
                lastLoginAt:
                    signInAfterCreation
                    ? now
                    : nil
            )

        data.users.append(user)

        data.schemaVersion =
            max(
                data.schemaVersion,
                3
            )

        if signInAfterCreation {
            currentUserID =
                user.id

            if staySignedIn {
                PersistentSession.save(
                    userID:
                        user.id
                )
            } else {
                PersistentSession.clear()
            }
        }

        save()

        return nil
    }

    private func restorePersistentSessionIfPossible() {
        guard
            let storedID =
                PersistentSession
                    .loadUserID(),
            let user =
                data.users.first(
                    where: {
                        $0.id == storedID
                    }
                ),
            user.isActive
        else {
            PersistentSession.clear()
            currentUserID = nil
            return
        }

        currentUserID =
            storedID
    }
}
