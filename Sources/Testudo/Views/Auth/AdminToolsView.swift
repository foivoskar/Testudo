import SwiftUI
import UniformTypeIdentifiers


struct AdminToolsView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var showingMembers =
        false

    @State
    private var environmentAppearanceError:
        String?

    @State
    private var calendarPendingRemoval:
        TestudoCalendar?

    @State
    private var calendarActionError:
        String?

    @State
    private var syncingCalendarIDs:
        Set<UUID> = []


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

                    appearanceSection(
                        environment
                    )

                    storageSection(
                        environment
                    )

                    identitySection(
                        environment
                    )

                    connectedCalendarsSection

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
                    760
            )
            .sheet(
                isPresented:
                    $showingMembers
            ) {
                EnvironmentMembershipManagementView()
            }
            .alert(
                item:
                    $calendarPendingRemoval
            ) {
                calendar in

                Alert(
                    title:
                        Text(
                            "Remove External Calendar?"
                        ),
                    message:
                        Text(
                            "“\(calendar.name)” will be disconnected from this Work Environment. All events imported from this calendar and their Testudo relationships will be removed. The original external calendar itself will not be modified."
                        ),
                    primaryButton:
                        .destructive(
                            Text(
                                "Remove Calendar"
                            )
                        ) {
                            removeExternalCalendar(
                                calendar
                            )
                        },
                    secondaryButton:
                        .cancel()
                )
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


    private func appearanceSection(
        _ environment:
            WorkEnvironment
    ) -> some View {

        let customIconData =
            store
                .environmentIconData(
                    for:
                        environment.id
                )

        let hasCustomIcon =
            customIconData
                != nil


        return
            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                Text(
                    "Environment Appearance"
                )
                .font(
                    .headline
                )


                HStack(
                    alignment:
                        .center,
                    spacing:
                        18
                ) {

                    EnvironmentIconView(
                        customImageData:
                            customIconData,
                        size:
                            76,
                        showsBackground:
                            false
                    )


                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            4
                    ) {

                        Text(
                            hasCustomIcon
                            ? "Custom Environment icon"
                            : "Default Testudo icon"
                        )
                        .fontWeight(
                            .medium
                        )


                        Text(
                            hasCustomIcon
                            ? "Stored inside this .testudoenv package."
                            : "This Environment currently uses Testudo's default blue icon."
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }


                    Spacer()
                }


                HStack(
                    spacing:
                        10
                ) {

                    Button {

                        chooseEnvironmentIcon()

                    } label: {

                        Label(
                            hasCustomIcon
                            ? "Change Icon…"
                            : "Choose Custom Icon…",
                            systemImage:
                                "photo"
                        )
                    }
                    .buttonStyle(
                        .bordered
                    )


                    if hasCustomIcon {

                        Button(
                            "Restore Default"
                        ) {

                            environmentAppearanceError =
                                store
                                    .restoreActiveEnvironmentDefaultIcon()
                        }
                        .buttonStyle(
                            .bordered
                        )
                    }
                }


                Text(
                    "A custom icon is saved as EnvironmentIcon.png inside the portable .testudoenv package, so it travels with the Environment to other Testudo installations."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )


                if
                    let environmentAppearanceError
                {
                    Text(
                        environmentAppearanceError
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .red
                    )
                }
            }
    }


    private func chooseEnvironmentIcon() {

        environmentAppearanceError =
            nil


        let panel =
            NSOpenPanel()

        panel.title =
            "Choose Work Environment Icon"

        panel.prompt =
            "Use Icon"

        panel.canChooseFiles =
            true

        panel.canChooseDirectories =
            false

        panel.allowsMultipleSelection =
            false

        panel.allowedContentTypes =
            [
                .image
            ]


        guard
            panel.runModal()
                == .OK,
            let sourceURL =
                panel.url
        else {
            return
        }


        environmentAppearanceError =
            store
                .setActiveEnvironmentIcon(
                    from:
                        sourceURL
                )
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
                    "Storage points this installation to the portable Work Environment package. A .testudoenv package can live locally, in iCloud Drive, Dropbox, OneDrive, another synced folder, external storage, or any other user-selected filesystem location."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

                Button {
                    saveEnvironmentAsPackage(
                        environment
                    )
                } label: {
                    Label(
                        storage.kind
                            == .localFolder
                            ? "Move to Testudo Package…"
                            : "Save Environment As…",
                        systemImage:
                            "shippingbox.and.arrow.backward"
                    )
                }
                .buttonStyle(
                    .bordered
                )


                if
                    storage.kind
                        == .localFolder
                {
                    Text(
                        "This Environment still uses the legacy app-local folder layout. Save it as a .testudoenv package to make its storage portable. The previous folder is retained as a safety copy but is no longer used by this installation."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


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


    private var connectedCalendarsSection:
        some View
    {
        let calendars =
            store.data.calendars
                .filter {
                    $0.sourceKind
                        == .iCalSubscription
                    || $0.sourceKind
                        == .appleEventKit
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }


        return VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            HStack {
                Text(
                    "Connected Calendars"
                )
                .font(
                    .headline
                )

                Spacer()

                Text(
                    "\(calendars.count)"
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Text(
                "External calendars connected to this Work Environment. Event source data is read-only; Testudo relationships remain editable."
            )
            .font(
                .callout
            )
            .foregroundStyle(
                .secondary
            )


            if calendars.isEmpty {
                Text(
                    "No external calendars are connected."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )

            } else {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        12
                ) {
                    ForEach(
                        calendars
                    ) {
                        calendar in

                        HStack(
                            alignment:
                                .top,
                            spacing:
                                12
                        ) {
                            Image(
                                systemName:
                                    calendar
                                        .sourceKind?
                                        .systemImage
                                    ?? "calendar"
                            )
                            .frame(
                                width:
                                    22
                            )

                            VStack(
                                alignment:
                                    .leading,
                                spacing:
                                    3
                            ) {
                                Text(
                                    calendar.name
                                )
                                .fontWeight(
                                    .medium
                                )

                                Text(
                                    calendar
                                        .sourceKind?
                                        .displayName
                                    ?? "External Calendar"
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )

                                Text(
                                    calendar.lastSyncAt
                                        .map {
                                            "Last sync: \(TestudoTime.dateTime($0))"
                                        }
                                    ?? "Last sync: Never"
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )

                                if
                                    let error =
                                        calendar
                                            .lastSyncError,
                                    !error.isEmpty
                                {
                                    Text(
                                        error
                                    )
                                    .font(
                                        .caption
                                    )
                                    .foregroundStyle(
                                        .red
                                    )
                                }
                            }

                            Spacer()

                            VStack(
                                alignment:
                                    .trailing,
                                spacing:
                                    8
                            ) {
                                if calendar.isReadOnly {
                                    Label(
                                        "Read-only",
                                        systemImage:
                                            "lock"
                                    )
                                    .font(
                                        .caption
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }


                                if
                                    syncingCalendarIDs
                                        .contains(
                                            calendar.id
                                        )
                                {
                                    ProgressView()
                                        .controlSize(
                                            .small
                                        )

                                } else {
                                    Menu {
                                        Button {
                                            syncExternalCalendar(
                                                calendar
                                            )
                                        } label: {
                                            Label(
                                                "Sync Now",
                                                systemImage:
                                                    "arrow.triangle.2.circlepath"
                                            )
                                        }


                                        Divider()


                                        Button(
                                            role:
                                                .destructive
                                        ) {
                                            calendarActionError =
                                                nil

                                            calendarPendingRemoval =
                                                calendar

                                        } label: {
                                            Label(
                                                "Remove Calendar…",
                                                systemImage:
                                                    "trash"
                                            )
                                        }

                                    } label: {
                                        Image(
                                            systemName:
                                                "ellipsis.circle"
                                        )
                                    }
                                    .menuStyle(
                                        .borderlessButton
                                    )
                                    .fixedSize()
                                }
                            }
                        }
                    }
                }
                .padding(
                    .vertical,
                    4
                )
            }


            if
                let calendarActionError,
                !calendarActionError.isEmpty
            {
                Label(
                    calendarActionError,
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


            Text(
                "Secret iCal addresses are stored in Keychain and are never displayed here. Apple Calendar access is supplied by macOS EventKit; Testudo stores only the calendar connection metadata in the Work Environment."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    private func syncExternalCalendar(
        _ calendar:
            TestudoCalendar
    ) {
        guard
            !syncingCalendarIDs
                .contains(
                    calendar.id
                )
        else {
            return
        }

        calendarActionError =
            nil

        syncingCalendarIDs
            .insert(
                calendar.id
            )

        Task {
            let error =
                await store
                    .syncExternalCalendar(
                        id:
                            calendar.id
                    )

            syncingCalendarIDs
                .remove(
                    calendar.id
                )

            calendarActionError =
                error
        }
    }


    private func removeExternalCalendar(
        _ calendar:
            TestudoCalendar
    ) {
        calendarActionError =
            store
                .disconnectExternalCalendar(
                    id:
                        calendar.id
                )

        calendarPendingRemoval =
            nil
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



// ============================================================
// MARK: - Portable Environment storage actions
// ============================================================

extension AdminToolsView {

    private func saveEnvironmentAsPackage(
        _ environment:
            WorkEnvironment
    ) {

        let panel =
            NSSavePanel()

        panel.title =
            "Save Testudo Work Environment"

        panel.prompt =
            "Save Environment"

        panel.canCreateDirectories =
            true

        panel.isExtensionHidden =
            false

        panel.allowedContentTypes =
            [
                TestudoEnvironmentPackage
                    .contentType
            ]

        panel.nameFieldStringValue =
            TestudoEnvironmentPackage
                .suggestedFileName(
                    for:
                        environment.name
                )


        guard
            panel.runModal()
                == .OK,
            let selectedURL =
                panel.url
        else {
            return
        }


        let destination =
            TestudoEnvironmentPackage
                .normalizedURL(
                    selectedURL
                )


        if
            let error =
                store
                    .saveWorkEnvironmentAsPackage(
                        id:
                            environment.id,
                        destinationURL:
                            destination
                    )
        {
            let alert =
                NSAlert()

            alert.alertStyle =
                .warning

            alert.messageText =
                "The Work Environment could not be saved."

            alert.informativeText =
                error

            alert.addButton(
                withTitle:
                    "OK"
            )

            alert.runModal()
        }
    }
}
