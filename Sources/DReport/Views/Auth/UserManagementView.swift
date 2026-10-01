import SwiftUI

struct UserManagementView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var showingAddUser = false

    @State
    private var selectedUserID: UUID?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Users")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        showingAddUser = true
                    } label: {
                        Image(
                            systemName:
                                "plus"
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Add User")
                }
                .padding(
                    .horizontal,
                    14
                )
                .padding(
                    .vertical,
                    12
                )

                List(
                    selection:
                        $selectedUserID
                ) {
                    ForEach(
                        store.users
                    ) { user in
                        UserManagementRow(
                            user: user
                        )
                        .tag(user.id)
                    }
                }
            }
            .navigationSplitViewColumnWidth(
                min: 230,
                ideal: 270,
                max: 330
            )
        } detail: {
            if
                let selectedUserID
            {
                UserAccountEditorView(
                    userID:
                        selectedUserID
                )
            } else {
                ContentUnavailableView {
                    Label(
                        "Select a User",
                        systemImage:
                            "person.crop.circle"
                    )
                } description: {
                    Text(
                        "Choose an account to manage its username, password and linked Person."
                    )
                }
            }
        }
        .frame(
            minWidth: 820,
            idealWidth: 900,
            minHeight: 560,
            idealHeight: 620
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
        .toolbar {
            ToolbarItem {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct UserManagementRow: View {
    @EnvironmentObject
    private var store: DReportStore

    let user: DReportUser

    var body: some View {
        HStack(spacing: 10) {
            UserAvatarView(
                user: user,
                size: 30
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    personName
                )
                .fontWeight(.medium)
                .lineLimit(1)

                Text(
                    "@\(user.username)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)
            }

            Spacer()

            if !user.isActive {
                Image(
                    systemName:
                        "pause.circle"
                )
                .foregroundStyle(
                    .secondary
                )
                .help(
                    "Disabled account"
                )
            }
        }
        .padding(.vertical, 2)
    }

    private var personName: String {
        guard
            let personID =
                user.personEntityID,
            let person =
                store.entity(
                    id: personID
                )
        else {
            return user.displayName
        }

        return person.name
    }
}

struct UserAccountEditorView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Environment(\.dismiss)
    private var dismiss

    let userID: UUID

    var showsCloseButton: Bool = false

    @State
    private var username = ""

    @State
    private var selectedPersonID:
        UUID?

    @State
    private var accountIsActive = true

    @State
    private var showingPasswordSheet =
        false

    @State
    private var message: String?

    @State
    private var messageIsError =
        false

    var body: some View {
        if
            let user =
                store.user(
                    id: userID
                )
        {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 26
                ) {
                    if showsCloseButton {
                        HStack {
                            Spacer()

                            Button("Done") {
                                dismiss()
                            }
                            .keyboardShortcut(.cancelAction)
                        }
                    }

                    header(user)

                    accountSection(user)

                    personSection(user)

                    passwordSection

                    statusSection(user)

                    metadataSection(user)
                }
                .padding(28)
                .frame(
                    maxWidth: 680,
                    alignment: .leading
                )
            }
            .onAppear {
                load(user)
            }
            .onChange(
                of: userID
            ) {
                if
                    let latest =
                        store.user(
                            id: userID
                        )
                {
                    load(latest)
                }
            }
            .sheet(
                isPresented:
                    $showingPasswordSheet
            ) {
                ChangePasswordView(
                    userID: userID,
                    isPresented:
                        $showingPasswordSheet
                )
            }
        } else {
            ContentUnavailableView(
                "User Not Found",
                systemImage:
                    "person.crop.circle.badge.questionmark"
            )
        }
    }

    private func header(
        _ user: DReportUser
    ) -> some View {
        HStack(spacing: 14) {
            UserAvatarView(
                user: user,
                size: 46
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    linkedPersonName(
                        user
                    )
                )
                .font(.title2)
                .fontWeight(.semibold)

                Text(
                    "@\(user.username)"
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Text(
                user.role.displayName
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func accountSection(
        _ user: DReportUser
    ) -> some View {
        accountGroup(
            "Account"
        ) {
            LabeledContent(
                "Username"
            ) {
                TextField(
                    "Username",
                    text: $username
                )
                .frame(width: 260)
            }

            HStack {
                Spacer()

                Button(
                    "Save Username"
                ) {
                    saveUsername()
                }
            }
        }
    }

    private func personSection(
        _ user: DReportUser
    ) -> some View {
        accountGroup(
            "Linked Person"
        ) {
            Picker(
                "Person",
                selection:
                    $selectedPersonID
            ) {
                ForEach(
                    store
                        .availablePeopleForUserLink(
                            userID:
                                userID
                        )
                ) { person in
                    Text(person.name)
                        .tag(
                            Optional(
                                person.id
                            )
                        )
                }
            }

            Text(
                "Every user must be linked to exactly one Person. Changing this does not delete the previous Person."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            HStack {
                Spacer()

                Button(
                    "Change Linked Person"
                ) {
                    savePersonLink()
                }
                .disabled(
                    selectedPersonID
                        == nil
                    || selectedPersonID
                        == user.personEntityID
                )
            }
        }
    }

    private var passwordSection:
        some View
    {
        accountGroup(
            "Password"
        ) {
            HStack {
                Text(
                    "Password is stored only as a salted cryptographic hash."
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )

                Spacer()

                Button(
                    "Change Password…"
                ) {
                    showingPasswordSheet =
                        true
                }
            }
        }
    }

    private func statusSection(
        _ user: DReportUser
    ) -> some View {
        accountGroup(
            "Account Status"
        ) {
            Toggle(
                "Account active",
                isOn:
                    $accountIsActive
            )

            if
                store.currentUserID
                    == user.id
            {
                Text(
                    "The account currently in use cannot be disabled from this screen."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            HStack {
                Spacer()

                Button(
                    "Apply Status"
                ) {
                    saveStatus()
                }
                .disabled(
                    accountIsActive
                        == user.isActive
                )
            }
        }
    }

    private func metadataSection(
        _ user: DReportUser
    ) -> some View {
        accountGroup(
            "Information"
        ) {
            LabeledContent(
                "Role",
                value:
                    user.role
                        .displayName
            )

            LabeledContent(
                "Created",
                value:
                    user.createdAt
                        .formatted(
                            date:
                                .abbreviated,
                            time:
                                .shortened
                        )
            )

            if
                let lastLogin =
                    user.lastLoginAt
            {
                LabeledContent(
                    "Last login",
                    value:
                        lastLogin
                            .formatted(
                                date:
                                    .abbreviated,
                                time:
                                    .shortened
                            )
                )
            }

            if let message {
                Label(
                    message,
                    systemImage:
                        messageIsError
                        ? "exclamationmark.triangle"
                        : "checkmark.circle"
                )
                .font(.callout)
                .foregroundStyle(
                    messageIsError
                    ? Color.red
                    : Color.secondary
                )
                .padding(.top, 4)
            }
        }
    }

    private func accountGroup<Content: View>(
        _ title: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text(title)
                .font(.headline)

            content()
        }
    }

    private func load(
        _ user: DReportUser
    ) {
        username =
            user.username

        selectedPersonID =
            user.personEntityID

        accountIsActive =
            user.isActive

        message = nil
    }

    private func saveUsername() {
        let error =
            store.updateUsername(
                userID:
                    userID,
                username:
                    username
            )

        showResult(error)
    }

    private func savePersonLink() {
        guard
            let selectedPersonID
        else {
            return
        }

        let error =
            store.relinkUser(
                userID:
                    userID,
                toPerson:
                    selectedPersonID
            )

        showResult(error)
    }

    private func saveStatus() {
        let error =
            store.setUserActive(
                userID:
                    userID,
                isActive:
                    accountIsActive
            )

        if let error {
            if
                let latest =
                    store.user(
                        id: userID
                    )
            {
                accountIsActive =
                    latest.isActive
            }
        }

        showResult(error)
    }

    private func showResult(
        _ error: String?
    ) {
        if let error {
            message = error
            messageIsError = true
        } else {
            message = "Changes saved."
            messageIsError = false
        }
    }

    private func linkedPersonName(
        _ user: DReportUser
    ) -> String {
        guard
            let personID =
                user.personEntityID,
            let person =
                store.entity(
                    id: personID
                )
        else {
            return user.displayName
        }

        return person.name
    }
}

private struct ChangePasswordView: View {
    @EnvironmentObject
    private var store: DReportStore

    let userID: UUID

    @Binding
    var isPresented: Bool

    @State
    private var password = ""

    @State
    private var confirmation = ""

    @State
    private var errorMessage: String?

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Text("Change Password")
                .font(.title2)
                .fontWeight(.semibold)

            SecureField(
                "New password",
                text:
                    $password
            )

            SecureField(
                "Confirm new password",
                text:
                    $confirmation
            )

            Text(
                "Passwords must contain at least 8 characters."
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

                Button(
                    "Change Password"
                ) {
                    save()
                }
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func save() {
        guard
            password == confirmation
        else {
            errorMessage =
                "The passwords do not match."
            return
        }

        let error =
            store.changeUserPassword(
                userID:
                    userID,
                newPassword:
                    password
            )

        if let error {
            errorMessage = error
        } else {
            isPresented = false
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
                            Text(person.name)
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
                "New accounts are currently created as Members. Roles and detailed permissions will be refined later."
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
