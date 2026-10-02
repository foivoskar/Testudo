import SwiftUI


struct AdminToolsView: View {
    @EnvironmentObject
    private var store: DReportStore

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
            VStack(
                alignment: .leading,
                spacing: 24
            ) {
                header(
                    environment
                )

                Divider()

                environmentSection(
                    environment
                )

                directorySection(
                    environment
                )

                membersSection

                Spacer()
            }
            .padding(24)
            .frame(
                width: 560,
                height: 520
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
                width: 520,
                height: 300
            )
        }
    }


    private func header(
        _ environment:
            WorkEnvironment
    ) -> some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    "Admin Tools"
                )
                .font(.title2)
                .fontWeight(
                    .semibold
                )

                Text(
                    "Administration for \(environment.name)"
                )
                .font(.callout)
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
            alignment: .leading,
            spacing: 10
        ) {
            Text(
                "Work Environment"
            )
            .font(.headline)

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
                .font(.caption)
                .textSelection(
                    .enabled
                )
            }
        }
    }


    private func directorySection(
        _ environment:
            WorkEnvironment
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(
                "Directory"
            )
            .font(.headline)

            if
                let directory =
                    environment.directory
            {
                LabeledContent(
                    "Type"
                ) {
                    Text(
                        directory
                            .kind
                            .displayName
                    )
                }

                if
                    let path =
                        directory.path
                {
                    LabeledContent(
                        "Location"
                    ) {
                        Text(path)
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

            } else {
                Text(
                    "No directory is currently configured for this Environment."
                )
                .font(.callout)
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
            alignment: .leading,
            spacing: 10
        ) {
            HStack {
                Text(
                    "Active Members"
                )
                .font(.headline)

                Spacer()

                Text(
                    "\(store.activeEnvironmentMemberships.count)"
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                "Manage the users and identities that can enter this Work Environment."
            )
            .font(.callout)
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
