import SwiftUI


// ============================================================
// MARK: - Local application user profile editor
//
// LocalUserProfile and Environment PersonProfile intentionally
// remain separate.
//
// The user may explicitly copy selected values from the Person
// linked to the current Environment membership into this draft.
// Nothing is synchronized automatically.
// ============================================================

struct LocalUserProfileEditorView:
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
    private var draft:
        LocalUserProfile

    @State
    private var errorMessage:
        String?

    @State
    private var showingEnvironmentImport =
        false


    init(
        profile:
            LocalUserProfile
    ) {

        _draft =
            State(
                initialValue:
                    profile
            )
    }


    // ========================================================
    // MARK: Current Environment Person
    // ========================================================

    private var currentEnvironmentPersonProfile:
        PersonProfile?
    {
        guard
            let personID =
                store
                    .currentEnvironmentMembership?
                    .personEntityID
        else {
            return nil
        }


        return
            store
                .personProfile(
                    for:
                        personID
                )
    }


    private var currentEnvironmentName:
        String
    {
        store
            .activeWorkEnvironment?
            .name
        ?? "Current Environment"
    }


    // ========================================================
    // MARK: Body
    // ========================================================

    var body:
        some View
    {
        VStack(
            spacing:
                0
        ) {

            header

            Divider()


            ScrollView {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        24
                ) {

                    AvatarPicker(
                        avatarData:
                            $draft.avatarData
                    )


                    if
                        let environmentProfile =
                            currentEnvironmentPersonProfile
                    {
                        environmentImportCard(
                            environmentProfile
                        )
                    }


                    editSection(
                        "Identity"
                    ) {

                        profileField(
                            "First name",
                            text:
                                binding(
                                    \.firstName
                                )
                        )

                        profileField(
                            "Middle name",
                            text:
                                binding(
                                    \.middleName
                                )
                        )

                        profileField(
                            "Last name",
                            text:
                                binding(
                                    \.lastName
                                )
                        )

                        profileField(
                            "Preferred / display name",
                            text:
                                binding(
                                    \.preferredName
                                )
                        )

                        profileField(
                            "Academic title",
                            text:
                                optionalBinding(
                                    \.academicTitle
                                )
                        )

                        profileField(
                            "Position / job title",
                            text:
                                binding(
                                    \.jobTitle
                                )
                        )
                    }


                    editSection(
                        "Professional Contact"
                    ) {

                        profileField(
                            "Email",
                            text:
                                binding(
                                    \.professionalEmail
                                )
                        )

                        profileField(
                            "Secondary email",
                            text:
                                binding(
                                    \.secondaryProfessionalEmail
                                )
                        )

                        profileField(
                            "Phone",
                            text:
                                binding(
                                    \.professionalPhone
                                )
                        )

                        profileField(
                            "Secondary phone",
                            text:
                                optionalBinding(
                                    \.secondaryPhone
                                )
                        )

                        profileField(
                            "Office",
                            text:
                                binding(
                                    \.office
                                )
                        )

                        profileField(
                            "Assistant / contact",
                            text:
                                optionalBinding(
                                    \.assistantContact
                                )
                        )
                    }


                    editSection(
                        "Workplace"
                    ) {

                        profileField(
                            "Staff / employee ID",
                            text:
                                binding(
                                    \.employeeID
                                )
                        )

                        profileField(
                            "Address",
                            text:
                                optionalBinding(
                                    \.professionalAddress
                                )
                        )

                        profileField(
                            "City",
                            text:
                                optionalBinding(
                                    \.city
                                )
                        )

                        profileField(
                            "Postal code",
                            text:
                                optionalBinding(
                                    \.postalCode
                                )
                        )

                        profileField(
                            "Country",
                            text:
                                optionalBinding(
                                    \.country
                                )
                        )
                    }


                    editSection(
                        "Online"
                    ) {

                        profileField(
                            "Website",
                            text:
                                binding(
                                    \.website
                                )
                        )

                        profileField(
                            "LinkedIn",
                            text:
                                binding(
                                    \.linkedIn
                                )
                        )

                        profileField(
                            "GitHub",
                            text:
                                binding(
                                    \.github
                                )
                        )
                    }


                    editSection(
                        "Research & Professional"
                    ) {

                        profileField(
                            "ORCID",
                            text:
                                binding(
                                    \.orcid
                                )
                        )

                        profileField(
                            "ResearcherID",
                            text:
                                optionalBinding(
                                    \.researcherID
                                )
                        )

                        profileField(
                            "Scopus Author ID",
                            text:
                                optionalBinding(
                                    \.scopusAuthorID
                                )
                        )

                        profileField(
                            "Google Scholar",
                            text:
                                optionalBinding(
                                    \.googleScholarURL
                                )
                        )

                        profileField(
                            "Fields / expertise",
                            text:
                                binding(
                                    \.professionalFields
                                )
                        )

                        profileField(
                            "Responsibilities",
                            text:
                                binding(
                                    \.responsibilities
                                )
                        )

                        profileField(
                            "Tags",
                            text:
                                optionalBinding(
                                    \.tags
                                )
                        )
                    }


                    editSection(
                        "Preferences"
                    ) {

                        profileField(
                            "Preferred language",
                            text:
                                optionalBinding(
                                    \.preferredLanguage
                                )
                        )


                        LabeledContent(
                            "Time zone"
                        ) {

                            Picker(
                                "",
                                selection:
                                    optionalBinding(
                                        \.timeZone
                                    )
                            ) {

                                Text(
                                    "System default"
                                )
                                .tag(
                                    ""
                                )


                                ForEach(
                                    TimeZone
                                        .knownTimeZoneIdentifiers,
                                    id:
                                        \.self
                                ) {
                                    identifier in

                                    Text(
                                        TestudoTime
                                            .timeZoneLabel(
                                                identifier:
                                                    identifier
                                            )
                                    )
                                    .tag(
                                        identifier
                                    )
                                }
                            }
                            .labelsHidden()
                            .frame(
                                minWidth:
                                    320
                            )
                        }
                    }


                    editSection(
                        "Notes"
                    ) {

                        TextEditor(
                            text:
                                binding(
                                    \.notes
                                )
                        )
                        .frame(
                            minHeight:
                                120
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius:
                                    6
                            )
                            .stroke(
                                Color
                                    .secondary
                                    .opacity(
                                        0.2
                                    )
                            )
                        }
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
                }
                .padding(
                    24
                )
            }


            Divider()

            footer
        }
        .frame(
            width:
                720,
            height:
                760
        )
        .sheet(
            isPresented:
                $showingEnvironmentImport
        ) {

            if
                let profile =
                    currentEnvironmentPersonProfile
            {
                EnvironmentToLocalProfileImportView(
                    profile:
                        profile,
                    environmentName:
                        currentEnvironmentName
                ) {
                    fields in

                    importFromEnvironment(
                        profile:
                            profile,
                        fields:
                            fields
                    )
                }
            }
        }
    }


    // ========================================================
    // MARK: Header / footer
    // ========================================================

    private var header:
        some View
    {
        HStack(
            alignment:
                .center,
            spacing:
                16
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {

                Text(
                    "My Profile"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )


                Text(
                    "This profile belongs to this Testudo application user and is included when you export a .testudouser profile."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()
        }
        .padding(
            24
        )
    }


    private var footer:
        some View
    {
        HStack {

            Spacer()


            Button(
                "Cancel"
            ) {
                dismiss()
            }


            Button(
                "Save"
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
        .padding(
            18
        )
    }


    // ========================================================
    // MARK: Environment import
    // ========================================================

    private func environmentImportCard(
        _ profile:
            PersonProfile
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {

            HStack {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        3
                ) {

                    Text(
                        "Current Environment Profile"
                    )
                    .font(
                        .headline
                    )


                    Text(
                        "\(profile.displayName) · \(currentEnvironmentName)"
                    )
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Spacer()


                Button(
                    "Import from Current Environment Profile…"
                ) {
                    showingEnvironmentImport =
                        true
                }
                .buttonStyle(
                    .bordered
                )
            }


            Text(
                "Choose information to copy into My Profile. This is a one-time copy; the two profiles remain independent afterwards."
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
            16
        )
        .background(
            Color
                .secondary
                .opacity(
                    0.07
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        12,
                    style:
                        .continuous
                )
        )
    }


    private func importFromEnvironment(
        profile:
            PersonProfile,
        fields:
            Set<LocalProfileImportField>
    ) {

        var updated =
            draft


        for field in
            fields
        {
            field
                .copyValue(
                    from:
                        profile,
                    to:
                        &updated
                )
        }


        draft =
            updated
    }


    // ========================================================
    // MARK: Form helpers
    // ========================================================

    @ViewBuilder
    private func editSection<
        Content:
            View
    >(
        _ title:
            String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {

            Text(
                title
            )
            .font(
                .headline
            )


            content()
        }
    }


    private func profileField(
        _ label:
            String,
        text:
            Binding<String>
    ) -> some View {

        LabeledContent(
            label
        ) {

            TextField(
                "",
                text:
                    text
            )
            .textFieldStyle(
                .roundedBorder
            )
            .frame(
                minWidth:
                    320
            )
        }
    }


    private func binding(
        _ keyPath:
            WritableKeyPath<
                LocalUserProfile,
                String
            >
    ) -> Binding<String> {

        Binding(
            get: {
                draft[
                    keyPath:
                        keyPath
                ]
            },
            set: {
                draft[
                    keyPath:
                        keyPath
                ] =
                    $0
            }
        )
    }


    private func optionalBinding(
        _ keyPath:
            WritableKeyPath<
                LocalUserProfile,
                String?
            >
    ) -> Binding<String> {

        Binding(
            get: {
                draft[
                    keyPath:
                        keyPath
                ]
                ?? ""
            },
            set: {

                let cleaned =
                    $0
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )


                draft[
                    keyPath:
                        keyPath
                ] =
                    cleaned.isEmpty
                    ? nil
                    : $0
            }
        )
    }


    // ========================================================
    // MARK: Save
    // ========================================================

    private func save() {

        errorMessage =
            store
                .saveLocalUserProfile(
                    draft
                )


        if
            errorMessage
                == nil
        {
            dismiss()
        }
    }
}


// ============================================================
// MARK: - Environment → My Profile selection
// ============================================================

private struct EnvironmentToLocalProfileImportView:
    View
{
    @Environment(
        \.dismiss
    )
    private var dismiss


    let profile:
        PersonProfile

    let environmentName:
        String

    let onImport:
        (Set<LocalProfileImportField>) -> Void


    @State
    private var selectedFields:
        Set<LocalProfileImportField>


    init(
        profile:
            PersonProfile,
        environmentName:
            String,
        onImport:
            @escaping (
                Set<LocalProfileImportField>
            ) -> Void
    ) {

        self.profile =
            profile

        self.environmentName =
            environmentName

        self.onImport =
            onImport


        _selectedFields =
            State(
                initialValue:
                    Set(
                        LocalProfileImportField
                            .allCases
                            .filter {
                                $0
                                    .hasValue(
                                        in:
                                            profile
                                    )
                            }
                    )
            )
    }


    private var availableFields:
        [LocalProfileImportField]
    {
        LocalProfileImportField
            .allCases
            .filter {
                $0
                    .hasValue(
                        in:
                            profile
                    )
            }
    }


    var body:
        some View
    {
        VStack(
            spacing:
                0
        ) {

            VStack(
                alignment:
                    .leading,
                spacing:
                    7
            ) {

                Text(
                    "Import from Current Environment Profile"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )


                Text(
                    "\(profile.displayName) · \(environmentName)"
                )
                .foregroundStyle(
                    .secondary
                )


                Text(
                    "Select the information to copy into My Profile. Existing local values for selected fields will be replaced. This does not create live synchronization."
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
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
            .padding(
                24
            )


            Divider()


            if
                availableFields
                    .isEmpty
            {
                ContentUnavailableView(
                    "No Profile Information",
                    systemImage:
                        "person.crop.circle.badge.questionmark",
                    description:
                        Text(
                            "The linked Environment Person does not contain information that can be imported."
                        )
                )

            } else {

                ScrollView {

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            22
                    ) {

                        ForEach(
                            LocalProfileImportSection
                                .allCases
                        ) {
                            section in

                            let fields =
                                availableFields
                                    .filter {
                                        $0.section
                                            == section
                                    }


                            if
                                !fields
                                    .isEmpty
                            {
                                fieldSection(
                                    section,
                                    fields:
                                        fields
                                )
                            }
                        }
                    }
                    .padding(
                        24
                    )
                }
            }


            Divider()


            HStack {

                Button(
                    "Select All"
                ) {

                    selectedFields =
                        Set(
                            availableFields
                        )
                }
                .disabled(
                    availableFields
                        .isEmpty
                )


                Button(
                    "Select None"
                ) {

                    selectedFields =
                        []
                }
                .disabled(
                    selectedFields
                        .isEmpty
                )


                Spacer()


                Button(
                    "Cancel"
                ) {
                    dismiss()
                }


                Button(
                    "Import Selected"
                ) {

                    onImport(
                        selectedFields
                    )

                    dismiss()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    selectedFields
                        .isEmpty
                )
            }
            .padding(
                18
            )
        }
        .frame(
            width:
                650,
            height:
                700
        )
    }


    @ViewBuilder
    private func fieldSection(
        _ section:
            LocalProfileImportSection,
        fields:
            [LocalProfileImportField]
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {

            Text(
                section.rawValue
            )
            .font(
                .headline
            )


            VStack(
                spacing:
                    8
            ) {

                ForEach(
                    fields
                ) {
                    field in

                    Toggle(
                        isOn:
                            selectionBinding(
                                for:
                                    field
                            )
                    ) {

                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                2
                        ) {

                            Text(
                                field.label
                            )


                            let value =
                                field
                                    .displayValue(
                                        from:
                                            profile
                                    )


                            if
                                !value.isEmpty,
                                field
                                    != .avatar
                            {
                                Text(
                                    value
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                                .lineLimit(
                                    2
                                )
                            }
                        }
                    }
                    .toggleStyle(
                        .checkbox
                    )
                }
            }
        }
    }


    private func selectionBinding(
        for field:
            LocalProfileImportField
    ) -> Binding<Bool> {

        Binding(
            get: {

                selectedFields
                    .contains(
                        field
                    )
            },
            set: {
                selected in

                if
                    selected
                {
                    selectedFields
                        .insert(
                            field
                        )

                } else {

                    selectedFields
                        .remove(
                            field
                        )
                }
            }
        )
    }
}
