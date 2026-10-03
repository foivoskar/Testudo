import SwiftUI


struct AppleCalendarConnectionView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(\.dismiss)
    private var dismiss


    @State
    private var calendars:
        [AppleCalendarCandidate] = []

    @State
    private var selectedIdentifier:
        String?

    @State
    private var isLoading =
        true

    @State
    private var isConnecting =
        false

    @State
    private var errorMessage:
        String?


    private var connectedIdentifiers:
        Set<String>
    {
        Set(
            store.data.calendars
                .filter {
                    $0.sourceKind
                        == .appleEventKit
                }
                .compactMap(
                    \.externalID
                )
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
            HStack {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        4
                ) {
                    Text(
                        "Connect Apple Calendar"
                    )
                    .font(
                        .title2
                    )
                    .fontWeight(
                        .semibold
                    )

                    Text(
                        "Choose an iCloud or other calendar available in Apple Calendar on this Mac."
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


            Divider()


            Label(
                "Events imported from Apple Calendar are read-only in Testudo. Only Testudo relationships can be edited.",
                systemImage:
                    "lock"
            )
            .font(
                .callout
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                "The initial sync covers one year in the past through two years in the future."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            if isLoading {
                HStack {
                    Spacer()

                    ProgressView(
                        "Requesting Calendar access…"
                    )

                    Spacer()
                }
                .frame(
                    minHeight:
                        180
                )

            } else if calendars.isEmpty {
                ContentUnavailableView(
                    "No Calendars Available",
                    systemImage:
                        "calendar.badge.exclamationmark",
                    description:
                        Text(
                            "No Apple Calendar calendars are currently available to Testudo."
                        )
                )
                .frame(
                    minHeight:
                        180
                )

            } else {
                ScrollView {
                    LazyVStack(
                        alignment:
                            .leading,
                        spacing:
                            4
                    ) {
                        ForEach(
                            calendars
                        ) {
                            calendar in

                            let connected =
                                connectedIdentifiers
                                    .contains(
                                        calendar
                                            .identifier
                                    )

                            Button {
                                guard
                                    !connected
                                else {
                                    return
                                }

                                selectedIdentifier =
                                    calendar
                                        .identifier

                            } label: {
                                HStack(
                                    spacing:
                                        12
                                ) {
                                    Image(
                                        systemName:
                                            connected
                                            ? "checkmark.circle.fill"
                                            : (
                                                selectedIdentifier
                                                    == calendar
                                                        .identifier
                                                ? "largecircle.fill.circle"
                                                : "circle"
                                            )
                                    )
                                    .frame(
                                        width:
                                            20
                                    )

                                    VStack(
                                        alignment:
                                            .leading,
                                        spacing:
                                            2
                                    ) {
                                        Text(
                                            calendar.title
                                        )
                                        .fontWeight(
                                            .medium
                                        )

                                        if
                                            !calendar
                                                .sourceTitle
                                                .isEmpty
                                        {
                                            Text(
                                                calendar
                                                    .sourceTitle
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

                                    if connected {
                                        Text(
                                            "Connected"
                                        )
                                        .font(
                                            .caption
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                    }
                                }
                                .padding(
                                    .horizontal,
                                    10
                                )
                                .padding(
                                    .vertical,
                                    9
                                )
                                .contentShape(
                                    Rectangle()
                                )
                            }
                            .buttonStyle(
                                .plain
                            )
                            .disabled(
                                connected
                            )
                        }
                    }
                }
                .frame(
                    minHeight:
                        200,
                    maxHeight:
                        320
                )
            }


            if
                let errorMessage
            {
                Label(
                    errorMessage,
                    systemImage:
                        "exclamationmark.triangle"
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
                Spacer()

                Button(
                    "Cancel"
                ) {
                    dismiss()
                }

                Button {
                    connectSelectedCalendar()
                } label: {
                    if isConnecting {
                        ProgressView()
                            .controlSize(
                                .small
                            )
                    } else {
                        Text(
                            "Connect"
                        )
                    }
                }
                .buttonStyle(
                    .borderedProminent
                )
                .keyboardShortcut(
                    .defaultAction
                )
                .disabled(
                    selectedIdentifier
                        == nil
                    || isLoading
                    || isConnecting
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
        .frame(
            minHeight:
                440
        )
        .task {
            await loadCalendars()
        }
    }


    @MainActor
    private func loadCalendars()
        async
    {
        isLoading =
            true

        errorMessage =
            nil

        do {
            calendars =
                try await
                    AppleCalendarEventKitBridge
                        .shared
                        .availableCalendars()

        } catch {
            errorMessage =
                error
                    .localizedDescription

            calendars =
                []
        }

        isLoading =
            false
    }


    private func connectSelectedCalendar()
    {
        guard
            let selectedIdentifier
        else {
            return
        }

        isConnecting =
            true

        errorMessage =
            nil

        Task {
            let result =
                await store
                    .connectAppleCalendar(
                        calendarIdentifier:
                            selectedIdentifier
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
