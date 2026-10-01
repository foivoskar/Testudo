import SwiftUI
import AppKit

struct SidebarUserFooter: View {
    @EnvironmentObject
    private var store: DReportStore

    @State
    private var showingAccountPopover = false

    @State
    private var showingUsers = false

    var body: some View {
        if let user = store.currentUser {
            Button {
                showingAccountPopover.toggle()
            } label: {
                HStack(spacing: 6) {
                    SidebarMiniAvatar(
                        user: user
                    )

                    Text(user.displayName)
                        .font(
                            .system(
                                size: 12,
                                weight: .regular
                            )
                        )
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 30,
                    maxHeight: 30,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        }
    }

    private func accountPopover(
        user: DReportUser
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(user.displayName)
                .fontWeight(.semibold)

            Text("@\(user.username)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.currentUserIsAdministrator {
                Divider()

                Button("Users…") {
                    showingAccountPopover = false

                    DispatchQueue.main.async {
                        showingUsers = true
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button("Sign Out") {
                showingAccountPopover = false
                store.signOut()
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(
            width: 180,
            alignment: .leading
        )
    }
}

private struct SidebarMiniAvatar: View {
    let user: DReportUser

    private let size: CGFloat = 22

    var body: some View {
        Group {
            if let image = thumbnail {
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
                                size: 9,
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

    private var thumbnail: NSImage? {
        guard
            let data = user.avatarData,
            let source = NSImage(data: data)
        else {
            return nil
        }

        let targetSize =
            NSSize(
                width: 36,
                height: 36
            )

        let target =
            NSImage(
                size: targetSize
            )

        target.lockFocus()

        NSGraphicsContext.current?
            .imageInterpolation = .high

        let sourceSize =
            source.size

        let sourceAspect =
            sourceSize.width
            / sourceSize.height

        let targetAspect =
            targetSize.width
            / targetSize.height

        var sourceRect =
            NSRect(
                origin: .zero,
                size: sourceSize
            )

        if sourceAspect > targetAspect {
            let newWidth =
                sourceSize.height
                * targetAspect

            sourceRect.origin.x =
                (
                    sourceSize.width
                    - newWidth
                ) / 2

            sourceRect.size.width =
                newWidth
        } else {
            let newHeight =
                sourceSize.width
                / targetAspect

            sourceRect.origin.y =
                (
                    sourceSize.height
                    - newHeight
                ) / 2

            sourceRect.size.height =
                newHeight
        }

        source.draw(
            in: NSRect(
                origin: .zero,
                size: targetSize
            ),
            from: sourceRect,
            operation: .copy,
            fraction: 1
        )

        target.unlockFocus()

        return target
    }
}
