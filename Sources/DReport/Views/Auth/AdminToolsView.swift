import SwiftUI

struct AdminToolsView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var showingResetConfirmation =
        false

    var body: some View {
        if store.currentUserIsAdministrator {
            VStack(
                alignment: .leading,
                spacing: 24
            ) {
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text("Admin Tools")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(
                            "Administrative operations for this DReport installation."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                }

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    Text("Application")
                        .font(.headline)

                    Text(
                        "Reset DReport to its initial state and remove all locally stored application data and user accounts."
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )

                    Button(
                        role: .destructive
                    ) {
                        showingResetConfirmation =
                            true
                    } label: {
                        Label(
                            "Reset App…",
                            systemImage:
                                "arrow.counterclockwise.circle"
                        )
                    }
                }

                Spacer()
            }
            .padding(24)
            .frame(
                width: 520,
                height: 280
            )
            .sheet(
                isPresented:
                    $showingResetConfirmation
            ) {
                ResetApplicationView {
                    store.resetApplication()

                    showingResetConfirmation =
                        false

                    dismiss()
                }
            }
        } else {
            ContentUnavailableView(
                "Administrator Access Required",
                systemImage:
                    "lock"
            )
            .frame(
                width: 480,
                height: 260
            )
        }
    }
}

private struct ResetApplicationView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State
    private var confirmation = ""

    let onReset: () -> Void

    private var isConfirmed: Bool {
        confirmation
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .uppercased()
            == "RESET"
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Label(
                "Reset DReport",
                systemImage:
                    "exclamationmark.triangle.fill"
            )
            .font(.title2)
            .fontWeight(.semibold)

            Text(
                "This permanently removes all Tasks, Notes, Events, Themes, Organizations, Groups, People and User accounts, including the Administrator account."
            )

            Text(
                "The saved login session will also be removed. DReport will immediately return to the first-run Administrator setup."
            )
            .foregroundStyle(
                .secondary
            )

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(
                    "Type RESET to continue:"
                )
                .font(.callout)
                .fontWeight(.medium)

                TextField(
                    "RESET",
                    text:
                        $confirmation
                )
                .textFieldStyle(
                    .roundedBorder
                )
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button(
                    "Reset App",
                    role: .destructive
                ) {
                    onReset()
                }
                .disabled(
                    !isConfirmed
                )
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
