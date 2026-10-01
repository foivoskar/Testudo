import SwiftUI
import AppKit

struct PeopleListView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Binding
    var selection: UUID?

    var body: some View {
        let people =
            store.entities(
                of: .person
            )

        if people.isEmpty {
            ContentUnavailableView {
                Label(
                    "No People Yet",
                    systemImage: "person.2"
                )
            } description: {
                Text(
                    "Create a person to start building your professional directory."
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            List(
                selection: $selection
            ) {
                ForEach(people) { person in
                    PersonListRow(
                        person: person
                    )
                    .tag(person.id)
                }
            }
        }
    }
}

private struct PersonListRow: View {
    @EnvironmentObject
    private var store: DReportStore

    let person: Entity

    var body: some View {
        HStack(spacing: 10) {
            PersonSmallAvatar(
                person: person,
                profile:
                    store.personProfile(
                        for: person.id
                    )
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(person.name)
                    .fontWeight(.medium)

                let profile =
                    store.personProfile(
                        for: person.id
                    )

                let affiliations =
                    store.containers(
                        for: person.id
                    )

                let secondary =
                    secondaryText(
                        profile: profile,
                        affiliations:
                            affiliations
                    )

                if !secondary.isEmpty {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                }
            }

            Spacer()

            if
                store.user(
                    linkedToPerson:
                        person.id
                ) != nil
            {
                Image(
                    systemName:
                        "person.crop.circle.badge.checkmark"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .help(
                    "DReport user account"
                )
            }
        }
        .padding(.vertical, 3)
    }

    private func secondaryText(
        profile: PersonProfile?,
        affiliations: [Entity]
    ) -> String {
        var parts: [String] = []

        if
            let title =
                profile?.jobTitle,
            !title.isEmpty
        {
            parts.append(title)
        }

        if
            let first =
                affiliations.first
        {
            parts.append(first.name)
        }

        return parts.joined(
            separator: " · "
        )
    }
}

private struct PersonSmallAvatar: View {
    let person: Entity
    let profile: PersonProfile?

    var body: some View {
        if
            let data =
                profile?.avatarData,
            let image =
                NSImage(data: data)
        {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: 30,
                    height: 30
                )
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(
                        Color.accentColor
                            .opacity(0.12)
                    )

                Text(initial)
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
            }
            .frame(
                width: 30,
                height: 30
            )
        }
    }

    private var initial: String {
        if
            let first =
                profile?.firstName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .first
        {
            return String(first)
                .uppercased()
        }

        return String(
            person.name.first ?? "?"
        )
        .uppercased()
    }
}

struct PersonDetailView: View {
    @EnvironmentObject
    private var store: DReportStore

    let personID: UUID

    @State
    private var showingEditor = false

    @State
    private var showingAccountManager = false

    var body: some View {
        if
            let person =
                store.entity(
                    id: personID
                )
        {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 26
                ) {
                    if !relatedWorkItems.isEmpty {
                        relatedWorkSection

                        Divider()
                    }

                    personProfile(
                        person: person
                    )
                }
                .padding(24)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            .background(
                DReportStyle.contentBackground
            )
            .sheet(
                isPresented:
                    $showingEditor
            ) {
                PersonEditView(
                    personID:
                        personID
                )
            }
            .sheet(
                isPresented:
                    $showingAccountManager
            ) {
                if
                    let user =
                        store.user(
                            linkedToPerson:
                                personID
                        )
                {
                    UserAccountEditorView(
                        userID:
                            user.id,
                        showsCloseButton:
                            true
                    )
                    .frame(
                        minWidth: 680,
                        idealWidth: 720,
                        minHeight: 600,
                        idealHeight: 650
                    )
                }
            }
        } else {
            ContentUnavailableView(
                "Person Not Found",
                systemImage:
                    "person.crop.circle.badge.questionmark"
            )
        }
    }

    private var relatedWorkSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            HStack {
                Text("Related Work")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Text(
                    "\(relatedWorkItems.count)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            VStack(spacing: 0) {
                ForEach(
                    relatedWorkItems
                ) { item in
                    RelatedWorkRow(
                        item: item
                    )

                    if
                        item.id
                            != relatedWorkItems
                                .last?.id
                    {
                        Divider()
                            .padding(
                                .leading,
                                30
                            )
                    }
                }
            }
        }
    }

    private func personProfile(
        person: Entity
    ) -> some View {
        let profile =
            store.personProfile(
                for: personID
            )

        return VStack(
            alignment: .leading,
            spacing: 26
        ) {
            HStack(
                alignment: .center,
                spacing: 16
            ) {
                PersonLargeAvatar(
                    person: person,
                    profile: profile
                )

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        profile?.displayName
                            .isEmpty == false
                        ? profile!.displayName
                        : person.name
                    )
                    .font(.title)
                    .fontWeight(.semibold)

                    if
                        let academic =
                            profile?
                                .academicTitle,
                        !academic.isEmpty
                    {
                        Text(academic)
                            .font(.callout)
                            .foregroundStyle(
                                .secondary
                            )
                    }

                    if
                        let job =
                            profile?.jobTitle,
                        !job.isEmpty
                    {
                        Text(job)
                            .foregroundStyle(
                                .secondary
                            )
                    }

                    let affiliations =
                        store.containers(
                            for: personID
                        )

                    if !affiliations.isEmpty {
                        Text(
                            affiliations
                                .map(\.name)
                                .joined(
                                    separator: " · "
                                )
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Spacer()

                Button {
                    showingEditor = true
                } label: {
                    Label(
                        "Edit",
                        systemImage:
                            "pencil"
                    )
                }
            }

            if let profile {
                readOnlySections(
                    profile: profile
                )
            }

            affiliationsSection

            accountSection
        }
    }

    @ViewBuilder
    private func readOnlySections(
        profile: PersonProfile
    ) -> some View {
        let identityRows =
            compactRows([
                (
                    "First name",
                    profile.firstName
                ),
                (
                    "Middle name",
                    profile.middleName
                ),
                (
                    "Last name",
                    profile.lastName
                ),
                (
                    "Preferred name",
                    profile.preferredName
                ),
                (
                    "Academic title",
                    profile.academicTitle
                ),
                (
                    "Position",
                    profile.jobTitle
                )
            ])

        if !identityRows.isEmpty {
            ReadOnlyProfileSection(
                title: "Identity",
                rows: identityRows
            )
        }

        let contactRows =
            compactRows([
                (
                    "Email",
                    profile.professionalEmail
                ),
                (
                    "Secondary email",
                    profile.secondaryProfessionalEmail
                ),
                (
                    "Phone",
                    profile.professionalPhone
                ),
                (
                    "Secondary phone",
                    profile.secondaryPhone
                ),
                (
                    "Office",
                    profile.office
                ),
                (
                    "Assistant / contact",
                    profile.assistantContact
                )
            ])

        if !contactRows.isEmpty {
            ReadOnlyProfileSection(
                title:
                    "Professional Contact",
                rows:
                    contactRows
            )
        }

        let workplaceRows =
            compactRows([
                (
                    "Staff / employee ID",
                    profile.employeeID
                ),
                (
                    "Address",
                    profile.professionalAddress
                ),
                (
                    "City",
                    profile.city
                ),
                (
                    "Postal code",
                    profile.postalCode
                ),
                (
                    "Country",
                    profile.country
                )
            ])

        if !workplaceRows.isEmpty {
            ReadOnlyProfileSection(
                title: "Workplace",
                rows: workplaceRows
            )
        }

        let onlineRows =
            compactRows([
                (
                    "Website",
                    profile.website
                ),
                (
                    "LinkedIn",
                    profile.linkedIn
                ),
                (
                    "GitHub",
                    profile.github
                )
            ])

        if !onlineRows.isEmpty {
            ReadOnlyProfileSection(
                title: "Online",
                rows: onlineRows
            )
        }

        let researchRows =
            compactRows([
                (
                    "ORCID",
                    profile.orcid
                ),
                (
                    "ResearcherID",
                    profile.researcherID
                ),
                (
                    "Scopus Author ID",
                    profile.scopusAuthorID
                ),
                (
                    "Google Scholar",
                    profile.googleScholarURL
                ),
                (
                    "Fields / expertise",
                    profile.professionalFields
                ),
                (
                    "Responsibilities",
                    profile.responsibilities
                ),
                (
                    "Tags",
                    profile.tags
                )
            ])

        if !researchRows.isEmpty {
            ReadOnlyProfileSection(
                title:
                    "Research & Professional",
                rows:
                    researchRows
            )
        }

        let preferenceRows =
            compactRows([
                (
                    "Preferred language",
                    profile.preferredLanguage
                ),
                (
                    "Time zone",
                    profile.timeZone.map {
                        DReportTime
                            .timeZoneLabel(
                                identifier: $0
                            )
                    }
                )
            ])

        if !preferenceRows.isEmpty {
            ReadOnlyProfileSection(
                title: "Preferences",
                rows: preferenceRows
            )
        }

        if
            !profile.notes
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
        {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text("Notes")
                    .font(.headline)

                Text(profile.notes)
                    .textSelection(
                        .enabled
                    )
            }
        }
    }

    private var affiliationsSection:
        some View
    {
        let affiliations =
            store.containers(
                for: personID
            )

        return Group {
            if !affiliations.isEmpty {
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    Text("Affiliations")
                        .font(.headline)

                    ForEach(
                        affiliations
                    ) { affiliation in
                        HStack(spacing: 8) {
                            Image(
                                systemName:
                                    affiliation.kind
                                        == .organization
                                    ? "building.2"
                                    : "person.3"
                            )
                            .foregroundStyle(
                                .secondary
                            )

                            Text(
                                affiliation.name
                            )
                        }
                    }
                }
            }
        }
    }

    private var accountSection:
        some View
    {
        Group {
            if
                let user =
                    store.user(
                        linkedToPerson:
                            personID
                    )
            {
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    Text("DReport Account")
                        .font(.headline)

                    ReadOnlyValueRow(
                        label: "Username",
                        value:
                            "@\(user.username)"
                    )

                    ReadOnlyValueRow(
                        label: "Role",
                        value:
                            user.role
                                .displayName
                    )

                    ReadOnlyValueRow(
                        label: "Status",
                        value:
                            user.isActive
                            ? "Active"
                            : "Disabled"
                    )

                    if store.currentUserIsAdministrator {
                        Button("Manage Account…") {
                            showingAccountManager = true
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var relatedWorkItems:
        [WorkItem]
    {
        store.data.workItems
            .filter {
                workItemIsRelated(
                    $0
                )
            }
            .sorted {
                $0.updatedAt
                    > $1.updatedAt
            }
    }

    private func workItemIsRelated(
        _ item: WorkItem
    ) -> Bool {
        if
            store.data
                .workEntityRelationships
                .contains(
                    where: {
                        $0.workItemID
                            == item.id
                        && $0.entityID
                            == personID
                    }
                )
        {
            return true
        }

        var currentParent =
            item.parentWorkItemID

        var visited =
            Set<UUID>()

        while let parentID =
            currentParent
        {
            if visited.contains(
                parentID
            ) {
                break
            }

            visited.insert(
                parentID
            )

            if
                store.data
                    .workEntityRelationships
                    .contains(
                        where: {
                            $0.workItemID
                                == parentID
                            && $0.entityID
                                == personID
                            && $0
                                .inheritedByChildren
                        }
                    )
            {
                return true
            }

            currentParent =
                store.workItem(
                    id: parentID
                )?
                .parentWorkItemID
        }

        return false
    }

    private func compactRows(
        _ values:
            [(String, String?)]
    ) -> [(String, String)] {
        values.compactMap {
            label,
            value in

            guard
                let value,
                !value
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            else {
                return nil
            }

            return (
                label,
                value
            )
        }
    }
}

private struct RelatedWorkRow: View {
    @EnvironmentObject
    private var store: DReportStore

    let item: WorkItem

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            Image(
                systemName: icon
            )
            .frame(width: 20)
            .foregroundStyle(
                .secondary
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .fontWeight(.medium)

                HStack(spacing: 7) {
                    Text(typeName)

                    if
                        let status =
                            item.status
                    {
                        Text(
                            status.displayName
                        )
                    }

                    if
                        let theme =
                            store.theme(
                                id: item.themeID
                            )
                    {
                        Text(theme.name)
                    }

                    if
                        let deadline =
                            item.deadlineAt
                    {
                        Text(
                            "Due \(DReportTime.displayDateTime(deadline, sourceTimeZoneID: item.deadlineTimeZoneID))"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                if
                    item.title != nil,
                    !item.body.isEmpty
                {
                    Text(item.body)
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(3)
                }
            }

            Spacer()

            Text(
                relevantDate,
                format:
                    .dateTime
                    .day()
                    .month()
                    .year()
            )
            .font(.caption)
            .foregroundStyle(
                .tertiary
            )
        }
        .padding(.vertical, 8)
    }

    private var title: String {
        if
            let title = item.title,
            !title.isEmpty
        {
            return title
        }

        if !item.body.isEmpty {
            return item.body
        }

        return typeName
    }

    private var typeName: String {
        switch item.kind {
        case .task:
            return "Task"

        case .note:
            return "Note"

        case .activity:
            return "Activity"
        }
    }

    private var icon: String {
        switch item.kind {
        case .task:
            switch item.status {
            case .todo:
                return "circle"
            case .inProgress:
                return "clock"
            case .completed:
                return "checkmark.circle"
            case nil:
                return "circle"
            }

        case .note:
            return "note.text"

        case .activity:
            return "waveform.path.ecg"
        }
    }

    private var relevantDate: Date {
        item.loggedAt
        ?? item.completedAt
        ?? item.startedAt
        ?? item.updatedAt
    }
}

private struct PersonLargeAvatar: View {
    let person: Entity
    let profile: PersonProfile?

    var body: some View {
        if
            let data =
                profile?.avatarData,
            let image =
                NSImage(data: data)
        {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: 64,
                    height: 64
                )
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(
                        Color.accentColor
                            .opacity(0.12)
                    )

                Text(initial)
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
            }
            .frame(
                width: 64,
                height: 64
            )
        }
    }

    private var initial: String {
        if
            let first =
                profile?.firstName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .first
        {
            return String(first)
                .uppercased()
        }

        return String(
            person.name.first ?? "?"
        )
        .uppercased()
    }
}

private struct ReadOnlyProfileSection: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(title)
                .font(.headline)

            VStack(spacing: 7) {
                ForEach(
                    Array(
                        rows.enumerated()
                    ),
                    id: \.offset
                ) { _, row in
                    ReadOnlyValueRow(
                        label: row.0,
                        value: row.1
                    )
                }
            }
        }
    }
}

private struct ReadOnlyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 16
        ) {
            Text(label)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 150,
                    alignment: .leading
                )

            Text(value)
                .textSelection(.enabled)

            Spacer()
        }
        .font(.callout)
    }
}

private struct PersonEditView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Environment(\.dismiss)
    private var dismiss

    let personID: UUID

    @State
    private var draft:
        PersonProfile?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Person")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    save()
                }
                .keyboardShortcut(
                    .defaultAction
                )
            }
            .padding()

            Divider()

            ScrollView {
                if draft != nil {
                    VStack(
                        alignment: .leading,
                        spacing: 24
                    ) {
                        AvatarPicker(
                            avatarData:
                                dataBinding(
                                    \.avatarData
                                )
                        )

                        editSection(
                            "Identity"
                        ) {
                            ProfileTextField(
                                "First name",
                                text:
                                    binding(
                                        \.firstName
                                    )
                            )

                            ProfileTextField(
                                "Middle name",
                                text:
                                    binding(
                                        \.middleName
                                    )
                            )

                            ProfileTextField(
                                "Last name",
                                text:
                                    binding(
                                        \.lastName
                                    )
                            )

                            ProfileTextField(
                                "Preferred / display name",
                                text:
                                    binding(
                                        \.preferredName
                                    )
                            )

                            ProfileTextField(
                                "Academic title",
                                text:
                                    optionalBinding(
                                        \.academicTitle
                                    )
                            )

                            ProfileTextField(
                                "Position / job title",
                                text:
                                    binding(
                                        \.jobTitle
                                    )
                            )
                        }

                        editSection(
                            "Professional Contact"
                        ) {
                            ProfileTextField(
                                "Email",
                                text:
                                    binding(
                                        \.professionalEmail
                                    )
                            )

                            ProfileTextField(
                                "Secondary email",
                                text:
                                    binding(
                                        \.secondaryProfessionalEmail
                                    )
                            )

                            ProfileTextField(
                                "Phone",
                                text:
                                    binding(
                                        \.professionalPhone
                                    )
                            )

                            ProfileTextField(
                                "Secondary phone",
                                text:
                                    optionalBinding(
                                        \.secondaryPhone
                                    )
                            )

                            ProfileTextField(
                                "Office",
                                text:
                                    binding(
                                        \.office
                                    )
                            )

                            ProfileTextField(
                                "Assistant / contact",
                                text:
                                    optionalBinding(
                                        \.assistantContact
                                    )
                            )
                        }

                        editSection(
                            "Workplace"
                        ) {
                            ProfileTextField(
                                "Staff / employee ID",
                                text:
                                    binding(
                                        \.employeeID
                                    )
                            )

                            ProfileTextField(
                                "Address",
                                text:
                                    optionalBinding(
                                        \.professionalAddress
                                    )
                            )

                            ProfileTextField(
                                "City",
                                text:
                                    optionalBinding(
                                        \.city
                                    )
                            )

                            ProfileTextField(
                                "Postal code",
                                text:
                                    optionalBinding(
                                        \.postalCode
                                    )
                            )

                            ProfileTextField(
                                "Country",
                                text:
                                    optionalBinding(
                                        \.country
                                    )
                            )
                        }

                        editSection(
                            "Online"
                        ) {
                            ProfileTextField(
                                "Website",
                                text:
                                    binding(
                                        \.website
                                    )
                            )

                            ProfileTextField(
                                "LinkedIn",
                                text:
                                    binding(
                                        \.linkedIn
                                    )
                            )

                            ProfileTextField(
                                "GitHub",
                                text:
                                    binding(
                                        \.github
                                    )
                            )
                        }

                        editSection(
                            "Research & Professional"
                        ) {
                            ProfileTextField(
                                "ORCID",
                                text:
                                    binding(
                                        \.orcid
                                    )
                            )

                            ProfileTextField(
                                "ResearcherID",
                                text:
                                    optionalBinding(
                                        \.researcherID
                                    )
                            )

                            ProfileTextField(
                                "Scopus Author ID",
                                text:
                                    optionalBinding(
                                        \.scopusAuthorID
                                    )
                            )

                            ProfileTextField(
                                "Google Scholar",
                                text:
                                    optionalBinding(
                                        \.googleScholarURL
                                    )
                            )

                            ProfileTextField(
                                "Fields / expertise",
                                text:
                                    binding(
                                        \.professionalFields
                                    )
                            )

                            ProfileTextField(
                                "Responsibilities",
                                text:
                                    binding(
                                        \.responsibilities
                                    )
                            )

                            ProfileTextField(
                                "Tags",
                                text:
                                    optionalBinding(
                                        \.tags
                                    )
                            )
                        }

                        editSection(
                            "Preferences"
                        ) {
                            ProfileTextField(
                                "Preferred language",
                                text:
                                    optionalBinding(
                                        \.preferredLanguage
                                    )
                            )

                            TimeZoneIdentifierPicker(
                                selection:
                                    optionalBinding(
                                        \.timeZone
                                    )
                            )
                        }

                        affiliationEditor

                        editSection(
                            "Notes"
                        ) {
                            TextEditor(
                                text:
                                    binding(
                                        \.notes
                                    )
                            )
                            .frame(
                                minHeight: 120
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 6
                                )
                                .stroke(
                                    Color.secondary
                                        .opacity(0.2)
                                )
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(
            width: 680,
            height: 720
        )
        .onAppear {
            load()
        }
    }

    private var affiliationEditor:
        some View
    {
        editSection(
            "Affiliations"
        ) {
            let affiliations =
                store.containers(
                    for: personID
                )

            if affiliations.isEmpty {
                Text(
                    "No organization or group affiliations."
                )
                .foregroundStyle(
                    .secondary
                )
            } else {
                ForEach(
                    affiliations
                ) { affiliation in
                    HStack {
                        Image(
                            systemName:
                                affiliation.kind
                                    == .organization
                                ? "building.2"
                                : "person.3"
                        )

                        Text(
                            affiliation.name
                        )

                        Spacer()

                        Button {
                            store.removeMembership(
                                memberID:
                                    personID,
                                containerID:
                                    affiliation.id
                            )
                        } label: {
                            Image(
                                systemName:
                                    "minus.circle"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Menu("Add Affiliation") {
                ForEach(
                    availableAffiliations
                ) { entity in
                    Button(entity.name) {
                        store.addMembership(
                            memberID:
                                personID,
                            containerID:
                                entity.id
                        )
                    }
                }
            }
            .disabled(
                availableAffiliations
                    .isEmpty
            )
        }
    }

    private var availableAffiliations:
        [Entity]
    {
        let current =
            Set(
                store.containers(
                    for: personID
                )
                .map(\.id)
            )

        return store.data.entities
            .filter {
                (
                    $0.kind
                        == .organization
                    || $0.kind
                        == .group
                )
                && !current.contains(
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

    private func editSection<Content: View>(
        _ title: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text(title)
                .font(.headline)

            content()
        }
    }

    private func load() {
        draft =
            store.personProfile(
                for: personID
            )
            ?? PersonProfile(
                entityID:
                    personID
            )
    }

    private func save() {
        guard
            let draft
        else {
            return
        }

        store.savePersonProfile(
            draft
        )

        dismiss()
    }

    private func binding(
        _ keyPath:
            WritableKeyPath<
                PersonProfile,
                String
            >
    ) -> Binding<String> {
        Binding(
            get: {
                draft?[keyPath: keyPath]
                ?? ""
            },
            set: {
                draft?[keyPath: keyPath] =
                    $0
            }
        )
    }

    private func optionalBinding(
        _ keyPath:
            WritableKeyPath<
                PersonProfile,
                String?
            >
    ) -> Binding<String> {
        Binding(
            get: {
                draft?[keyPath: keyPath]
                ?? ""
            },
            set: {
                draft?[keyPath: keyPath] =
                    $0.isEmpty
                    ? nil
                    : $0
            }
        )
    }

    private func dataBinding(
        _ keyPath:
            WritableKeyPath<
                PersonProfile,
                Data?
            >
    ) -> Binding<Data?> {
        Binding(
            get: {
                draft?[keyPath: keyPath]
            },
            set: {
                draft?[keyPath: keyPath] =
                    $0
            }
        )
    }
}

private struct ProfileTextField: View {
    let label: String

    @Binding
    var text: String

    init(
        _ label: String,
        text: Binding<String>
    ) {
        self.label = label
        self._text = text
    }

    var body: some View {
        LabeledContent(label) {
            TextField(
                "",
                text: $text
            )
            .textFieldStyle(
                .roundedBorder
            )
            .frame(
                minWidth: 280
            )
        }
    }
}
