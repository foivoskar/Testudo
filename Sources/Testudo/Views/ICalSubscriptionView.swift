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


// ============================================================
// MARK: - Restore Secret Address for existing subscription
// ============================================================

struct ICalSecretRecoveryView:
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
    private var selectedCalendarID:
        UUID?


    @State
    private var secretAddress =
        ""


    @State
    private var isRestoring =
        false


    @State
    private var errorMessage:
        String?


    init(
        calendarID:
            UUID? = nil
    ) {
        _selectedCalendarID =
            State(
                initialValue:
                    calendarID
            )
    }


    private var iCalCalendars:
        [TestudoCalendar]
    {
        store
            .data
            .calendars
            .filter {
                $0.sourceKind
                    == .iCalSubscription
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }


    private var selectedCalendar:
        TestudoCalendar?
    {
        guard
            let selectedCalendarID
        else {
            return
                nil
        }


        return
            iCalCalendars
                .first {
                    $0.id
                        == selectedCalendarID
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
            Label(
                "Restore iCal Secret Address",
                systemImage:
                    "key.horizontal"
            )
            .font(
                .title2
            )
            .fontWeight(
                .semibold
            )


            Text(
                "Restore the private iCal address for an existing calendar on this Mac. The calendar, imported events and Testudo relationships keep their existing identities."
            )
            .font(
                .callout
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
                iCalCalendars
                    .isEmpty
            {
                ContentUnavailableView(
                    "No iCal Subscriptions",
                    systemImage:
                        "calendar.badge.exclamationmark",
                    description:
                        Text(
                            "There is no existing iCal subscription whose Secret address can be restored."
                        )
                )

            } else {

                if
                    iCalCalendars
                        .count
                        == 1,
                    let onlyCalendar =
                        iCalCalendars
                            .first
                {
                    LabeledContent(
                        "Calendar"
                    ) {
                        Text(
                            onlyCalendar
                                .name
                        )
                    }

                } else {

                    Picker(
                        "Calendar",
                        selection:
                            $selectedCalendarID
                    ) {
                        ForEach(
                            iCalCalendars
                        ) {
                            calendar in

                            Text(
                                calendar
                                    .name
                            )
                            .tag(
                                Optional(
                                    calendar.id
                                )
                            )
                        }
                    }
                    .pickerStyle(
                        .menu
                    )
                }


                SecureField(
                    "Secret address in iCal format",
                    text:
                        $secretAddress
                )
                .textFieldStyle(
                    .roundedBorder
                )


                Label(
                    "The Secret address is stored only in this Mac's Keychain. It is not written into the shared .testudoenv package.",
                    systemImage:
                        "lock"
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
                .fixedSize(
                    horizontal:
                        false,
                    vertical:
                        true
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
                    isRestoring
                    ? "Restoring…"
                    : "Restore and Sync"
                ) {
                    restore()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .keyboardShortcut(
                    .defaultAction
                )
                .disabled(
                    isRestoring
                    || selectedCalendar
                        == nil
                    || secretAddress
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                )
            }
        }
        .padding(
            24
        )
        .frame(
            width:
                560
        )
        .onAppear {
            if
                selectedCalendarID
                    == nil
            {
                selectedCalendarID =
                    iCalCalendars
                        .first?
                        .id
            }
        }
    }


    private func restore() {
        guard
            let selectedCalendarID
        else {
            return
        }


        errorMessage =
            nil

        isRestoring =
            true


        Task {
            let error =
                await store
                    .restoreICalSecretAddress(
                        id:
                            selectedCalendarID,
                        secretAddress:
                            secretAddress
                    )


            isRestoring =
                false


            if
                let error
            {
                errorMessage =
                    error

                return
            }


            dismiss()
        }
    }
}
