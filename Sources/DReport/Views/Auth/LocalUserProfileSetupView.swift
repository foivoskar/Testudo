import SwiftUI


struct LocalUserProfileSetupView: View {
    @EnvironmentObject
    private var store: DReportStore

    @State
    private var draft =
        LocalUserProfile()

    @State
    private var errorMessage:
        String?


    var body: some View {
        ZStack {
            Color(
                nsColor:
                    .windowBackgroundColor
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {
                    header

                    profileCard
                }
                .frame(
                    maxWidth: 680
                )
                .padding(
                    .horizontal,
                    44
                )
                .padding(
                    .vertical,
                    44
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
        }
    }


    private var header:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(
                "Create Your Profile"
            )
            .font(.largeTitle)
            .fontWeight(
                .semibold
            )

            Text(
                "This profile belongs to you and to this Testudo installation. After saving it, you will create an application password. Your Testudo login remains independent of all Work Environment accounts."
            )
            .foregroundStyle(
                .secondary
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }


    private var profileCard:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            AvatarPicker(
                avatarData:
                    $draft.avatarData
            )


            section(
                "Name"
            ) {
                HStack(
                    spacing: 12
                ) {
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
                }

                TextField(
                    "Preferred name",
                    text:
                        $draft.preferredName
                )
            }


            section(
                "Professional Information"
            ) {
                HStack(
                    spacing: 12
                ) {
                    TextField(
                        "Academic title",
                        text:
                            optionalBinding(
                                \.academicTitle
                            )
                    )

                    TextField(
                        "Job title",
                        text:
                            $draft.jobTitle
                    )
                }

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
            }


            section(
                "Professional Identity"
            ) {
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

                HStack(
                    spacing: 12
                ) {
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
                }
            }


            section(
                "Location"
            ) {
                TextField(
                    "Professional address",
                    text:
                        optionalBinding(
                            \.professionalAddress
                        )
                )

                HStack(
                    spacing: 12
                ) {
                    TextField(
                        "City",
                        text:
                            optionalBinding(
                                \.city
                            )
                    )

                    TextField(
                        "Postal code",
                        text:
                            optionalBinding(
                                \.postalCode
                            )
                    )

                    TextField(
                        "Country",
                        text:
                            optionalBinding(
                                \.country
                            )
                    )
                }
            }


            section(
                "Additional Information"
            ) {
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

                TextField(
                    "Notes",
                    text:
                        $draft.notes,
                    axis:
                        .vertical
                )
                .lineLimit(
                    3...8
                )
            }


            if let errorMessage {
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
                    "Continue"
                ) {
                    save()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(
                    .large
                )
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .textFieldStyle(
            .roundedBorder
        )
        .padding(28)
        .background(
            .regularMaterial,
            in:
                RoundedRectangle(
                    cornerRadius: 16,
                    style:
                        .continuous
                )
        )
    }


    @ViewBuilder
    private func section<
        Content: View
    >(
        _ title: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(title)
                .font(
                    .headline
                )

            content()
        }
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
                ] ?? ""
            },
            set: {
                draft[
                    keyPath:
                        keyPath
                ] =
                    $0.isEmpty
                    ? nil
                    : $0
            }
        )
    }


    private func save() {
        errorMessage =
            store
                .saveLocalUserProfile(
                    draft
                )
    }
}
