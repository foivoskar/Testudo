import SwiftUI
import AppKit

struct UserAvatarView: View {
    let user: DReportUser

    var size: CGFloat = 30

    var body: some View {
        Group {
            if
                let data =
                    user.avatarData,
                let image =
                    NSImage(
                        data: data
                    )
            {
                Image(
                    nsImage: image
                )
                .resizable()
                .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(
                            Color.accentColor
                                .opacity(0.16)
                        )

                    Text(user.initials)
                        .font(
                            .system(
                                size:
                                    max(
                                        11,
                                        size * 0.42
                                    ),
                                weight:
                                    .semibold
                            )
                        )
                        .foregroundStyle(
                            Color.accentColor
                        )
                }
            }
        }
        .frame(
            width: size,
            height: size
        )
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(
                    Color.primary
                        .opacity(0.08),
                    lineWidth: 0.5
                )
        }
    }
}
