import SwiftUI
import AppKit

struct SidebarUserFooter: View {
    @EnvironmentObject
    private var store: DReportStore

    @State
    private var showingAccountPopover = false

    @State
    private var showingUsers = false

    @State
    private var showingAdminTools = false

    var body: some View {
        if let user = store.currentUser {
            Button {
                showingAccountPopover.toggle()
            } label: {
                HStack(spacing: 8) {
                    SidebarMiniAvatar(
                        user: user
                    )

                    Text(user.displayName)
                        .font(
                            .system(
                                size: 13,
                                weight: .regular
                            )
                        )
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 34,
                    maxHeight: 34,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .popover(
                isPresented:
                    $showingAccountPopover,
                arrowEdge: .bottom
            ) {
                accountPopover(
                    user: user
                )
            }
            .sheet(
                isPresented:
                    $showingUsers
            ) {
                UserManagementView()
            }
            .sheet(
                isPresented:
                    $showingAdminTools
            ) {
                AdminToolsView()
            }
        }
    }

    private func accountPopover(
        user: DReportUser
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(user.displayName)
                    .fontWeight(.semibold)

                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                if store.currentUserIsAdministrator {
                    Text(
                        user.role.displayName
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .tertiary
                    )
                }
            }

            if store.currentUserIsAdministrator {
                Button("Users…") {
                    showingAccountPopover = false

                    DispatchQueue.main.async {
                        showingUsers = true
                    }
                }
                .buttonStyle(.plain)

                Button("Admin Tools…") {
                    showingAccountPopover = false

                    DispatchQueue.main.async {
                        showingAdminTools = true
                    }
                }
                .buttonStyle(.plain)
            }

            Button("Sign Out") {
                showingAccountPopover = false
                store.signOut()
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(
            width: 200,
            alignment: .leading
        )
    }
}

private struct SidebarMiniAvatar: View {
    let user: DReportUser

    private let size: CGFloat = 24

    var body: some View {
        Group {
            if
                let data = user.avatarData,
                let image = NSImage(
                    data: data
                )
            {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: size,
                        height: size
                    )
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(
                            Color.accentColor
                                .opacity(0.15)
                        )

                    Text(user.initials)
                        .font(
                            .system(
                                size: 10,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            Color.accentColor
                        )
                }
                .frame(
                    width: size,
                    height: size
                )
            }
        }
        .frame(
            width: size,
            height: size
        )
        .clipShape(Circle())
    }
}
