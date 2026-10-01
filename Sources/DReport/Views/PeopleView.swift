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
                    systemImage:
                        "person.2"
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
            avatar

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

    @ViewBuilder
    private var avatar:
        some View
    {
        let profile =
            store.personProfile(
                for: person.id
            )

        if
            let data =
                profile?.avatarData,
            let image =
                NSImage(
                    data: data
                )
        {
            Image(
                nsImage: image
            )
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

                Text(
                    String(
                        person.name
                            .first
                        ?? "?"
                    )
                    .uppercased()
                )
                .font(
                    .system(
                        size: 12,
                        weight:
                            .semibold
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

struct PersonDetailView: View {
    @EnvironmentObject
    private var store: DReportStore

    let personID: UUID

    @State
    private var draft:
        PersonProfile?

    @State
    private var savedIndicator =
        false

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
                    spacing: 24
                ) {
                    profileHeader(
                        person: person
                    )

                    Divider()

                    if draft != nil {
                        identitySection
                        contactSection
                        workplaceSection
                        onlineSection
                        researchSection
                        preferencesSection
                        affiliationsSection
                        accountSection
                        notesSection
                    }
                }
                .padding(24)
                .frame(
                    maxWidth: 760,
                    alignment: .leading
                )
            }
            .background(
                DReportStyle.contentBackground
            )
            .onAppear {
                loadProfile()
            }
            .onChange(
                of: personID
            ) {
                loadProfile()
            }
        } else {
            ContentUnavailableView(
                "Person Not Found",
                systemImage:
                    "person.crop.circle.badge.questionmark"
            )
        }
    }

    private func profileHeader(
        person: Entity
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: 16
        ) {
            editableAvatar

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    draft?.displayName
                        .isEmpty == false
                    ? draft!.displayName
                    : person.name
                )
                .font(.title2)
                .fontWeight(.semibold)

                if
                    let job =
                        draft?.jobTitle,
                    !job.isEmpty
                {
                    Text(job)
                        .foregroundStyle(
                            .secondary
                        )
                }

                if
                    let user =
                        store.user(
                            linkedToPerson:
                                personID
                        )
                {
                    Text(
                        "@\(user.username) · \(user.role.displayName)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            if savedIndicator {
                Label(
                    "Saved",
                    systemImage:
                        "checkmark"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Button("Save") {
                saveProfile()
            }
            .keyboardShortcut(
                "s",
                modifiers: [.command]
            )
        }
    }

    @ViewBuilder
    private var editableAvatar:
        some View
    {
        if draft != nil {
            AvatarPicker(
                avatarData:
                    binding(
                        \.avatarData
                    )
            )
        }
    }

    private var identitySection:
        some View
    {
        profileSection(
            title: "Identity"
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
    }

    private var contactSection:
        some View
    {
        profileSection(
            title: "Professional Contact"
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
    }

    private var workplaceSection:
        some View
    {
        profileSection(
            title: "Workplace"
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
    }

    private var onlineSection:
        some View
    {
        profileSection(
            title: "Online"
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
    }

    private var researchSection:
        some View
    {
        profileSection(
            title: "Research & Professional IDs"
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
    }

    private var preferencesSection:
        some View
    {
        profileSection(
            title: "Professional Preferences"
        ) {
            ProfileTextField(
                "Preferred language",
                text:
                    optionalBinding(
                        \.preferredLanguage
                    )
            )

            ProfileTextField(
                "Time zone",
                text:
                    optionalBinding(
                        \.timeZone
                    )
            )
        }
    }

    private var affiliationsSection:
        some View
    {
        profileSection(
            title: "Affiliations"
        ) {
            let affiliations =
                store.containers(
                    for: personID
                )

            if affiliations.isEmpty {
                Text(
                    "No organization or group affiliations."
                )
                .font(.callout)
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
                        .foregroundStyle(
                            .secondary
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
                    Button(
                        entity.name
                    ) {
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

    private var accountSection:
        some View
    {
        profileSection(
            title: "DReport Account"
        ) {
            if
                let user =
                    store.user(
                        linkedToPerson:
                            personID
                    )
            {
                LabeledContent(
                    "Username",
                    value:
                        "@\(user.username)"
                )

                LabeledContent(
                    "Role",
                    value:
                        user.role
                            .displayName
                )

                LabeledContent(
                    "Status",
                    value:
                        user.isActive
                        ? "Active"
                        : "Disabled"
                )
            } else {
                Text(
                    "This person does not have a DReport user account."
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }

    private var notesSection:
        some View
    {
        profileSection(
            title: "Notes"
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

    private var availableAffiliations:
        [Entity]
    {
        let currentIDs =
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
                && !currentIDs.contains(
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

    private func profileSection<Content: View>(
        title: String,
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

    private func loadProfile() {
        if
            let existing =
                store.personProfile(
                    for: personID
                )
        {
            draft = existing
        } else {
            draft =
                PersonProfile(
                    entityID:
                        personID
                )
        }

        savedIndicator = false
    }

    private func saveProfile() {
        guard
            let draft
        else {
            return
        }

        store.savePersonProfile(
            draft
        )

        self.draft =
            store.personProfile(
                for: personID
            )

        savedIndicator = true

        DispatchQueue.main
            .asyncAfter(
                deadline:
                    .now() + 1.5
            ) {
                savedIndicator = false
            }
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
            set: { newValue in
                draft?[keyPath: keyPath] =
                    newValue
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
            set: { newValue in
                draft?[keyPath: keyPath] =
                    newValue.isEmpty
                    ? nil
                    : newValue
            }
        )
    }

    private func binding(
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
            set: { newValue in
                draft?[keyPath: keyPath] =
                    newValue
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
                minWidth: 260
            )
        }
    }
}
