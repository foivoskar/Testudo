import SwiftUI


// ============================================================
// MARK: - My Profile in Current Environment
// ============================================================

struct CurrentEnvironmentProfileImportSummaryView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

    @State
    private var showingImport =
        false

    @State
    private var message:
        String?


    private var membership:
        EnvironmentMembership?
    {
        store
            .currentEnvironmentMembership
    }


    private var person:
        Entity?
    {
        guard
            let personID =
                membership?
                    .personEntityID
        else {
            return nil
        }

        return
            store.entity(
                id:
                    personID
            )
    }


    private var personProfile:
        PersonProfile?
    {
        guard
            let personID =
                membership?
                    .personEntityID
        else {
            return nil
        }

        return
            store.personProfile(
                for:
                    personID
            )
    }


    private var personDisplayName:
        String
    {
        if
            let profile =
                personProfile,
            !profile
                .displayName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
        {
            return profile.displayName
        }

        return
            person?.name
            ?? "Linked Person"
    }


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {

            if
                store
                    .activeWorkEnvironment
                    == nil
            {
                Text(
                    "Open a Work Environment to manage your Environment-specific profile."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )

            } else if membership == nil {

                Text(
                    "No Environment membership is currently active."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )

            } else if person == nil {

                Text(
                    "Your Environment membership is not linked to a Person in People."
                )
                .font(
                    .callout
                )

                Text(
                    "An Environment Administrator can link this membership to the corresponding Person. Until then, personal information cannot be imported into the Environment."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                HStack(
                    alignment:
                        .center,
                    spacing:
                        12
                ) {

                    Image(
                        systemName:
                            "person.crop.circle.badge.checkmark"
                    )
                    .font(
                        .system(
                            size:
                                25
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )


                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            3
                    ) {

                        Text(
                            personDisplayName
                        )
                        .fontWeight(
                            .medium
                        )


                        if
                            let environmentName =
                                store
                                    .activeWorkEnvironment?
                                    .name
                        {
                            Text(
                                environmentName
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }


                    Spacer()


                    Button(
                        "Import from My Profile…"
                    ) {
                        message =
                            nil

                        showingImport =
                            true
                    }
                    .buttonStyle(
                        .bordered
                    )
                    .disabled(
                        store.localUserProfile
                            == nil
                    )
                }


                Text(
                    "Imported values are copied into this Environment only. They are not synchronized afterwards, so you can keep different information in different Work Environments."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )


                if
                    let message
                {
                    Label(
                        message,
                        systemImage:
                            "checkmark.circle"
                    )
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
        .sheet(
            isPresented:
                $showingImport
        ) {
            if
                let localProfile =
                    store.localUserProfile,
                let environmentName =
                    store
                        .activeWorkEnvironment?
                        .name,
                person != nil
            {
                LocalProfileImportSelectionView(
                    profile:
                        localProfile,
                    environmentName:
                        environmentName,
                    personName:
                        personDisplayName
                ) {
                    message =
                        "Selected information was imported into your Environment profile."
                }
                .environmentObject(
                    store
                )
            }
        }
    }
}


// ============================================================
// MARK: - Field selection sheet
// ============================================================

private struct LocalProfileImportSelectionView:
    View
{
    @EnvironmentObject
    private var store:
        DReportStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    let profile:
        LocalUserProfile

    let environmentName:
        String

    let personName:
        String

    let onImported:
        () -> Void


    @State
    private var selectedFields:
        Set<LocalProfileImportField>

    @State
    private var errorMessage:
        String?


    init(
        profile:
            LocalUserProfile,
        environmentName:
            String,
        personName:
            String,
        onImported:
            @escaping () -> Void
    ) {

        self.profile =
            profile

        self.environmentName =
            environmentName

        self.personName =
            personName

        self.onImported =
            onImported


        let initiallySelected =
            Set(
                LocalProfileImportField
                    .allCases
                    .filter {
                        $0.hasValue(
                            in:
                                profile
                        )
                    }
            )


        _selectedFields =
            State(
                initialValue:
                    initiallySelected
            )
    }


    private var availableFields:
        [LocalProfileImportField]
    {
        LocalProfileImportField
            .allCases
            .filter {
                $0.hasValue(
                    in:
                        profile
                )
            }
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

            header


            Divider()


            if availableFields.isEmpty {

                ContentUnavailableView(
                    "No Information to Import",
                    systemImage:
                        "person.text.rectangle",
                    description:
                        Text(
                            "Your local profile does not currently contain any populated fields."
                        )
                )
                .frame(
                    minHeight:
                        260
                )

            } else {

                HStack {

                    Text(
                        "\(selectedFields.count) of \(availableFields.count) selected"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )


                    Spacer()


                    Button(
                        "Select All"
                    ) {
                        selectedFields =
                            Set(
                                availableFields
                            )
                    }
                    .buttonStyle(
                        .plain
                    )


                    Button(
                        "Clear"
                    ) {
                        selectedFields =
                            []
                    }
                    .buttonStyle(
                        .plain
                    )
                }


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


                            if !fields.isEmpty {

                                fieldSection(
                                    section,
                                    fields:
                                        fields
                                )
                            }
                        }
                    }
                    .padding(
                        .vertical,
                        2
                    )
                }
            }


            if
                let errorMessage
            {
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


            Divider()


            HStack {

                Text(
                    "Only selected fields will be overwritten in this Environment."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
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
                    importSelected()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    selectedFields
                        .isEmpty
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
                640
        )
        .frame(
            minHeight:
                520,
            idealHeight:
                680,
            maxHeight:
                760
        )
    }


    private var header:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                6
        ) {

            Text(
                "Import from My Testudo Profile"
            )
            .font(
                .title2
            )
            .fontWeight(
                .semibold
            )


            Text(
                "Copy selected information to \(personName) in \(environmentName)."
            )
            .font(
                .callout
            )


            Text(
                "This is a one-time copy. Future changes to your local profile will not automatically change this Environment profile, and changes made here will not alter your local profile."
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
                    0
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


                            Text(
                                field.displayValue(
                                    from:
                                        profile
                                )
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
                            .truncationMode(
                                .middle
                            )
                        }
                    }
                    .toggleStyle(
                        .checkbox
                    )
                    .padding(
                        .vertical,
                        7
                    )


                    if
                        field.id
                            != fields
                                .last?
                                .id
                    {
                        Divider()
                    }
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

                if selected {
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


    private func importSelected() {

        errorMessage =
            store
                .importLocalProfileIntoCurrentEnvironmentPerson(
                    fields:
                        selectedFields
                )


        guard
            errorMessage
                == nil
        else {
            return
        }


        onImported()

        dismiss()
    }
}
