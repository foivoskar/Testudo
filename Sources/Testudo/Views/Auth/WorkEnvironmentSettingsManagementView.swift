import SwiftUI


// ============================================================
// MARK: - Work Environment Settings
//
// This manages only this application's local registry.
//
// Removing an Environment here NEVER deletes, moves or modifies
// its .testudoenv package.
// ============================================================

struct WorkEnvironmentSettingsManagementView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @State
    private var environmentPendingRemoval:
        WorkEnvironment?

    @State
    private var errorMessage:
        String?


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {

            Text(
                "These are the Work Environments registered with this installation of Testudo."
            )
            .font(
                .callout
            )


            Text(
                "Removing a normal Work Environment here only forgets it on this Mac; its .testudoenv package remains untouched. Testudo-managed Demo Environments are disposable and are permanently deleted when removed."
            )
            .font(
                .callout
            )
            .foregroundStyle(
                .secondary
            )


            if
                store
                    .workEnvironments
                    .isEmpty
            {
                Text(
                    "No Work Environments are currently registered."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        0
                ) {
                    ForEach(
                        store.workEnvironments
                    ) {
                        environment in

                        environmentRow(
                            environment
                        )

                        if
                            environment.id
                                != store
                                    .workEnvironments
                                    .last?
                                    .id
                        {
                            Divider()
                        }
                    }
                }
            }


            if
                let errorMessage
            {
                Label(
                    errorMessage,
                    systemImage:
                        "exclamationmark.circle"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .red
                )
            }
        }
        .alert(
            item:
                $environmentPendingRemoval
        ) {
            environment in

            let isManagedDemo =
                store
                    .isManagedDemoEnvironment(
                        id:
                            environment.id
                    )


            return
                Alert(
                    title:
                        Text(
                            isManagedDemo
                            ? "Delete Demo Environment?"
                            : "Remove Work Environment?"
                        ),
                    message:
                        Text(
                            isManagedDemo
                            ? "“\(environment.name)” is a disposable Testudo Demo Environment. Its local .testudoenv package and Demo data will be permanently deleted from this Mac."
                            : "“\(environment.name)” will be removed only from this installation of Testudo. Its .testudoenv package and all Environment data will remain untouched at its current storage location."
                        ),
                    primaryButton:
                        .destructive(
                            Text(
                                isManagedDemo
                                ? "Delete Demo"
                                : "Remove from Testudo"
                            )
                        ) {
                            remove(
                                environment
                            )
                        },
                    secondaryButton:
                        .cancel()
                )
        }
    }


    private func environmentRow(
        _ environment:
            WorkEnvironment
    ) -> some View {

        HStack(
            alignment:
                .center,
            spacing:
                14
        ) {

            Image(
                systemName:
                    "shippingbox"
            )
            .font(
                .system(
                    size:
                        17
                )
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width:
                    24
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {

                HStack(
                    spacing:
                        8
                ) {

                    Text(
                        environment.name
                    )
                    .fontWeight(
                        .medium
                    )


                    if
                        environment.id
                            == store
                                .activeEnvironmentID
                    {
                        Text(
                            "Current"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }


                if
                    let path =
                        environment
                            .storage?
                            .path
                {
                    Text(
                        path
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(
                        1
                    )
                    .truncationMode(
                        .middle
                    )
                    .textSelection(
                        .enabled
                    )
                }
            }


            Spacer()


            Button(
                role:
                    .destructive
            ) {
                errorMessage =
                    nil

                environmentPendingRemoval =
                    environment

            } label: {
                Text(
                    "Remove Environment…"
                )
            }
            .buttonStyle(
                .bordered
            )
        }
        .padding(
            .vertical,
            10
        )
    }


    private func remove(
        _ environment:
            WorkEnvironment
    ) {

        errorMessage =
            store
                .unregisterWorkEnvironment(
                    id:
                        environment.id
                )

        environmentPendingRemoval =
            nil
    }
}
