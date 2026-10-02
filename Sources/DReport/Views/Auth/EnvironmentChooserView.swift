import SwiftUI
import AppKit


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
                "Choose an existing Work Environment, create a new one, or load one from a directory."
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
                        "Create a new Environment or load an existing one from a directory."
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
                            .directory?
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
                    "Load Environment from Directory",
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
            "Load Work Environment"

        panel.prompt =
            "Load Environment"

        panel.canChooseFiles =
            false

        panel.canChooseDirectories =
            true

        panel.allowsMultipleSelection =
            false

        panel.canCreateDirectories =
            false


        guard
            panel.runModal()
                == .OK,
            let directoryURL =
                panel.url
        else {
            return
        }


        let result =
            store.registerWorkEnvironment(
                from:
                    directoryURL
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
                "The Work Environment could not be loaded."

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
            store
                .createWorkEnvironment(
                    name:
                        name
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
