import SwiftUI


struct AdminToolsView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var showingMembers =
        false


    var body: some View {
        if
            store
                .currentEnvironmentUserIsAdministrator,
            let environment =
                store.activeWorkEnvironment
        {
            ScrollView {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        24
                ) {
                    header(
                        environment
                    )

                    Divider()

                    environmentSection(
                        environment
                    )

                    storageSection(
                        environment
                    )

                    identitySection(
                        environment
                    )

                    membersSection
                }
                .padding(
                    24
                )
            }
            .frame(
                width:
                    620,
                height:
                    650
            )
            .sheet(
                isPresented:
                    $showingMembers
            ) {
                EnvironmentMembershipManagementView()
            }

        } else {
            ContentUnavailableView(
                "Environment Administrator Access Required",
                systemImage:
                    "lock",
                description:
                    Text(
                        "Admin Tools are available only to Administrators of the active Work Environment."
                    )
            )
            .frame(
                width:
                    520,
                height:
                    300
            )
        }
    }


    private func header(
        _ environment:
            WorkEnvironment
    ) -> some View {
        HStack {
            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {
                Text(
                    "Admin Tools"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )

                Text(
                    "Administration for \(environment.name)"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Button(
                "Done"
            ) {
                dismiss()
            }
        }
    }


    private func environmentSection(
        _ environment:
            WorkEnvironment
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            Text(
                "Work Environment"
            )
            .font(
                .headline
            )

            LabeledContent(
                "Name"
            ) {
                Text(
                    environment.name
                )
            }

            LabeledContent(
                "Your role"
            ) {
                Text(
                    store
                        .currentEnvironmentRole?
                        .displayName
                    ?? "Unknown"
                )
            }

            LabeledContent(
                "Environment ID"
            ) {
                Text(
                    environment
                        .id
                        .uuidString
                )
                .font(
                    .caption
                )
                .textSelection(
                    .enabled
                )
            }
        }
    }


    private func storageSection(
        _ environment:
            WorkEnvironment
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            Text(
                "Environment Storage"
            )
            .font(
                .headline
            )

            if
                let storage =
                    environment.storage
            {
                LabeledContent(
                    "Type"
                ) {
                    Text(
                        storage
                            .kind
                            .displayName
                    )
                }

                if
                    let path =
                        storage.path
                {
                    LabeledContent(
                        "Location"
                    ) {
                        Text(
                            path
                        )
                        .font(
                            .caption
                        )
                        .textSelection(
                            .enabled
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                    }
                }

                Text(
                    "Storage describes where this installation reads and writes the Environment database. It is separate from user identity and authentication."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            } else {
                Text(
                    "No explicit storage location is registered for this Environment."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    private func identitySection(
        _ environment:
            WorkEnvironment
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            Text(
                "Identity & Authentication"
            )
            .font(
                .headline
            )

            LabeledContent(
                "Provider"
            ) {
                Text(
                    environment
                        .identityProvider
                        .displayName
                )
            }

            switch
                environment
                    .identityProvider
                    .kind
            {
            case .localAccounts:
                LabeledContent(
                    "Authentication"
                ) {
                    Text(
                        "Environment-scoped passwords"
                    )
                }

                Text(
                    "Members and credentials are managed by this Work Environment. No external identity directory is connected."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            case .externalDirectory:
                LabeledContent(
                    "Authentication"
                ) {
                    Text(
                        "External directory"
                    )
                }

                Text(
                    "Identity and authentication are supplied by the Environment's configured external directory."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    private var membersSection:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            HStack {
                Text(
                    "Active Members"
                )
                .font(
                    .headline
                )

                Spacer()

                Text(
                    "\(store.activeEnvironmentMemberships.count)"
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                "Manage the identities, roles and authentication access for this Work Environment."
            )
            .font(
                .callout
            )
            .foregroundStyle(
                .secondary
            )

            Button(
                "Manage Environment Members…"
            ) {
                showingMembers =
                    true
            }
        }
    }
}
