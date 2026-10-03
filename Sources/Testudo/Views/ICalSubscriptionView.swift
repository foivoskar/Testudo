import SwiftUI


struct ICalSubscriptionView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var name =
        ""

    @State
    private var secretAddress =
        ""

    @State
    private var isConnecting =
        false

    @State
    private var errorMessage:
        String?


    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Label(
                "Connect iCal Calendar",
                systemImage:
                    "link.badge.plus"
            )
            .font(.title2)
            .fontWeight(
                .semibold
            )

            Text(
                "Paste the Secret address in iCal format. Events from this calendar are imported as read-only."
            )
            .font(.callout)
            .foregroundStyle(
                .secondary
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                TextField(
                    "Calendar name (optional)",
                    text: $name
                )

                SecureField(
                    "Secret address in iCal format",
                    text:
                        $secretAddress
                )
            }
            .textFieldStyle(
                .roundedBorder
            )

            Label(
                "The Secret address is stored in macOS Keychain, not in the Testudo data file.",
                systemImage:
                    "lock"
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
                    dismiss()
                }

                Button(
                    isConnecting
                    ? "Connecting…"
                    : "Connect"
                ) {
                    connect()
                }
                .keyboardShortcut(
                    .defaultAction
                )
                .disabled(
                    isConnecting
                    || secretAddress
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                )
            }
        }
        .padding(24)
        .frame(
            width: 520
        )
    }


    private func connect() {
        errorMessage =
            nil

        isConnecting =
            true

        Task {
            let result =
                await store
                    .connectICalSubscription(
                        name:
                            name,
                        secretAddress:
                            secretAddress
                    )

            isConnecting =
                false

            if
                let error =
                    result.error
            {
                errorMessage =
                    error

                return
            }

            dismiss()
        }
    }
}
