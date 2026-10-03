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
    private var store:
        DReportStore

    @Environment(
        \.dismiss
    )
    private var dismiss


    @State
    private var name =
        ""

    @State
    private var username =
        ""

    @State
    private var password =
        ""

    @State
    private var passwordConfirmation =
        ""

    @State
    private var errorMessage:
        String?


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                20
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {

                Text(
                    "Create Work Environment"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )


                Text(
                    "Create the Environment and its first Administrator account."
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


            Divider()


            Text(
                "Administrator Login"
            )
            .font(
                .headline
            )


            TextField(
                "Username",
                text:
                    $username
            )
            .textFieldStyle(
                .roundedBorder
            )


            SecureField(
                "Password",
                text:
                    $password
            )
            .textFieldStyle(
                .roundedBorder
            )


            SecureField(
                "Confirm password",
                text:
                    $passwordConfirmation
            )
            .textFieldStyle(
                .roundedBorder
            )


            Text(
                "This account belongs to the Work Environment. It is separate from your local Testudo profile."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                "The Environment will be saved as a portable .testudoenv package. You can choose a local, cloud-synced or external location."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            if
                let errorMessage
            {
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
        .padding(
            26
        )
        .frame(
            width:
                540
        )
    }


    private func create() {

        errorMessage =
            nil


        let cleanedName =
            name
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanedUsername =
            username
                .trimmingCharacters(
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


        guard
            !cleanedUsername.isEmpty
        else {
            errorMessage =
                "Administrator username is required."

            return
        }


        guard
            !password.isEmpty
        else {
            errorMessage =
                "Administrator password is required."

            return
        }


        guard
            password
                == passwordConfirmation
        else {
            errorMessage =
                "The passwords do not match."

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
                        packageURL,
                    adminUsername:
                        cleanedUsername,
                    adminPassword:
                        password
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
    private var store:
        DReportStore

    let environmentID:
        UUID

    let onEntered:
        () -> Void


    @State
    private var username =
        ""

    @State
    private var password =
        ""

    @State
    private var staySignedIn =
        false

    @State
    private var errorMessage:
        String?


    private var environment:
        WorkEnvironment?
    {
        store
            .workEnvironments
            .first {
                $0.id
                    == environmentID
            }
    }


    private var canEnter:
        Bool
    {
        !username
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        && !password.isEmpty
    }


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                20
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {

                Text(
                    environment?
                        .name
                    ?? "Work Environment"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )


                Text(
                    "Sign in to this Work Environment."
                )
                .foregroundStyle(
                    .secondary
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    12
            ) {

                TextField(
                    "Username",
                    text:
                        $username
                )
                .textFieldStyle(
                    .roundedBorder
                )


                SecureField(
                    "Password",
                    text:
                        $password
                )
                .textFieldStyle(
                    .roundedBorder
                )


                Toggle(
                    "Stay signed in",
                    isOn:
                        $staySignedIn
                )


                Text(
                    "If enabled, this installation can reopen the Environment without asking for your credentials again until you explicitly sign out."
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
            }


            if
                let errorMessage
            {
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
                    !canEnter
                )
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(
            26
        )
        .frame(
            width:
                500
        )
    }


    private func enter() {

        errorMessage =
            store
                .enterActiveEnvironment(
                    username:
                        username,
                    password:
                        password,
                    staySignedIn:
                        staySignedIn
                )


        if errorMessage == nil {
            onEntered()
        }
    }
}
