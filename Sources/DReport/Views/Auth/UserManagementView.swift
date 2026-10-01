import SwiftUI

struct UserManagementView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var showingAddUser = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text("Users")
                        .font(.title2)
                        .fontWeight(
                            .semibold
                        )

                    Text(
                        "Accounts that can use this DReport installation."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                Button {
                    showingAddUser = true
                } label: {
                    Label(
                        "Add User",
                        systemImage:
                            "plus"
                    )
                }

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(
                    .cancelAction
                )
            }
            .padding()

            Divider()

            List(store.users) { user in
                HStack(spacing: 12) {
                    UserAvatarView(
                        user: user,
                        size: 34
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text(
                            user.displayName
                        )
                        .fontWeight(
                            .medium
                        )

                        Text(
                            "@\(user.username)"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Text(
                        user.role
                            .displayName
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .vertical,
                    3
                )
            }
        }
        .frame(
            width: 600,
            height: 440
        )
        .sheet(
            isPresented:
                $showingAddUser
        ) {
            AddUserView(
                isPresented:
                    $showingAddUser
            )
        }
    }
}

private struct AddUserView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Binding
    var isPresented: Bool

    @State
    private var firstName = ""

    @State
    private var lastName = ""

    @State
    private var username = ""

    @State
    private var password = ""

    @State
    private var confirmation = ""

    @State
    private var avatarData: Data?

    @State
    private var errorMessage: String?

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Text("Add User")
                .font(.title2)
                .fontWeight(.semibold)

            AvatarPicker(
                avatarData:
                    $avatarData
            )

            HStack(spacing: 12) {
                TextField(
                    "First name",
                    text:
                        $firstName
                )

                TextField(
                    "Last name",
                    text:
                        $lastName
                )
            }

            TextField(
                "Username",
                text:
                    $username
            )

            SecureField(
                "Password",
                text:
                    $password
            )

            SecureField(
                "Confirm password",
                text:
                    $confirmation
            )

            Text(
                "New accounts are created as Members. Detailed permissions will be added later."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(
                        .red
                    )
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }

                Button("Add User") {
                    addUser()
                }
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func addUser() {
        guard
            password == confirmation
        else {
            errorMessage =
                "The passwords do not match."
            return
        }

        let error =
            store.addMember(
                username:
                    username,
                firstName:
                    firstName,
                lastName:
                    lastName,
                password:
                    password,
                avatarData:
                    avatarData
            )

        if let error {
            errorMessage = error
        } else {
            isPresented = false
        }
    }
}
