import SwiftUI
import AppKit
import UniformTypeIdentifiers


struct EnvironmentChooserView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

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
    private var hoveredEnvironmentID:
        UUID?


    var body:
        some View
    {
        ZStack {

            Color(
                nsColor:
                    .windowBackgroundColor
            )
            .ignoresSafeArea()


            ScrollView {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        26
                ) {

                    header

                    environmentList

                    actions


                    if
                        let errorMessage
                    {
                        Label(
                            errorMessage,
                            systemImage:
                                "exclamationmark.circle.fill"
                        )
                        .font(
                            .callout
                        )
                        .foregroundStyle(
                            .red
                        )
                        .padding(
                            .horizontal,
                            4
                        )
                    }
                }
                .frame(
                    maxWidth:
                        780
                )
                .padding(
                    .horizontal,
                    44
                )
                .padding(
                    .vertical,
                    42
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
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
        HStack(
            alignment:
                .center,
            spacing:
                18
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {

                Text(
                    "Work Environments"
                )
                .font(
                    .system(
                        size:
                            30,
                        weight:
                            .semibold,
                        design:
                            .rounded
                    )
                )


                Text(
                    "Choose where you want to work."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            if
                let profile =
                    store
                        .localUserProfile
            {
                HStack(
                    spacing:
                        10
                ) {

                    VStack(
                        alignment:
                            .trailing,
                        spacing:
                            2
                    ) {

                        Text(
                            profile
                                .displayName
                        )
                        .font(
                            .callout
                        )
                        .fontWeight(
                            .medium
                        )


                        Text(
                            "Testudo user"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }


                    TestudoUserAvatarView(
                        profile:
                            profile,
                        size:
                            42
                    )
                }
            }
        }
        .padding(
            .bottom,
            4
        )
    }


    @ViewBuilder
    private var environmentList:
        some View
    {
        if
            store
                .workEnvironments
                .isEmpty
        {
            VStack(
                spacing:
                    16
            ) {

                TestudoBrandIcon(
                    size:
                        90,
                    showsBackground:
                        false
                )
                .opacity(
                    0.75
                )


                Text(
                    "No Work Environments yet"
                )
                .font(
                    .title3
                )
                .fontWeight(
                    .semibold
                )


                Text(
                    "Create a new Environment or open an existing .testudoenv package."
                )
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
            }
            .frame(
                maxWidth:
                    .infinity
            )
            .padding(
                .vertical,
                54
            )
            .background(
                .regularMaterial,
                in:
                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
            )

        } else {

            LazyVStack(
                spacing:
                    10
            ) {

                ForEach(
                    store
                        .workEnvironments
                ) {
                    environment in

                    environmentRow(
                        environment
                    )
                }
            }
        }
    }


    private func environmentRow(
        _ environment:
            WorkEnvironment
    ) -> some View
    {
        let isHovered =
            hoveredEnvironmentID
                == environment.id


        return
            Button {
                open(
                    environment.id
                )

            } label: {

                HStack(
                    spacing:
                        18
                ) {

                    TestudoBrandIcon(
                        size:
                            50,
                        showsBackground:
                            false
                    )


                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            5
                    ) {

                        Text(
                            environment
                                .name
                        )
                        .font(
                            .system(
                                size:
                                    16,
                                weight:
                                    .semibold
                            )
                        )
                        .foregroundStyle(
                            .primary
                        )


                        if
                            let path =
                                environment
                                    .storage?
                                    .path
                        {
                            Text(
                                path
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(
                                1
                            )
                            .truncationMode(
                                .middle
                            )
                        }


                        Text(
                            "Open Work Environment"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            Color
                                .accentColor
                        )
                    }


                    Spacer()


                    Image(
                        systemName:
                            "chevron.right"
                    )
                    .font(
                        .system(
                            size:
                                13,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        isHovered
                        ? Color
                            .accentColor
                        : Color
                            .secondary
                    )
                    .frame(
                        width:
                            30,
                        height:
                            30
                    )
                    .background {

                        Circle()
                            .fill(
                                Color
                                    .accentColor
                                    .opacity(
                                        isHovered
                                        ? 0.12
                                        : 0.05
                                    )
                            )
                    }
                }
                .padding(
                    16
                )
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .fill(
                    isHovered
                    ? Color
                        .accentColor
                        .opacity(
                            0.055
                        )
                    : Color
                        .primary
                        .opacity(
                            0.028
                        )
                )
            }
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .stroke(
                    isHovered
                    ? Color
                        .accentColor
                        .opacity(
                            0.25
                        )
                    : Color
                        .primary
                        .opacity(
                            0.07
                        ),
                    lineWidth:
                        1
                )
            }
            .onHover {
                hovering in

                withAnimation(
                    .easeOut(
                        duration:
                            0.12
                    )
                ) {
                    hoveredEnvironmentID =
                        hovering
                        ? environment.id
                        : nil
                }
            }
    }


    private var actions:
        some View
    {
        HStack(
            spacing:
                12
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
                .borderedProminent
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
        .padding(
            .top,
            2
        )
    }


    private func open(
        _ environmentID:
            UUID
    ) {

        errorMessage =
            nil


        switch
            store
                .openWorkEnvironment(
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
            store
                .registerWorkEnvironment(
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

    @FocusState
    private var usernameIsFocused:
        Bool


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
            spacing:
                22
        ) {

            TestudoBrandIcon(
                size:
                    72,
                showsBackground:
                    true
            )


            VStack(
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
                    "Sign in to this Work Environment"
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
                .focused(
                    $usernameIsFocused
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
                    "When enabled, this Mac can reopen the Environment without asking for these credentials again until you explicitly sign out of the Environment."
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
            .padding(
                18
            )
            .background(
                Color
                    .primary
                    .opacity(
                        0.025
                    ),
                in:
                    RoundedRectangle(
                        cornerRadius:
                            14,
                        style:
                            .continuous
                    )
            )


            if
                let errorMessage
            {
                Label(
                    errorMessage,
                    systemImage:
                        "exclamationmark.circle.fill"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .red
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )
            }


            Button(
                "Enter Environment"
            ) {
                enter()
            }
            .buttonStyle(
                .borderedProminent
            )
            .controlSize(
                .large
            )
            .frame(
                maxWidth:
                    .infinity
            )
            .disabled(
                !canEnter
            )
            .keyboardShortcut(
                .defaultAction
            )
        }
        .padding(
            28
        )
        .frame(
            width:
                480
        )
        .onAppear {

            DispatchQueue
                .main
                .asyncAfter(
                    deadline:
                        .now()
                        + 0.15
                ) {
                    usernameIsFocused =
                        true
                }
        }
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
