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
                        .fontWeight(.semibold)

                    Text(
                        "Every DReport user is linked to a Person."
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
                        systemImage: "plus"
                    )
                }

                Button("Done") {
                    dismiss()
                }
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
                        .fontWeight(.medium)

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
                .padding(.vertical, 3)
            }
        }
        .frame(
            width: 620,
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

private enum NewUserPersonMode:
    String,
    CaseIterable,
    Identifiable
{
    case create
    case existing

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .create:
            return "Create New Person"
        case .existing:
            return "Link Existing Person"
        }
    }
}

private struct AddUserView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Binding
    var isPresented: Bool

    @State
    private var mode:
        NewUserPersonMode = .create

    @State
    private var selectedPersonID:
        UUID?

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

            Picker(
                "Person",
                selection: $mode
            ) {
                ForEach(
                    NewUserPersonMode
                        .allCases
                ) { option in
                    Text(option.label)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)

            if mode == .create {
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
            } else {
                if
                    store
                        .peopleWithoutUserAccounts
                        .isEmpty
                {
                    Text(
                        "There are no People without a user account."
                    )
                    .foregroundStyle(
                        .secondary
                    )
                } else {
                    Picker(
                        "Person",
                        selection:
                            $selectedPersonID
                    ) {
                        Text(
                            "Select a person…"
                        )
                        .tag(
                            Optional<UUID>.none
                        )

                        ForEach(
                            store
                                .peopleWithoutUserAccounts
                        ) { person in
                            Text(
                                person.name
                            )
                            .tag(
                                Optional(
                                    person.id
                                )
                            )
                        }
                    }
                }
            }

            Divider()

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
                "New accounts are currently created as Members. Permissions will be refined later."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
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
        .frame(width: 520)
    }

    private func addUser() {
        guard
            password == confirmation
        else {
            errorMessage =
                "The passwords do not match."
            return
        }

        let error: String?

        switch mode {
        case .create:
            error =
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

        case .existing:
            guard
                let selectedPersonID
            else {
                errorMessage =
                    "Select a Person first."
                return
            }

            error =
                store
                    .addMemberLinkedToExistingPerson(
                        username:
                            username,
                        password:
                            password,
                        personEntityID:
                            selectedPersonID
                    )
        }

        if let error {
            errorMessage = error
        } else {
            isPresented = false
        }
    }
}
