import SwiftUI
import AppKit


struct SidebarUserFooter: View {
    @EnvironmentObject
    private var store: DReportStore

    @State
    private var showingPopover =
        false

    @State
    private var showingAdminTools =
        false


    var body: some View {
        if
            let profile =
                store.localUserProfile
        {
            Button {
                showingPopover
                    .toggle()
            } label: {
                HStack(
                    spacing: 8
                ) {
                    SidebarLocalUserAvatar(
                        profile:
                            profile
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 1
                    ) {
                        Text(
                            profile
                                .displayName
                        )
                        .font(
                            .system(
                                size: 13,
                                weight:
                                    .regular
                            )
                        )
                        .foregroundStyle(
                            .primary
                        )
                        .lineLimit(1)

                        if
                            let environment =
                                store
                                    .activeWorkEnvironment
                        {
                            Text(
                                environment
                                    .name
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(1)
                        }
                    }

                    Spacer(
                        minLength: 0
                    )
                }
                .padding(
                    .horizontal,
                    4
                )
                .frame(
                    maxWidth:
                        .infinity,
                    minHeight:
                        38,
                    maxHeight:
                        38,
                    alignment:
                        .leading
                )
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .padding(
                .horizontal,
                12
            )
            .padding(
                .top,
                4
            )
            .padding(
                .bottom,
                8
            )
            .popover(
                isPresented:
                    $showingPopover,
                arrowEdge:
                    .bottom
            ) {
                popover(
                    profile
                )
            }
            .sheet(
                isPresented:
                    $showingAdminTools
            ) {
                AdminToolsView()
            }
        }
    }


    private func popover(
        _ profile:
            LocalUserProfile
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(
                profile.displayName
            )
            .fontWeight(
                .semibold
            )


            if
                let environment =
                    store
                        .activeWorkEnvironment
            {
                Divider()

                Text(
                    environment.name
                )
                .fontWeight(
                    .medium
                )

                if
                    let role =
                        store
                            .currentEnvironmentRole
                {
                    Text(
                        role.displayName
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }


            Divider()


            if
                store
                    .currentEnvironmentUserIsAdministrator
            {
                Button(
                    "Admin Tools…"
                ) {
                    showingPopover =
                        false

                    DispatchQueue
                        .main
                        .async {
                            showingAdminTools =
                                true
                        }
                }
                .buttonStyle(
                    .plain
                )

                Divider()
            }


            Button(
                "Switch Work Environment…"
            ) {
                showingPopover =
                    false

                store
                    .closeWorkEnvironment()
            }
            .buttonStyle(
                .plain
            )
        }
        .padding(12)
        .frame(
            width: 230,
            alignment:
                .leading
        )
    }
}


private struct SidebarLocalUserAvatar:
    View
{
    let profile:
        LocalUserProfile

    private let size:
        CGFloat = 24


    private var initials:
        String
    {
        let first =
            profile.firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .first

        let last =
            profile.lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .first

        let characters =
            [
                first,
                last
            ]
            .compactMap {
                $0
            }

        if characters.isEmpty {
            return "?"
        }

        return
            String(
                characters
            )
            .uppercased()
    }


    var body: some View {
        Group {
            if
                let data =
                    profile.avatarData,
                let image =
                    NSImage(
                        data:
                            data
                    )
            {
                Image(
                    nsImage:
                        image
                )
                .resizable()
                .scaledToFill()
                .frame(
                    width:
                        size,
                    height:
                        size
                )
                .clipShape(
                    Circle()
                )

            } else {
                ZStack {
                    Circle()
                        .fill(
                            Color
                                .accentColor
                                .opacity(
                                    0.15
                                )
                        )

                    Text(
                        initials
                    )
                    .font(
                        .system(
                            size: 9,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        Color
                            .accentColor
                    )
                }
                .frame(
                    width:
                        size,
                    height:
                        size
                )
            }
        }
        .frame(
            width:
                size,
            height:
                size
        )
        .clipShape(
            Circle()
        )
    }
}
