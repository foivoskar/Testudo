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
        .toolbar {
            ToolbarItem {
                Button(
                    "Done"
                ) {
                    dismiss()
                }
            }
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

            infoRow(
                "Name",
                membership
                    .displayName
            )

            infoRow(
                "Directory identifier",
                membership
                    .directoryUserIdentifier
                ?? "None"
            )

            infoRow(
                "Linked Person",
                linkedPersonName(
                    membership
                )
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


    private func linkedPersonName(
        _ membership:
            EnvironmentMembership
    ) -> String {
        guard
            let personID =
                membership
                    .personEntityID,
            let person =
                store.entity(
                    id:
                        personID
                )
        else {
            return "None"
        }

        return
            person.name
    }


    private func load(
        _ membership:
            EnvironmentMembership
    ) {
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
