import SwiftUI


struct LocalUserProfileEditorView: View {
    @EnvironmentObject
    private var store: TestudoStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var draft:
        LocalUserProfile

    @State
    private var errorMessage:
        String?


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


    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        "My Profile"
                    )
                    .font(.title2)
                    .fontWeight(
                        .semibold
                    )

                    Text(
                        "This profile belongs to this application installation, not to a Work Environment."
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()
            }


            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    AvatarPicker(
                        avatarData:
                            $draft.avatarData
                    )

                    Group {
                        TextField(
                            "First name",
                            text:
                                $draft.firstName
                        )

                        TextField(
                            "Middle name",
                            text:
                                $draft.middleName
                        )

                        TextField(
                            "Last name",
                            text:
                                $draft.lastName
                        )

                        TextField(
                            "Preferred name",
                            text:
                                $draft.preferredName
                        )

                        TextField(
                            "Job title",
                            text:
                                $draft.jobTitle
                        )

                        TextField(
                            "Professional email",
                            text:
                                $draft.professionalEmail
                        )

                        TextField(
                            "Professional phone",
                            text:
                                $draft.professionalPhone
                        )

                        TextField(
                            "Office",
                            text:
                                $draft.office
                        )

                        TextField(
                            "Website",
                            text:
                                $draft.website
                        )

                        TextField(
                            "ORCID",
                            text:
                                $draft.orcid
                        )

                        TextField(
                            "LinkedIn",
                            text:
                                $draft.linkedIn
                        )

                        TextField(
                            "GitHub",
                            text:
                                $draft.github
                        )

                        TextField(
                            "Professional fields",
                            text:
                                $draft.professionalFields
                        )

                        TextField(
                            "Responsibilities",
                            text:
                                $draft.responsibilities
                        )
                    }
                    .textFieldStyle(
                        .roundedBorder
                    )


                    TextField(
                        "Notes",
                        text:
                            $draft.notes,
                        axis:
                            .vertical
                    )
                    .textFieldStyle(
                        .roundedBorder
                    )
                    .lineLimit(
                        3...8
                    )


                    if let errorMessage {
                        Text(
                            errorMessage
                        )
                        .font(.callout)
                        .foregroundStyle(
                            .red
                        )
                    }
                }
            }


            Divider()

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
        }
        .padding(24)
        .frame(
            width: 560,
            height: 680
        )
    }


    private func save() {
        errorMessage =
            store.saveLocalUserProfile(
                draft
            )

        if errorMessage == nil {
            dismiss()
        }
    }
}
