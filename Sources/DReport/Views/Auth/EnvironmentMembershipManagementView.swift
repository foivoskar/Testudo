import SwiftUI


struct EnvironmentMembershipManagementView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var selectedMembershipID:
        UUID?

    @State
    private var showingAddMember =
        false


    var body: some View {
        NavigationSplitView {
            VStack(
                spacing:
                    0
            ) {
                HStack {
                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            2
                    ) {
                        Text(
                            "Environment Members"
                        )
                        .font(
                            .title2
                        )
                        .fontWeight(
                            .semibold
                        )

                        if
                            let environment =
                                store
                                    .activeWorkEnvironment
                        {
                            Text(
                                environment.name
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }

                    Spacer()

                    Button {
                        showingAddMember =
                            true
                    } label: {
                        Image(
                            systemName:
                                "plus"
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                    .help(
                        "Add Environment Member"
                    )
                }
                .padding(
                    .horizontal,
                    14
                )
                .padding(
                    .vertical,
                    12
                )


                List(
                    selection:
                        $selectedMembershipID
                ) {
                    ForEach(
                        store
                            .environmentMembershipsForActiveEnvironment
                    ) {
                        membership in

                        EnvironmentMembershipRow(
                            membership:
                                membership,
                            isCurrent:
                                membership.id
                                == store
                                    .currentEnvironmentMembership?
                                    .id
                        )
                        .tag(
                            membership.id
                        )
                    }
                }
            }
            .navigationSplitViewColumnWidth(
                min:
                    250,
                ideal:
                    290,
                max:
                    350
            )

        } detail: {
            if
                let selectedMembershipID
            {
                EnvironmentMembershipEditorView(
                    membershipID:
                        selectedMembershipID
                )

            } else {
                ContentUnavailableView {
                    Label(
                        "Select a Member",
                        systemImage:
                            "person.crop.circle"
                    )

                } description: {
                    Text(
                        "Choose an Environment membership to inspect or manage."
                    )
                }
            }
        }
        .frame(
            minWidth:
                820,
            idealWidth:
                900,
            minHeight:
                560,
            idealHeight:
                620
        )
        .onAppear {
            if selectedMembershipID == nil {
                selectedMembershipID =
                    store
                        .currentEnvironmentMembership?
                        .id
                    ?? store
                        .environmentMembershipsForActiveEnvironment
                        .first?
                        .id
            }
        }
        .toolbar {
            ToolbarItem {
                Button(
                    "Done"
                ) {
                    dismiss()
                }
            }
        }
        .sheet(
            isPresented:
                $showingAddMember
        ) {
            AddEnvironmentMembershipView {
                membershipID in

                selectedMembershipID =
                    membershipID

                showingAddMember =
                    false
            }
            .environmentObject(
                store
            )
        }
    }
}


private struct EnvironmentMembershipRow:
    View
{
    let membership:
        EnvironmentMembership

    let isCurrent:
        Bool


    var body: some View {
        HStack(
            spacing:
                10
        ) {
            ZStack {
                Circle()
                    .fill(
                        Color
                            .accentColor
                            .opacity(
                                0.12
                            )
                    )

                Text(
                    initials
                )
                .font(
                    .system(
                        size:
                            10,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    Color
                        .accentColor
                )
            }
            .frame(
                width:
                    30,
                height:
                    30
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {
                Text(
                    membership.displayName
                )
                .fontWeight(
                    .medium
                )
                .lineLimit(
                    1
                )

                Text(
                    membership.role
                        .displayName
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            if isCurrent {
                Image(
                    systemName:
                        "checkmark.circle.fill"
                )
                .foregroundStyle(
                    Color
                        .accentColor
                )
                .help(
                    "Current Environment membership"
                )
            }


            if !membership.isActive {
                Image(
                    systemName:
                        "pause.circle"
                )
                .foregroundStyle(
                    .secondary
                )
                .help(
                    "Inactive membership"
                )
            }
        }
        .padding(
            .vertical,
            2
        )
    }


    private var initials:
        String
    {
        let first =
            membership
                .firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .first

        let last =
            membership
                .lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .first

        let value =
            [
                first,
                last
            ]
            .compactMap {
                $0
            }

        if value.isEmpty {
            return "?"
        }

        return
            String(
                value
            )
            .uppercased()
    }
}


private struct EnvironmentMembershipEditorView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

    let membershipID:
        UUID

    @State
    private var selectedPersonID:
        UUID?

    @State
    private var firstName =
        ""

    @State
    private var lastName =
        ""

    @State
    private var directoryIdentifier =
        ""

    @State
    private var role:
        EnvironmentRole =
            .user

    @State
    private var isActive =
        true

    @State
    private var message:
        String?

    @State
    private var messageIsError =
        false


    var body: some View {
        Group {
            if
                let membership =
                    store.environmentMembership(
                        id:
                            membershipID
                    )
            {
                ScrollView {
                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            24
                    ) {
                        header(
                            membership
                        )

                        Divider()

                        identitySection(
                            membership
                        )

                        accessSection(
                            membership
                        )

                        if let message {
                            Label(
                                message,
                                systemImage:
                                    messageIsError
                                    ? "exclamationmark.triangle"
                                    : "checkmark.circle"
                            )
                            .font(
                                .callout
                            )
                            .foregroundStyle(
                                messageIsError
                                ? Color.red
                                : Color.secondary
                            )
                        }
                    }
                    .padding(
                        28
                    )
                    .frame(
                        maxWidth:
                            680,
                        alignment:
                            .leading
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .center
                    )
                }
                .onAppear {
                    load(
                        membership
                    )
                }
                .onChange(
                    of:
                        membershipID
                ) {
                    if
                        let updated =
                            store
                                .environmentMembership(
                                    id:
                                        membershipID
                                )
                    {
                        load(
                            updated
                        )
                    }
                }

            } else {
                ContentUnavailableView(
                    "Membership Not Found",
                    systemImage:
                        "person.crop.circle.badge.questionmark"
                )
            }
        }
    }


    private func header(
        _ membership:
            EnvironmentMembership
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                4
        ) {
            Text(
                membership
                    .displayName
            )
            .font(
                .title2
            )
            .fontWeight(
                .semibold
            )

            if
                membership.id
                    == store
                        .currentEnvironmentMembership?
                        .id
            {
                Text(
                    "Current Environment membership"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    Color
                        .accentColor
                )
            }
        }
    }


    private func identitySection(
        _ membership:
            EnvironmentMembership
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {
            Text(
                "Identity"
            )
            .font(
                .headline
            )


            EntitySelectionSummaryRow(
                label:
                    "Linked Person",
                selectedIDs:
                    selectedPersonID
                        .map {
                            [$0]
                        }
                    ?? [],
                tabs:
                    [.people],
                candidateIDs:
                    linkedPersonCandidateIDs,
                maximumSelectionCount:
                    1,
                selectorTitle:
                    "Link to Person",
                selectorMessage:
                    "Choose the Person represented by this Environment membership.",
                emptyText:
                    "None",
                buttonSystemImage:
                    "pencil"
            ) {
                selection in

                selectedPersonID =
                    selection.first

                return nil
            }


            if selectedPersonID == nil {
                editableTextRow(
                    label:
                        "First name",
                    prompt:
                        "First name",
                    text:
                        $firstName
                )

                editableTextRow(
                    label:
                        "Last name",
                    prompt:
                        "Last name",
                    text:
                        $lastName
                )

            } else {
                infoRow(
                    "Name",
                    selectedPersonDisplayName
                )

                Text(
                    "The membership name follows the linked Person."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            editableTextRow(
                label:
                    "Directory identifier",
                prompt:
                    "Optional",
                text:
                    $directoryIdentifier
            )


            infoRow(
                "Membership ID",
                membership
                    .id
                    .uuidString
            )
        }
    }


    private func accessSection(
        _ membership:
            EnvironmentMembership
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {
            Text(
                "Environment Access"
            )
            .font(
                .headline
            )

            Picker(
                "Role",
                selection:
                    $role
            ) {
                ForEach(
                    EnvironmentRole
                        .allCases
                ) {
                    role in

                    Text(
                        role.displayName
                    )
                    .tag(
                        role
                    )
                }
            }
            .frame(
                maxWidth:
                    360
            )


            Toggle(
                "Active membership",
                isOn:
                    $isActive
            )


            HStack {
                Spacer()

                Button(
                    "Save Changes"
                ) {
                    save()
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
            .padding(
                .top,
                4
            )
        }
    }


    private func editableTextRow(
        label:
            String,
        prompt:
            String,
        text:
            Binding<String>
    ) -> some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing:
                18
        ) {
            Text(
                label
            )
            .font(
                .callout
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width:
                    150,
                alignment:
                    .leading
            )

            TextField(
                prompt,
                text:
                    text
            )
            .textFieldStyle(
                .roundedBorder
            )
            .frame(
                maxWidth:
                    360
            )
        }
    }


    private func infoRow(
        _ label:
            String,
        _ value:
            String
    ) -> some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing:
                18
        ) {
            Text(
                label
            )
            .font(
                .callout
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width:
                    150,
                alignment:
                    .leading
            )

            Text(
                value
            )
            .font(
                .callout
            )
            .textSelection(
                .enabled
            )
        }
    }


    private var selectedPersonDisplayName:
        String
    {
        guard
            let selectedPersonID,
            let person =
                store.entity(
                    id:
                        selectedPersonID
                )
        else {
            return "None"
        }

        return
            person.name
    }


    private var linkedPersonCandidateIDs:
        Set<UUID>
    {
        var ids =
            Set(
                store
                    .peopleAvailableForEnvironmentMembershipLink
                    .map(
                        \.id
                    )
            )

        if let selectedPersonID {
            ids.insert(
                selectedPersonID
            )
        }

        return ids
    }


    private func load(
        _ membership:
            EnvironmentMembership
    ) {
        selectedPersonID =
            membership.personEntityID

        firstName =
            membership.firstName

        lastName =
            membership.lastName

        directoryIdentifier =
            membership
                .directoryUserIdentifier
            ?? ""

        role =
            membership.role

        isActive =
            membership.isActive

        message =
            nil

        messageIsError =
            false
    }


    private func save() {
        let error =
            store
                .updateEnvironmentMembership(
                    membershipID:
                        membershipID,
                    firstName:
                        firstName,
                    lastName:
                        lastName,
                    directoryUserIdentifier:
                        directoryIdentifier,
                    personEntityID:
                        selectedPersonID,
                    role:
                        role,
                    isActive:
                        isActive
                )

        if let error {
            message =
                error

            messageIsError =
                true

            if
                let membership =
                    store
                        .environmentMembership(
                            id:
                                membershipID
                        )
            {
                selectedPersonID =
                    membership.personEntityID

                firstName =
                    membership.firstName

                lastName =
                    membership.lastName

                directoryIdentifier =
                    membership
                        .directoryUserIdentifier
                    ?? ""

                role =
                    membership.role

                isActive =
                    membership.isActive
            }

        } else {
            message =
                "Membership updated."

            messageIsError =
                false
        }
    }
}


private struct AddEnvironmentMembershipView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

    @Environment(\.dismiss)
    private var dismiss

    let onCreated:
        (UUID) -> Void

    @State
    private var selectedPersonID:
        UUID?

    @State
    private var firstName =
        ""

    @State
    private var lastName =
        ""

    @State
    private var directoryIdentifier =
        ""

    @State
    private var role:
        EnvironmentRole =
            .user

    @State
    private var isActive =
        true

    @State
    private var errorMessage:
        String?


    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                22
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {
                Text(
                    "Add Environment Member"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )

                Text(
                    "Create a membership for this Work Environment."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Divider()


            VStack(
                alignment:
                    .leading,
                spacing:
                    12
            ) {
                Text(
                    "Identity"
                )
                .font(
                    .headline
                )


                EntitySelectionButton(
                    title:
                        "Link to Person",
                    selectedIDs:
                        selectedPersonID
                            .map {
                                [$0]
                            }
                        ?? [],
                    tabs:
                        [.people],
                    candidateIDs:
                        Set(
                            store
                                .peopleAvailableForEnvironmentMembershipLink
                                .map(
                                    \.id
                                )
                        ),
                    maximumSelectionCount:
                        1,
                    placeholder:
                        "No linked Person",
                    selectorMessage:
                        "Choose a Person to link to this Environment membership."
                ) {
                    selection in

                    selectedPersonID =
                        selection.first

                    return nil
                }


                if selectedPersonID == nil {
                    HStack(
                        spacing:
                            12
                    ) {
                        TextField(
                            "First name",
                            text:
                                $firstName
                        )

                        TextField(
                            "Last name",
                            text:
                                $lastName
                        )
                    }

                } else {
                    Text(
                        "The member name will be copied from the linked Person."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                TextField(
                    "Directory identifier (optional)",
                    text:
                        $directoryIdentifier
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    12
            ) {
                Text(
                    "Environment Access"
                )
                .font(
                    .headline
                )

                Picker(
                    "Role",
                    selection:
                        $role
                ) {
                    ForEach(
                        EnvironmentRole
                            .allCases
                    ) {
                        role in

                        Text(
                            role.displayName
                        )
                        .tag(
                            role
                        )
                    }
                }

                Toggle(
                    "Active membership",
                    isOn:
                        $isActive
                )
            }


            Text(
                "This creates an Environment membership only. It does not create a legacy DReport user account or password."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )


            if let errorMessage {
                Label(
                    errorMessage,
                    systemImage:
                        "exclamationmark.triangle"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .red
                )
            }


            HStack {
                Spacer()

                Button(
                    "Cancel"
                ) {
                    dismiss()
                }

                Button(
                    "Add Member"
                ) {
                    create()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(
            24
        )
        .frame(
            width:
                520
        )
    }


    private func create() {
        errorMessage =
            nil

        let result =
            store
                .addEnvironmentMembership(
                    firstName:
                        firstName,
                    lastName:
                        lastName,
                    directoryUserIdentifier:
                        directoryIdentifier,
                    personEntityID:
                        selectedPersonID,
                    role:
                        role,
                    isActive:
                        isActive
                )

        if let error = result.error {
            errorMessage =
                error

            return
        }

        guard
            let membershipID =
                result.membershipID
        else {
            errorMessage =
                "The Environment membership could not be created."

            return
        }

        onCreated(
            membershipID
        )

        dismiss()
    }
}
