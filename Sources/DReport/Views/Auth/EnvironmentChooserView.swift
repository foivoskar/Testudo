import SwiftUI
import AppKit
import UniformTypeIdentifiers


struct EnvironmentChooserView: View {
    @EnvironmentObject
    private var store: DReportStore

    @State
    private var showingCreateEnvironment =
        false

    @State
    private var showingEnvironmentEntry =
        false

    @State
    private var entryEnvironmentID:
        UUID?

    @State
    private var errorMessage:
        String?

    @State
    private var environmentPendingRemoval:
        WorkEnvironment?


    var body: some View {
        ZStack {
            Color(
                nsColor:
                    .windowBackgroundColor
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 26
            ) {
                header

                environmentList

                Divider()

                actions

                if let errorMessage {
                    Label(
                        errorMessage,
                        systemImage:
                            "exclamationmark.circle"
                    )
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .red
                    )
                }
            }
            .frame(
                width: 650
            )
            .padding(36)
            .background(
                .regularMaterial,
                in:
                    RoundedRectangle(
                        cornerRadius: 18,
                        style:
                            .continuous
                    )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18,
                    style:
                        .continuous
                )
                .stroke(
                    Color.primary
                        .opacity(0.07)
                )
            }
            .padding(48)
        }
        .sheet(
            isPresented:
                $showingCreateEnvironment
        ) {
            CreateWorkEnvironmentView()
        }
        .sheet(
            isPresented:
                $showingEnvironmentEntry
        ) {
            if
                let environmentID =
                    entryEnvironmentID
            {
                EnvironmentEntryView(
                    environmentID:
                        environmentID
                ) {
                    showingEnvironmentEntry =
                        false
                }
            }
        }
        .alert(
            item:
                $environmentPendingRemoval
        ) {
            environment in

            Alert(
                title:
                    Text(
                        "Remove Work Environment?"
                    ),
                message:
                    Text(
                        "“\(environment.name)” will be removed only from this installation of Testudo. Its .testudoenv package and all Environment data will remain untouched at the current storage location, and you can open it again later."
                    ),
                primaryButton:
                    .destructive(
                        Text(
                            "Remove"
                        )
                    ) {
                        remove(
                            environment
                        )
                    },
                secondaryButton:
                    .cancel()
            )
        }
    }


    private var header:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            if
                let profile =
                    store.localUserProfile
            {
                Text(
                    profile.displayName.isEmpty
                    ? "Work Environments"
                    : "Welcome, \(profile.displayName)"
                )
                .font(.largeTitle)
                .fontWeight(
                    .semibold
                )
            } else {
                Text(
                    "Work Environments"
                )
                .font(.largeTitle)
                .fontWeight(
                    .semibold
                )
            }

            Text(
                "Choose a registered Work Environment, create a new one, or open an existing .testudoenv package."
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    @ViewBuilder
    private var environmentList:
        some View
    {
        if store.workEnvironments.isEmpty {
            ContentUnavailableView(
                "No Work Environments",
                systemImage:
                    "square.stack.3d.up",
                description:
                    Text(
                        "Create a new Environment or open an existing .testudoenv package."
                    )
            )
            .frame(
                minHeight: 180
            )
        } else {
            ScrollView {
                LazyVStack(
                    spacing: 10
                ) {
                    ForEach(
                        store.workEnvironments
                    ) {
                        environment in

                        environmentRow(
                            environment
                        )
                    }
                }
            }
            .frame(
                maxHeight: 330
            )
        }
    }


    private func environmentRow(
        _ environment:
            WorkEnvironment
    ) -> some View {
        HStack(
            spacing: 14
        ) {
            Image(
                systemName:
                    "square.stack.3d.up.fill"
            )
            .font(
                .system(
                    size: 22
                )
            )
            .foregroundStyle(
                Color.accentColor
            )
            .frame(
                width: 36
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    environment.name
                )
                .fontWeight(
                    .medium
                )

                if
                    let path =
                        environment
                            .storage?
                            .path
                {
                    Text(path)
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                        .truncationMode(
                            .middle
                        )
                }
            }

            Spacer()

            Button(
                role:
                    .destructive
            ) {
                environmentPendingRemoval =
                    environment
            } label: {
                Label(
                    "Remove",
                    systemImage:
                        "minus.circle"
                )
            }
            .buttonStyle(
                .bordered
            )
            .help(
                "Remove this Environment from Testudo without deleting its package"
            )

            Button(
                "Open"
            ) {
                open(
                    environment.id
                )
            }
            .buttonStyle(
                .borderedProminent
            )
        }
        .padding(14)
        .background(
            Color.primary
                .opacity(0.035),
            in:
                RoundedRectangle(
                    cornerRadius: 10,
                    style:
                        .continuous
                )
        )
    }


    private var actions:
        some View
    {
        HStack(
            spacing: 12
        ) {
            Button {
                showingCreateEnvironment =
                    true
            } label: {
                Label(
                    "Create New Environment",
                    systemImage:
                        "plus"
                )
            }
            .buttonStyle(
                .bordered
            )

            Button {
                loadEnvironment()
            } label: {
                Label(
                    "Open Existing Environment…",
                    systemImage:
                        "folder"
                )
            }
            .buttonStyle(
                .bordered
            )

            Spacer()
        }
    }


    private func remove(
        _ environment:
            WorkEnvironment
    ) {

        errorMessage =
            store
                .unregisterWorkEnvironment(
                    id:
                        environment.id
                )


        if
            entryEnvironmentID
                == environment.id
        {
            entryEnvironmentID =
                nil

            showingEnvironmentEntry =
                false
        }


        environmentPendingRemoval =
            nil
    }


    private func open(
        _ environmentID:
            UUID
    ) {
        errorMessage =
            nil

        switch
            store.openWorkEnvironment(
                id:
                    environmentID
            )
        {
        case .opened:
            break

        case .identityRequired:
            entryEnvironmentID =
                environmentID

            showingEnvironmentEntry =
                true

        case .failed(
            let message
        ):
            errorMessage =
                message
        }
    }


    private func loadEnvironment() {

        let panel =
            NSOpenPanel()

        panel.title =
            "Open Testudo Work Environment"

        panel.prompt =
            "Open Environment"

        panel.canChooseFiles =
            true

        panel.canChooseDirectories =
            false

        panel.treatsFilePackagesAsDirectories =
            false

        panel.allowsMultipleSelection =
            false

        panel.canCreateDirectories =
            false

        panel.allowedContentTypes =
            [
                TestudoEnvironmentPackage
                    .contentType
            ]


        guard
            panel.runModal()
                == .OK,
            let packageURL =
                panel.url
        else {
            return
        }


        let result =
            store.registerWorkEnvironment(
                from:
                    packageURL
            )


        if
            let error =
                result.error
        {
            errorMessage =
                error

            return
        }


        guard
            let environmentID =
                result.environmentID
        else {
            errorMessage =
                "The Work Environment could not be opened."

            return
        }


        open(
            environmentID
        )
    }


}


// ============================================================
// MARK: - Create Work Environment
// ============================================================

private struct CreateWorkEnvironmentView:
    View
{
    @EnvironmentObject
    private var store: DReportStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var name =
        ""

    @State
    private var errorMessage:
        String?


    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    "Create Work Environment"
                )
                .font(.title2)
                .fontWeight(
                    .semibold
                )

                Text(
                    "You will become the Administrator of this Environment."
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                "The Environment will be saved as a portable .testudoenv package. Choose any local, cloud-synced or external location in the Save dialog."
            )
            .font(
                .callout
            )
            .foregroundStyle(
                .secondary
            )


            TextField(
                "Environment name",
                text:
                    $name
            )
            .textFieldStyle(
                .roundedBorder
            )


            if let errorMessage {
                Text(
                    errorMessage
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
                    "Create Environment"
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
        .padding(26)
        .frame(
            width: 460
        )
    }


    private func create() {

        errorMessage =
            nil


        let cleanedName =
            name.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )


        guard
            !cleanedName.isEmpty
        else {
            errorMessage =
                "Environment name is required."

            return
        }


        let panel =
            NSSavePanel()

        panel.title =
            "Create Testudo Work Environment"

        panel.prompt =
            "Create Environment"

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
                        cleanedName
                )


        guard
            panel.runModal()
                == .OK,
            let selectedURL =
                panel.url
        else {
            return
        }


        let packageURL =
            TestudoEnvironmentPackage
                .normalizedURL(
                    selectedURL
                )


        errorMessage =
            store
                .createWorkEnvironment(
                    name:
                        cleanedName,
                    packageURL:
                        packageURL
                )


        if errorMessage == nil {
            dismiss()
        }
    }


}


// ============================================================
// MARK: - Environment Identity / Entry
// ============================================================

private struct EnvironmentEntryView:
    View
{
    @EnvironmentObject
    private var store: DReportStore

    let environmentID:
        UUID

    let onEntered:
        () -> Void

    @State
    private var selectedMembershipID:
        UUID?

    @State
    private var password =
        ""

    @State
    private var errorMessage:
        String?


    private var environment:
        WorkEnvironment?
    {
        store.workEnvironments
            .first {
                $0.id
                    == environmentID
            }
    }


    private var needsPassword:
        Bool
    {
        guard
            let selectedMembershipID
        else {
            return false
        }

        return
            store
                .environmentMembershipNeedsPassword(
                    id:
                        selectedMembershipID
                )
    }


    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    environment?
                        .name
                    ?? "Work Environment"
                )
                .font(.title2)
                .fontWeight(
                    .semibold
                )

                Text(
                    "Choose your identity for this Work Environment."
                )
                .foregroundStyle(
                    .secondary
                )
            }


            ScrollView {
                LazyVStack(
                    spacing: 8
                ) {
                    ForEach(
                        store
                            .activeEnvironmentMemberships
                    ) {
                        membership in

                        membershipRow(
                            membership
                        )
                    }
                }
            }
            .frame(
                minHeight: 120,
                maxHeight: 260
            )


            if needsPassword {
                SecureField(
                    "Environment password",
                    text:
                        $password
                )
                .textFieldStyle(
                    .roundedBorder
                )
            }


            if let errorMessage {
                Text(
                    errorMessage
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
                    "Enter Environment"
                ) {
                    enter()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    selectedMembershipID
                        == nil
                )
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(26)
        .frame(
            width: 500
        )
        .onAppear {
            if
                selectedMembershipID
                    == nil
            {
                selectedMembershipID =
                    store
                        .activeEnvironmentMemberships
                        .first?
                        .id
            }
        }
    }


    private func membershipRow(
        _ membership:
            EnvironmentMembership
    ) -> some View {
        Button {
            selectedMembershipID =
                membership.id

            password =
                ""

            errorMessage =
                nil
        } label: {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(
                        membership
                            .displayName
                    )
                    .foregroundStyle(
                        .primary
                    )

                    Text(
                        membership
                            .role
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

                if
                    selectedMembershipID
                        == membership.id
                {
                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
                }
            }
            .padding(11)
            .background(
                Color.primary
                    .opacity(
                        selectedMembershipID
                            == membership.id
                        ? 0.07
                        : 0.025
                    ),
                in:
                    RoundedRectangle(
                        cornerRadius: 8,
                        style:
                            .continuous
                    )
            )
        }
        .buttonStyle(
            .plain
        )
    }


    private func enter() {
        guard
            let selectedMembershipID
        else {
            return
        }


        errorMessage =
            store
                .enterActiveEnvironment(
                    membershipID:
                        selectedMembershipID,
                    password:
                        password
                )


        if errorMessage == nil {
            onEntered()
        }
    }
}
