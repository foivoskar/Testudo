import SwiftUI

struct LoginView: View {
    @EnvironmentObject
    private var store: DReportStore

    @State
    private var username = ""

    @State
    private var password = ""

    @State
    private var staySignedIn = false

    @State
    private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(
                nsColor:
                    .textBackgroundColor
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        Text("DReport")
                            .font(.title)
                            .fontWeight(.semibold)

                        Text(
                            "Sign in to continue."
                        )
                        .foregroundStyle(
                            .secondary
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
                        .password
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

                    HStack {
                        Spacer()

                        Button("Sign In") {
                            signIn()
                        }
                        .keyboardShortcut(
                            .defaultAction
                        )
                        .buttonStyle(
                            .borderedProminent
                        )
                        .controlSize(.large)
                    }
                }
                .padding(30)
                .frame(width: 430)
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

    private func signIn() {
        errorMessage =
            store.login(
                username:
                    username,
                password:
                    password,
                staySignedIn:
                    staySignedIn
            )
    }
}
