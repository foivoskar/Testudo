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

    @FocusState
    private var focusedField:
        LoginField?


    private enum LoginField {
        case username
        case password
    }


    var body: some View {
        ZStack {
            Color(
                nsColor:
                    .windowBackgroundColor
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                loginCard

                Spacer()
            }
            .padding(48)
        }
        .onAppear {
            focusedField =
                .username
        }
    }


    private var loginCard:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 26
        ) {
            header

            VStack(
                spacing: 16
            ) {
                usernameField
                passwordField
            }

            Toggle(
                "Stay signed in",
                isOn:
                    $staySignedIn
            )
            .toggleStyle(
                .checkbox
            )
            .font(.callout)

            if let errorMessage {
                errorView(
                    errorMessage
                )
            }

            Button {
                signIn()
            } label: {
                Text("Sign In")
                    .fontWeight(
                        .semibold
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 30
                    )
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
        .padding(
            .horizontal,
            34
        )
        .padding(
            .top,
            32
        )
        .padding(
            .bottom,
            34
        )
        .frame(
            width: 440
        )
        .background(
            .regularMaterial,
            in:
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.07),
                lineWidth: 1
            )
        }
        .shadow(
            color:
                Color.black
                    .opacity(0.10),
            radius: 24,
            x: 0,
            y: 12
        )
    }


    private var header:
        some View
    {
        HStack(
            alignment: .center,
            spacing: 15
        ) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(
                    Color.accentColor
                        .opacity(0.12)
                )

                Image(
                    systemName:
                        "doc.text"
                )
                .font(
                    .system(
                        size: 22,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.accentColor
                )
            }
            .frame(
                width: 48,
                height: 48
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text("DReport")
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold
                        )
                    )

                Text(
                    "Sign in to continue."
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    private var usernameField:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            Text("Username")
                .font(
                    .caption
                        .weight(.medium)
                )
                .foregroundStyle(
                    .secondary
                )

            TextField(
                "Enter your username",
                text:
                    $username
            )
            .textContentType(
                .username
            )
            .textFieldStyle(
                .plain
            )
            .focused(
                $focusedField,
                equals:
                    .username
            )
            .onSubmit {
                focusedField =
                    .password
            }
            .padding(
                .horizontal,
                13
            )
            .frame(
                height: 42
            )
            .background(
                fieldBackground
            )
            .overlay {
                fieldBorder(
                    active:
                        focusedField
                            == .username
                )
            }
        }
    }


    private var passwordField:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            Text("Password")
                .font(
                    .caption
                        .weight(.medium)
                )
                .foregroundStyle(
                    .secondary
                )

            SecureField(
                "Enter your password",
                text:
                    $password
            )
            .textContentType(
                .password
            )
            .textFieldStyle(
                .plain
            )
            .focused(
                $focusedField,
                equals:
                    .password
            )
            .onSubmit {
                signIn()
            }
            .padding(
                .horizontal,
                13
            )
            .frame(
                height: 42
            )
            .background(
                fieldBackground
            )
            .overlay {
                fieldBorder(
                    active:
                        focusedField
                            == .password
                )
            }
        }
    }


    private var fieldBackground:
        some View
    {
        RoundedRectangle(
            cornerRadius: 8,
            style: .continuous
        )
        .fill(
            Color(
                nsColor:
                    .textBackgroundColor
            )
        )
    }


    @ViewBuilder
    private func fieldBorder(
        active: Bool
    ) -> some View {
        RoundedRectangle(
            cornerRadius: 8,
            style: .continuous
        )
        .stroke(
            active
            ? Color.accentColor
                .opacity(0.75)
            : Color.primary
                .opacity(0.12),
            lineWidth:
                active
                ? 1.5
                : 1
        )
    }


    private func errorView(
        _ message: String
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 8
        ) {
            Image(
                systemName:
                    "exclamationmark.circle.fill"
            )
            .foregroundStyle(
                .red
            )

            Text(message)
                .font(.callout)
                .foregroundStyle(
                    .red
                )

            Spacer()
        }
        .padding(11)
        .background(
            Color.red
                .opacity(0.07),
            in:
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
        )
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
