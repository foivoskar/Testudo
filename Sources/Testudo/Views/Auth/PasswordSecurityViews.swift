import SwiftUI


// ============================================================
// MARK: - Three-question editor
// ============================================================

struct SecurityQuestionDraftEditor:
    View
{
    @Binding
    var drafts:
        [SecurityQuestionDraft]


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                16
        ) {

            ForEach(
                0..<3,
                id:
                    \.self
            ) {
                index in

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        7
                ) {

                    Text(
                        "Security Question \(index + 1)"
                    )
                    .font(
                        .callout
                    )
                    .fontWeight(
                        .medium
                    )


                    TextField(
                        "Enter a question only you can answer",
                        text:
                            binding(
                                index:
                                    index,
                                keyPath:
                                    \.question
                            )
                    )
                    .textFieldStyle(
                        .roundedBorder
                    )


                    SecureField(
                        "Answer",
                        text:
                            binding(
                                index:
                                    index,
                                keyPath:
                                    \.answer
                            )
                    )
                    .textFieldStyle(
                        .roundedBorder
                    )
                }
            }


            Text(
                "Answers are stored only as salted hashes. Capitalization, accents and repeated spaces are ignored when checking an answer."
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
    }


    private func binding(
        index:
            Int,
        keyPath:
            WritableKeyPath<
                SecurityQuestionDraft,
                String
            >
    ) -> Binding<String> {

        Binding(
            get: {
                guard
                    drafts.indices
                        .contains(
                            index
                        )
                else {
                    return ""
                }

                return
                    drafts[index][
                        keyPath:
                            keyPath
                    ]
            },
            set: {
                newValue in

                guard
                    drafts.indices
                        .contains(
                            index
                        )
                else {
                    return
                }

                drafts[index][
                    keyPath:
                        keyPath
                ] =
                    newValue
            }
        )
    }
}


// ============================================================
// MARK: - Change Testudo application password
// ============================================================

struct ApplicationChangePasswordView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    @State
    private var currentPassword =
        ""

    @State
    private var newPassword =
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
        passwordChangeLayout(
            title:
                "Change Testudo Password",
            explanation:
                "Enter your current Testudo application password before choosing a new one."
        )
    }


    private func passwordChangeLayout(
        title:
            String,
        explanation:
            String
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                18
        ) {

            Text(
                title
            )
            .font(
                .title2
            )
            .fontWeight(
                .semibold
            )


            Text(
                explanation
            )
            .foregroundStyle(
                .secondary
            )


            SecureField(
                "Current password",
                text:
                    $currentPassword
            )


            SecureField(
                "New password",
                text:
                    $newPassword
            )


            SecureField(
                "Confirm new password",
                text:
                    $confirmation
            )


            Text(
                "Minimum 8 characters."
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
                    "Change Password"
                ) {
                    save()
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
                460
        )
    }


    private func save() {

        errorMessage =
            nil


        guard
            newPassword
                == confirmation
        else {
            errorMessage =
                "The new passwords do not match."

            return
        }


        if
            let error =
                store
                    .changeApplicationPassword(
                        currentPassword:
                            currentPassword,
                        newPassword:
                            newPassword
                    )
        {
            errorMessage =
                error

            return
        }


        dismiss()
    }
}


// ============================================================
// MARK: - Testudo application recovery-question editor
// ============================================================

struct ApplicationSecurityQuestionsView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    @State
    private var currentPassword =
        ""

    @State
    private var drafts =
        SecurityQuestionDraft
            .emptySet

    @State
    private var errorMessage:
        String?


    var body:
        some View
    {
        ScrollView {

            VStack(
                alignment:
                    .leading,
                spacing:
                    20
            ) {

                Text(
                    store.applicationRecoveryQuestionsAreConfigured
                    ? "Replace Security Questions"
                    : "Set Security Questions"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )


                Text(
                    "Enter your current Testudo password, then define all three recovery questions. Saving replaces any previously configured questions."
                )
                .foregroundStyle(
                    .secondary
                )


                SecureField(
                    "Current Testudo password",
                    text:
                        $currentPassword
                )


                Divider()


                SecurityQuestionDraftEditor(
                    drafts:
                        $drafts
                )


                if
                    let errorMessage
                {
                    Text(
                        errorMessage
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
                        "Save Security Questions"
                    ) {
                        save()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
            .padding(
                26
            )
        }
        .frame(
            width:
                560,
            height:
                620
        )
    }


    private func save() {

        errorMessage =
            store
                .setApplicationRecoveryQuestions(
                    currentPassword:
                        currentPassword,
                    drafts:
                        drafts
                )


        if errorMessage == nil {
            dismiss()
        }
    }
}


// ============================================================
// MARK: - Forgot Testudo application password
// ============================================================

struct ApplicationPasswordRecoveryView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    @State
    private var selectedQuestionID:
        UUID?

    @State
    private var answer =
        ""

    @State
    private var newPassword =
        ""

    @State
    private var confirmation =
        ""

    @State
    private var errorMessage:
        String?


    private var prompts:
        [SecurityQuestionPrompt]
    {
        store
            .applicationRecoveryQuestionPrompts
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

            Text(
                "Forgot Testudo Password?"
            )
            .font(
                .title2
            )
            .fontWeight(
                .semibold
            )


            if prompts.count == 3 {

                Text(
                    "Answer one of your three security questions and choose a new password."
                )
                .foregroundStyle(
                    .secondary
                )


                Picker(
                    "Security question",
                    selection:
                        $selectedQuestionID
                ) {
                    ForEach(
                        prompts
                    ) {
                        prompt in

                        Text(
                            prompt.question
                        )
                        .tag(
                            Optional(
                                prompt.id
                            )
                        )
                    }
                }


                SecureField(
                    "Security answer",
                    text:
                        $answer
                )


                SecureField(
                    "New password",
                    text:
                        $newPassword
                )


                SecureField(
                    "Confirm new password",
                    text:
                        $confirmation
                )


                Text(
                    "Minimum 8 characters."
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
                        "Reset Password"
                    ) {
                        reset()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }

            } else {

                Label(
                    "Password recovery has not been configured for this Testudo account.",
                    systemImage:
                        "exclamationmark.triangle"
                )


                Text(
                    "If you can still remember the password, log in and configure three security questions in Settings → Security."
                )
                .foregroundStyle(
                    .secondary
                )


                HStack {
                    Spacer()

                    Button(
                        "Close"
                    ) {
                        dismiss()
                    }
                }
            }
        }
        .padding(
            26
        )
        .frame(
            width:
                520
        )
        .onAppear {

            if selectedQuestionID == nil {
                selectedQuestionID =
                    prompts
                        .first?
                        .id
            }
        }
    }


    private func reset() {

        errorMessage =
            nil


        guard
            let selectedQuestionID
        else {
            errorMessage =
                "Choose a security question."

            return
        }


        guard
            newPassword
                == confirmation
        else {
            errorMessage =
                "The new passwords do not match."

            return
        }


        errorMessage =
            store
                .resetApplicationPasswordUsingRecovery(
                    questionID:
                        selectedQuestionID,
                    answer:
                        answer,
                    newPassword:
                        newPassword
                )


        if errorMessage == nil {
            dismiss()
        }
    }
}


// ============================================================
// MARK: - Change current Environment password
// ============================================================

struct EnvironmentChangePasswordView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    @State
    private var currentPassword =
        ""

    @State
    private var newPassword =
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
                18
        ) {

            Text(
                "Change Environment Password"
            )
            .font(
                .title2
            )
            .fontWeight(
                .semibold
            )


            Text(
                "This changes only your password for the current Work Environment."
            )
            .foregroundStyle(
                .secondary
            )


            SecureField(
                "Current Environment password",
                text:
                    $currentPassword
            )


            SecureField(
                "New Environment password",
                text:
                    $newPassword
            )


            SecureField(
                "Confirm new password",
                text:
                    $confirmation
            )


            Text(
                "Minimum 8 characters."
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
                    "Change Password"
                ) {
                    save()
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
        }
        .padding(
            26
        )
        .frame(
            width:
                470
        )
    }


    private func save() {

        errorMessage =
            nil


        guard
            newPassword
                == confirmation
        else {
            errorMessage =
                "The new passwords do not match."

            return
        }


        errorMessage =
            store
                .changeCurrentEnvironmentPassword(
                    currentPassword:
                        currentPassword,
                    newPassword:
                        newPassword
                )


        if errorMessage == nil {
            dismiss()
        }
    }
}


// ============================================================
// MARK: - Current Environment recovery questions
// ============================================================

struct EnvironmentSecurityQuestionsView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    @State
    private var currentPassword =
        ""

    @State
    private var drafts =
        SecurityQuestionDraft
            .emptySet

    @State
    private var errorMessage:
        String?


    var body:
        some View
    {
        ScrollView {

            VStack(
                alignment:
                    .leading,
                spacing:
                    20
            ) {

                Text(
                    store.currentEnvironmentRecoveryQuestionsAreConfigured
                    ? "Replace Environment Security Questions"
                    : "Set Environment Security Questions"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )


                Text(
                    "These questions belong only to your account in the current Work Environment and travel with its .testudoenv package."
                )
                .foregroundStyle(
                    .secondary
                )


                SecureField(
                    "Current Environment password",
                    text:
                        $currentPassword
                )


                Divider()


                SecurityQuestionDraftEditor(
                    drafts:
                        $drafts
                )


                if
                    let errorMessage
                {
                    Text(
                        errorMessage
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
                        "Save Security Questions"
                    ) {
                        save()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
            .padding(
                26
            )
        }
        .frame(
            width:
                560,
            height:
                620
        )
    }


    private func save() {

        errorMessage =
            store
                .setCurrentEnvironmentRecoveryQuestions(
                    currentPassword:
                        currentPassword,
                    drafts:
                        drafts
                )


        if errorMessage == nil {
            dismiss()
        }
    }
}


// ============================================================
// MARK: - Forgot Environment password
// ============================================================

struct EnvironmentPasswordRecoveryView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    let environmentID:
        UUID

    @State
    private var username:
        String

    @State
    private var selectedQuestionID:
        UUID?

    @State
    private var answer =
        ""

    @State
    private var newPassword =
        ""

    @State
    private var confirmation =
        ""

    @State
    private var errorMessage:
        String?


    init(
        environmentID:
            UUID,
        initialUsername:
            String
    ) {

        self.environmentID =
            environmentID

        _username =
            State(
                initialValue:
                    initialUsername
            )
    }


    private var prompts:
        [SecurityQuestionPrompt]
    {
        store
            .environmentRecoveryQuestionPrompts(
                environmentID:
                    environmentID,
                username:
                    username
            )
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

            Text(
                "Forgot Environment Password?"
            )
            .font(
                .title2
            )
            .fontWeight(
                .semibold
            )


            Text(
                "Enter your Environment username. If recovery questions are configured, answer one of them to set a new password."
            )
            .foregroundStyle(
                .secondary
            )


            TextField(
                "Username",
                text:
                    $username
            )


            if prompts.count == 3 {

                Picker(
                    "Security question",
                    selection:
                        $selectedQuestionID
                ) {
                    ForEach(
                        prompts
                    ) {
                        prompt in

                        Text(
                            prompt.question
                        )
                        .tag(
                            Optional(
                                prompt.id
                            )
                        )
                    }
                }


                SecureField(
                    "Security answer",
                    text:
                        $answer
                )


                SecureField(
                    "New password",
                    text:
                        $newPassword
                )


                SecureField(
                    "Confirm new password",
                    text:
                        $confirmation
                )


                Text(
                    "Minimum 8 characters."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            } else if
                !username
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            {
                Label(
                    "No recovery questions are available for this username.",
                    systemImage:
                        "exclamationmark.triangle"
                )
                .foregroundStyle(
                    .orange
                )
            }


            Text(
                "If you cannot answer a security question, contact an Environment Administrator. An Administrator can set a new password for your Environment account without knowing your old password."
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


            if
                let errorMessage
            {
                Text(
                    errorMessage
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


                if prompts.count == 3 {

                    Button(
                        "Reset Password"
                    ) {
                        reset()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                }
            }
        }
        .padding(
            26
        )
        .frame(
            width:
                540
        )
        .onAppear {
            selectFirstQuestion()
        }
        .onChange(
            of:
                username
        ) {
            selectFirstQuestion()
        }
    }


    private func selectFirstQuestion() {

        if
            !prompts
                .contains(
                    where: {
                        $0.id
                            == selectedQuestionID
                    }
                )
        {
            selectedQuestionID =
                prompts
                    .first?
                    .id
        }
    }


    private func reset() {

        errorMessage =
            nil


        guard
            let selectedQuestionID
        else {
            errorMessage =
                "Choose a security question."

            return
        }


        guard
            newPassword
                == confirmation
        else {
            errorMessage =
                "The new passwords do not match."

            return
        }


        errorMessage =
            store
                .resetEnvironmentPasswordUsingRecovery(
                    environmentID:
                        environmentID,
                    username:
                        username,
                    questionID:
                        selectedQuestionID,
                    answer:
                        answer,
                    newPassword:
                        newPassword
                )


        if errorMessage == nil {
            dismiss()
        }
    }
}


// ============================================================
// MARK: - Settings Security tab
// ============================================================

struct SecuritySettingsView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @State
    private var showingApplicationPassword =
        false

    @State
    private var showingApplicationQuestions =
        false

    @State
    private var showingEnvironmentPassword =
        false

    @State
    private var showingEnvironmentQuestions =
        false


    var body:
        some View
    {
        ScrollView {

            VStack(
                alignment:
                    .leading,
                spacing:
                    28
            ) {

                Text(
                    "Security"
                )
                .font(
                    .largeTitle
                )
                .fontWeight(
                    .semibold
                )


                securityCard(
                    title:
                        "Testudo Application Account"
                ) {

                    securityRow(
                        label:
                            "Password",
                        status:
                            "Set",
                        button:
                            "Change Password…"
                    ) {
                        showingApplicationPassword =
                            true
                    }


                    securityRow(
                        label:
                            "Security questions",
                        status:
                            store
                                .applicationRecoveryQuestionsAreConfigured
                            ? "3 configured"
                            : "Not configured",
                        button:
                            store
                                .applicationRecoveryQuestionsAreConfigured
                            ? "Replace…"
                            : "Configure…"
                    ) {
                        showingApplicationQuestions =
                            true
                    }


                    Text(
                        "The Testudo application password and recovery questions are local to this installation."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                if
                    let membership =
                        store
                            .currentEnvironmentMembership
                {
                    securityCard(
                        title:
                            "Current Environment Account"
                    ) {

                        Text(
                            membership
                                .displayName
                        )
                        .fontWeight(
                            .medium
                        )


                        if
                            let username =
                                membership
                                    .directoryUserIdentifier
                        {
                            Text(
                                username
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }


                        securityRow(
                            label:
                                "Password",
                            status:
                                "Set",
                            button:
                                "Change Password…"
                        ) {
                            showingEnvironmentPassword =
                                true
                        }


                        securityRow(
                            label:
                                "Security questions",
                            status:
                                store
                                    .currentEnvironmentRecoveryQuestionsAreConfigured
                                ? "3 configured"
                                : "Not configured",
                            button:
                                store
                                    .currentEnvironmentRecoveryQuestionsAreConfigured
                                ? "Replace…"
                                : "Configure…"
                        ) {
                            showingEnvironmentQuestions =
                                true
                        }


                        Text(
                            "If you lose access and cannot answer a recovery question, an Environment Administrator can assign a new password to your membership."
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
            .padding(
                28
            )
            .frame(
                maxWidth:
                    720,
                alignment:
                    .leading
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .center
            )
        }
        .sheet(
            isPresented:
                $showingApplicationPassword
        ) {
            ApplicationChangePasswordView()
                .environmentObject(
                    store
                )
        }
        .sheet(
            isPresented:
                $showingApplicationQuestions
        ) {
            ApplicationSecurityQuestionsView()
                .environmentObject(
                    store
                )
        }
        .sheet(
            isPresented:
                $showingEnvironmentPassword
        ) {
            EnvironmentChangePasswordView()
                .environmentObject(
                    store
                )
        }
        .sheet(
            isPresented:
                $showingEnvironmentQuestions
        ) {
            EnvironmentSecurityQuestionsView()
                .environmentObject(
                    store
                )
        }
    }


    private func securityCard<Content: View>(
        title:
            String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {

            Text(
                title
            )
            .font(
                .headline
            )

            content()
        }
        .padding(
            18
        )
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
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
    }


    private func securityRow(
        label:
            String,
        status:
            String,
        button:
            String,
        action:
            @escaping () -> Void
    ) -> some View {

        HStack {

            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {

                Text(
                    label
                )

                Text(
                    status
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Button(
                button,
                action:
                    action
            )
        }
    }
}
