import SwiftUI


struct ProtectedDeleteButton: View {
    let objectType: String
    let objectName: String
    let warning: String

    let deleteAction:
        () -> String?

    let onDeleted:
        () -> Void

    @State
    private var showingConfirmation =
        false


    var body: some View {
        HStack {
            Spacer()

            Button {
                showingConfirmation =
                    true

            } label: {
                Text("Delete")
                    .font(
                        .callout
                            .weight(
                                .medium
                            )
                    )
                    .foregroundStyle(
                        Color.red
                    )
                    .padding(
                        .horizontal,
                        22
                    )
                    .padding(
                        .vertical,
                        8
                    )
                    .background(
                        RoundedRectangle(
                            cornerRadius:
                                8,
                            style:
                                .continuous
                        )
                        .fill(
                            Color.red
                                .opacity(
                                    0.035
                                )
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius:
                                8,
                            style:
                                .continuous
                        )
                        .stroke(
                            Color.red
                                .opacity(
                                    0.65
                                ),
                            lineWidth:
                                1
                        )
                    }
            }
            .buttonStyle(.plain)
            .help(
                "Delete \(objectType)"
            )

            Spacer()
        }
        .frame(
            maxWidth:
                760
        )
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .horizontal,
            28
        )
        .padding(
            .top,
            10
        )
        .padding(
            .bottom,
            14
        )
        .background(
            DReportStyle
                .contentBackground
        )
        .sheet(
            isPresented:
                $showingConfirmation
        ) {
            ProtectedDeleteConfirmationView(
                objectType:
                    objectType,
                objectName:
                    objectName,
                warning:
                    warning,
                deleteAction:
                    deleteAction,
                onDeleted:
                    onDeleted
            )
        }
    }
}


private struct ProtectedDeleteConfirmationView:
    View
{
    @Environment(\.dismiss)
    private var dismiss

    let objectType: String
    let objectName: String
    let warning: String

    let deleteAction:
        () -> String?

    let onDeleted:
        () -> Void

    @State
    private var confirmation =
        ""

    @State
    private var errorMessage:
        String?


    private var isConfirmed:
        Bool
    {
        confirmation
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .uppercased()
            == "DELETE"
    }


    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                18
        ) {
            Label(
                "Delete \(objectType)",
                systemImage:
                    "trash"
            )
            .font(.title2)
            .fontWeight(
                .semibold
            )
            .foregroundStyle(
                .red
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(objectName)
                    .fontWeight(
                        .semibold
                    )

                Text(warning)
                    .font(.callout)
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


            Divider()


            VStack(
                alignment:
                    .leading,
                spacing:
                    8
            ) {
                Text(
                    "This action cannot be undone."
                )
                .font(.callout)
                .fontWeight(
                    .medium
                )

                Text(
                    "Type DELETE to confirm:"
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )

                TextField(
                    "DELETE",
                    text:
                        $confirmation
                )
                .textFieldStyle(
                    .roundedBorder
                )
                .onSubmit {
                    if isConfirmed {
                        performDeletion()
                    }
                }
            }


            if let errorMessage {
                Label(
                    errorMessage,
                    systemImage:
                        "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(
                    .red
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
                    "Delete permanently",
                    role:
                        .destructive
                ) {
                    performDeletion()
                }
                .keyboardShortcut(
                    .defaultAction
                )
                .disabled(
                    !isConfirmed
                )
            }
        }
        .padding(24)
        .frame(
            width:
                470
        )
    }


    private func performDeletion() {
        errorMessage =
            nil

        guard isConfirmed else {
            return
        }

        if
            let deletionError =
                deleteAction()
        {
            errorMessage =
                deletionError

            return
        }

        onDeleted()

        dismiss()
    }
}
