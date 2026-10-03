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
                "Log In to Testudo"
            )
            .font(
                .largeTitle
            )
            .fontWeight(
                .semibold
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


            Text(
                "Your local profile, Work Environment registry and remembered Environment sessions are still here exactly as you left them."
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


            SecureField(
                "Password",
                text:
                    $password
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

                Button(
                    "Sign Out from Testudo…",
                    role:
                        .destructive
                ) {
                    showingSignOutConfirmation =
                        true
                }


                Spacer()


                Button(
                    "Log In"
                ) {
                    login()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    password.isEmpty
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
                560
        )
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
                "Signing out removes this Testudo user's local profile, application password, registered Work Environments, local bookmarks, Environment identity mappings and remembered sign-ins from this Mac."
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )


            Text(
                "Your .testudoenv packages and all data stored inside them are NOT deleted or modified. To use them again, the next local user must open those Environment packages again."
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
                560
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
