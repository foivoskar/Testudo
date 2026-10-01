import SwiftUI

struct CreateAdministratorView: View {
    @EnvironmentObject
    private var store: DReportStore

    @State
    private var firstName = ""

    @State
    private var lastName = ""

    @State
    private var username = ""

    @State
    private var password = ""

    @State
    private var passwordConfirmation = ""

    @State
    private var avatarData: Data?

    @State
    private var staySignedIn = true

    @State
    private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(
                nsColor:
                    .textBackgroundColor
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        Text("Set up DReport")
                            .font(.title)
                            .fontWeight(.semibold)

                        Text(
                            "Create the administrator account for this installation."
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

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
                    .textContentType(
                        .username
                    )

                    SecureField(
                        "Password",
                        text:
                            $password
                    )
                    .textContentType(
                        .newPassword
                    )

                    SecureField(
                        "Confirm password",
                        text:
                            $passwordConfirmation
                    )
                    .textContentType(
                        .newPassword
                    )

                    Toggle(
                        "Stay signed in",
                        isOn:
                            $staySignedIn
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(
                                .red
                            )
                    }

                    Button(
                        "Create Administrator Account"
                    ) {
                        createAccount()
                    }
                    .keyboardShortcut(
                        .defaultAction
                    )
                    .buttonStyle(
                        .borderedProminent
                    )
                    .controlSize(.large)
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .trailing
                    )
                }
                .padding(30)
                .frame(width: 500)
                .background(
                    .regularMaterial,
                    in:
                        RoundedRectangle(
                            cornerRadius: 14
                        )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 14
                    )
                    .stroke(
                        Color.primary
                            .opacity(0.08)
                    )
                }

                Spacer()
            }
            .padding(40)
        }
    }

    private func createAccount() {
        guard
            password
                == passwordConfirmation
        else {
            errorMessage =
                "The passwords do not match."
            return
        }

        errorMessage =
            store
                .createInitialAdministrator(
                    username:
                        username,
                    firstName:
                        firstName,
                    lastName:
                        lastName,
                    password:
                        password,
                    avatarData:
                        avatarData,
                    staySignedIn:
                        staySignedIn
                )
    }
}
