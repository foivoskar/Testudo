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
        ensureAllPeopleHaveProfiles()
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
                createdByUserID:
                    currentUserID,
                updatedByUserID:
                    currentUserID,
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
                actorUserID:
                    currentUserID,
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

        data.workItems[index].updatedByUserID =
            currentUserID

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
                actorUserID:
                    currentUserID
,
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

        if let userIndex =
            data.users.firstIndex(
                where: {
                    $0.personEntityID
                        == updated.entityID
                }
            )
        {
            data.users[userIndex].firstName =
                updated.firstName

            data.users[userIndex].lastName =
                updated.lastName

            data.users[userIndex].avatarData =
                updated.avatarData
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

    func addMemberLinkedToExistingPerson(
        username: String,
        password: String,
        personEntityID: UUID
    ) -> String? {
        guard currentUserIsAdministrator else {
            return "Administrator rights are required."
        }

        let cleanedUsername =
            username.trimmingCharacters(
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
            return "Username cannot contain spaces."
        }

        guard password.count >= 8 else {
            return "Password must contain at least 8 characters."
        }

        guard
            let person =
                data.entities.first(
                    where: {
                        $0.id == personEntityID
                        && $0.kind == .person
                    }
                )
        else {
            return "The selected Person no longer exists."
        }

        guard
            !data.users.contains(
                where: {
                    $0.personEntityID
                        == personEntityID
                }
            )
        else {
            return "This Person already has a user account."
        }

        guard
            !data.users.contains(
                where: {
                    $0.username
                        .caseInsensitiveCompare(
                            cleanedUsername
                        )
                        == .orderedSame
                }
            )
        else {
            return "That username already exists."
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
                        password: password
                    )
        } catch {
            return "The password could not be secured."
        }

        let profile =
            personProfile(
                for: personEntityID
            )

        let user =
            DReportUser(
                personEntityID:
                    personEntityID,
                username:
                    cleanedUsername,
                firstName:
                    profile?.firstName
                    ?? person.name,
                lastName:
                    profile?.lastName
                    ?? "",
                role:
                    .member,
                passwordSaltBase64:
                    hash.saltBase64,
                passwordHashBase64:
                    hash.hashBase64,
                passwordIterations:
                    hash.iterations,
                avatarData:
                    profile?.avatarData
            )

        data.users.append(user)

        data.schemaVersion =
            max(
                data.schemaVersion,
                4
            )

        save()

        return nil
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
    func user(
        id: UUID
    ) -> DReportUser? {
        data.users.first {
            $0.id == id
        }
    }

    func availablePeopleForUserLink(
        userID: UUID
    ) -> [Entity] {
        guard
            let user =
                user(id: userID)
        else {
            return []
        }

        return data.entities
            .filter {
                $0.kind == .person
            }
            .filter { person in
                if
                    person.id
                        == user.personEntityID
                {
                    return true
                }

                return !data.users.contains {
                    $0.id != userID
                    && $0.personEntityID
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

    func updateUsername(
        userID: UUID,
        username: String
    ) -> String? {
        guard
            currentUserIsAdministrator
        else {
            return
                "Administrator rights are required."
        }

        let cleaned =
            username.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleaned.isEmpty else {
            return "Username is required."
        }

        guard
            cleaned.rangeOfCharacter(
                from: .whitespacesAndNewlines
            ) == nil
        else {
            return
                "Username cannot contain spaces."
        }

        guard
            let index =
                data.users.firstIndex(
                    where: {
                        $0.id == userID
                    }
                )
        else {
            return "User not found."
        }

        let duplicate =
            data.users.contains {
                $0.id != userID
                && $0.username
                    .caseInsensitiveCompare(
                        cleaned
                    )
                    == .orderedSame
            }

        guard !duplicate else {
            return
                "That username already exists."
        }

        data.users[index].username =
            cleaned

        save()

        return nil
    }

    func changeUserPassword(
        userID: UUID,
        newPassword: String
    ) -> String? {
        guard
            currentUserIsAdministrator
        else {
            return
                "Administrator rights are required."
        }

        guard
            data.users.contains(
                where: {
                    $0.id == userID
                }
            )
        else {
            return "User not found."
        }

        guard
            newPassword.count >= 8
        else {
            return
                "Password must contain at least 8 characters."
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
                            newPassword
                    )
        } catch {
            return
                "The password could not be secured."
        }

        guard
            let index =
                data.users.firstIndex(
                    where: {
                        $0.id == userID
                    }
                )
        else {
            return "User not found."
        }

        data.users[index]
            .passwordSaltBase64 =
            hash.saltBase64

        data.users[index]
            .passwordHashBase64 =
            hash.hashBase64

        data.users[index]
            .passwordIterations =
            hash.iterations

        save()

        return nil
    }

    func relinkUser(
        userID: UUID,
        toPerson personEntityID: UUID
    ) -> String? {
        guard
            currentUserIsAdministrator
        else {
            return
                "Administrator rights are required."
        }

        guard
            let userIndex =
                data.users.firstIndex(
                    where: {
                        $0.id == userID
                    }
                )
        else {
            return "User not found."
        }

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
            return "Person not found."
        }

        let alreadyLinked =
            data.users.contains {
                $0.id != userID
                && $0.personEntityID
                    == personEntityID
            }

        guard !alreadyLinked else {
            return
                "This Person already has a DReport user account."
        }

        data.users[userIndex]
            .personEntityID =
            personEntityID

        if
            let profile =
                personProfile(
                    for: personEntityID
                )
        {
            data.users[userIndex]
                .firstName =
                profile.firstName

            data.users[userIndex]
                .lastName =
                profile.lastName

            data.users[userIndex]
                .avatarData =
                profile.avatarData
        } else {
            data.users[userIndex]
                .firstName =
                person.name

            data.users[userIndex]
                .lastName =
                ""
        }

        save()

        return nil
    }

    func setUserActive(
        userID: UUID,
        isActive: Bool
    ) -> String? {
        guard
            currentUserIsAdministrator
        else {
            return
                "Administrator rights are required."
        }

        guard
            let index =
                data.users.firstIndex(
                    where: {
                        $0.id == userID
                    }
                )
        else {
            return "User not found."
        }

        if
            !isActive,
            currentUserID == userID
        {
            return
                "You cannot disable the account you are currently using."
        }

        if
            !isActive,
            data.users[index].role
                == .administrator
        {
            let otherActiveAdmins =
                data.users.filter {
                    $0.id != userID
                    && $0.role
                        == .administrator
                    && $0.isActive
                }

            guard
                !otherActiveAdmins.isEmpty
            else {
                return
                    "The last active Administrator cannot be disabled."
            }
        }

        data.users[index].isActive =
            isActive

        if !isActive {
            if
                PersistentSession
                    .loadUserID()
                    == userID
            {
                PersistentSession.clear()
            }
        }

        save()

        return nil
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


extension DReportStore {
    func resetApplication() {
        guard currentUserIsAdministrator else {
            return
        }

        PersistentSession.clear()

        currentUserID = nil

        data = DReportData()

        save()
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
            .updatedByUserID =
            currentUserID

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
            .updatedByUserID =
            currentUserID

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
                    actorUserID:
                        currentUserID,
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
                createdByUserID:
                    currentUserID,
                updatedByUserID:
                    currentUserID,
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
                actorUserID:
                    currentUserID
,
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
                actorUserID:
                    currentUserID,
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
    func verifyCurrentUserPassword(
        _ password: String
    ) -> Bool {
        guard
            let user =
                currentUser,
            user.isActive
        else {
            return false
        }

        return PasswordHasher.verify(
            password:
                password,
            saltBase64:
                user.passwordSaltBase64,
            expectedHashBase64:
                user.passwordHashBase64,
            iterations:
                user.passwordIterations
        )
    }
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
            let linkedUser =
                user(
                    linkedToPerson:
                        id
                )
        {
            return
                "This Person is linked to the DReport account @\(linkedUser.username). Remove or unlink that account before deleting the Person."
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
