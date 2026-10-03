import SwiftUI


// ============================================================
// MARK: - One-time application password setup
// ============================================================

struct ApplicationPasswordSetupView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

    @State
    private var password =
        ""

    @State
    private var confirmation =
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
                22
        ) {

            Text(
                "Protect Your Testudo Profile"
            )
            .font(
                .largeTitle
            )
            .fontWeight(
                .semibold
            )


            Text(
                "Create a password for this Testudo installation. This password protects your local profile and your saved Work Environment registry. It is separate from every Work Environment password."
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


            if
                let profile =
                    store
                        .localUserProfile
            {
                Text(
                    profile.displayName
                )
                .font(
                    .title3
                )
                .fontWeight(
                    .medium
                )
            }


            SecureField(
                "Application password",
                text:
                    $password
            )
            .textFieldStyle(
                .roundedBorder
            )


            SecureField(
                "Confirm password",
                text:
                    $confirmation
            )
            .textFieldStyle(
                .roundedBorder
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
                    "Set Password"
                ) {
                    save()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    password.isEmpty
                    || confirmation.isEmpty
                )
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(
            32
        )
        .frame(
            width:
                540
        )
    }


    private func save() {

        errorMessage =
            nil


        guard
            password
                == confirmation
        else {
            errorMessage =
                "The passwords do not match."

            return
        }


        errorMessage =
            store
                .configureApplicationPassword(
                    password
                )
    }
}


// ============================================================
// MARK: - Application login
// ============================================================

struct ApplicationLoginView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

    @State
    private var password =
        ""

    @State
    private var errorMessage:
        String?

    @State
    private var showingSignOutConfirmation =
        false

    @FocusState
    private var passwordIsFocused:
        Bool


    var body:
        some View
    {
        ZStack {

            Color(
                nsColor:
                    .windowBackgroundColor
            )
            .ignoresSafeArea()


            VStack(
                spacing:
                    28
            ) {

                Spacer()


                if
                    let profile =
                        store
                            .localUserProfile
                {
                    VStack(
                        spacing:
                            18
                    ) {

                        TestudoUserAvatarView(
                            profile:
                                profile,
                            size:
                                108
                        )


                        VStack(
                            spacing:
                                6
                        ) {

                            Text(
                                "Welcome back"
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
                                profile
                                    .displayName
                            )
                            .font(
                                .title3
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }


                VStack(
                    alignment:
                        .leading,
                    spacing:
                        18
                ) {

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            6
                    ) {

                        Text(
                            "Log in to Testudo"
                        )
                        .font(
                            .headline
                        )


                        Text(
                            "Your profile and registered Work Environments are exactly as you left them."
                        )
                        .font(
                            .callout
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }


                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            7
                    ) {

                        Text(
                            "Password"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )


                        HStack(
                            spacing:
                                10
                        ) {

                            Image(
                                systemName:
                                    "lock.fill"
                            )
                            .foregroundStyle(
                                .secondary
                            )


                            SecureField(
                                "Enter your password",
                                text:
                                    $password
                            )
                            .textFieldStyle(
                                .plain
                            )
                            .focused(
                                $passwordIsFocused
                            )
                        }
                        .padding(
                            .horizontal,
                            13
                        )
                        .frame(
                            height:
                                42
                        )
                        .background {

                            RoundedRectangle(
                                cornerRadius:
                                    9,
                                style:
                                    .continuous
                            )
                            .fill(
                                Color(
                                    nsColor:
                                        .textBackgroundColor
                                )
                            )
                        }
                        .overlay {

                            RoundedRectangle(
                                cornerRadius:
                                    9,
                                style:
                                    .continuous
                            )
                            .stroke(
                                passwordIsFocused
                                ? Color
                                    .accentColor
                                    .opacity(
                                        0.75
                                    )
                                : Color
                                    .primary
                                    .opacity(
                                        0.10
                                    ),
                                lineWidth:
                                    passwordIsFocused
                                    ? 2
                                    : 1
                            )
                        }
                    }


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
                    }


                    Button(
                        "Log In"
                    ) {
                        login()
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
                        password.isEmpty
                    )
                    .keyboardShortcut(
                        .defaultAction
                    )
                }
                .padding(
                    24
                )
                .frame(
                    width:
                        440
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
                .overlay {

                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
                    .stroke(
                        Color
                            .primary
                            .opacity(
                                0.07
                            ),
                        lineWidth:
                            1
                    )
                }


                Button(
                    "Sign Out from Testudo…",
                    role:
                        .destructive
                ) {
                    showingSignOutConfirmation =
                        true
                }
                .buttonStyle(
                    .plain
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )


                Spacer()
                Spacer()
            }
            .padding(
                44
            )
        }
        .onAppear {

            DispatchQueue
                .main
                .asyncAfter(
                    deadline:
                        .now()
                        + 0.2
                ) {
                    passwordIsFocused =
                        true
                }
        }
        .sheet(
            isPresented:
                $showingSignOutConfirmation
        ) {
            ApplicationSignOutConfirmationView {

                store
                    .signOutApplicationAndRemoveLocalData()

                showingSignOutConfirmation =
                    false
            }
        }
    }


    private func login() {

        errorMessage =
            store
                .unlockApplication(
                    password:
                        password
                )


        if errorMessage == nil {
            password =
                ""
        }
    }
}


// ============================================================
// MARK: - Destructive local sign out confirmation
// ============================================================

struct ApplicationSignOutConfirmationView:
    View
{
    @Environment(
        \.dismiss
    )
    private var dismiss


    @State
    private var confirmation =
        ""


    let onConfirm:
        () -> Void


    private var isConfirmed:
        Bool
    {
        confirmation
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .uppercased()
            == "SIGN OUT"
    }


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                18
        ) {

            Label(
                "Sign Out from Testudo",
                systemImage:
                    "exclamationmark.triangle.fill"
            )
            .font(
                .title2
            )
            .fontWeight(
                .semibold
            )


            Text(
                "This is not the same as Log Out."
            )
            .fontWeight(
                .semibold
            )


            Text(
                "If you only want to lock Testudo and return later with everything exactly as you left it, cancel this action and choose Log Out instead."
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )


            Divider()


            Text(
                "Before signing out, you can save your personal profile as a .testudouser file."
            )
            .fontWeight(
                .medium
            )


            Text(
                "Importing that file later restores your profile information and avatar, but not your application password or your Work Environment registry."
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


            TestudoUserProfileExportButton(
                title:
                    "Export My Profile Before Signing Out…"
            )


            Divider()


            Text(
                "Signing out removes this Testudo user's local profile, application password, registered Work Environments, local bookmarks, Environment identity mappings and remembered sign-ins from this Mac."
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )


            Text(
                "Your .testudoenv packages and all data stored inside them are NOT deleted or modified. After signing in as a new local user, reopen the Environment packages you want to use."
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


            VStack(
                alignment:
                    .leading,
                spacing:
                    6
            ) {

                Text(
                    "Type SIGN OUT to continue:"
                )
                .font(
                    .callout
                )
                .fontWeight(
                    .medium
                )


                TextField(
                    "SIGN OUT",
                    text:
                        $confirmation
                )
                .textFieldStyle(
                    .roundedBorder
                )
            }


            HStack {

                Button(
                    "Cancel"
                ) {
                    dismiss()
                }


                Spacer()


                Button(
                    "Sign Out and Remove Local Data",
                    role:
                        .destructive
                ) {
                    onConfirm()
                    dismiss()
                }
                .disabled(
                    !isConfirmed
                )
            }
        }
        .padding(
            26
        )
        .frame(
            width:
                580
        )
    }
}


// ============================================================
// MARK: - Settings authentication gate
// ============================================================

struct ApplicationSettingsGateView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore


    var body:
        some View
    {
        Group {

            if
                store
                    .applicationSessionIsOpen
            {
                SettingsView()

            } else {

                VStack(
                    spacing:
                        10
                ) {

                    Image(
                        systemName:
                            "lock.fill"
                    )
                    .font(
                        .system(
                            size:
                                28
                        )
                    )


                    Text(
                        "Testudo is locked"
                    )
                    .font(
                        .title3
                    )
                    .fontWeight(
                        .semibold
                    )


                    Text(
                        "Log in from the main Testudo window to access Settings."
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    36
                )
            }
        }
    }
}
