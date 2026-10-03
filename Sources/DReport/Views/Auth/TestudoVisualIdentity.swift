import SwiftUI
import AppKit


// ============================================================
// MARK: - Testudo brand icon
// ============================================================

struct TestudoBrandIcon:
    View
{
    var size:
        CGFloat

    var showsBackground:
        Bool = false


    var body:
        some View
    {
        ZStack {

            if showsBackground {

                RoundedRectangle(
                    cornerRadius:
                        size * 0.26,
                    style:
                        .continuous
                )
                .fill(
                    Color
                        .accentColor
                        .opacity(
                            0.08
                        )
                )
            }


            Group {

                if
                    let url =
                        Bundle
                            .main
                            .url(
                                forResource:
                                    "testudo_icon_blue",
                                withExtension:
                                    "png"
                            ),
                    let image =
                        NSImage(
                            contentsOf:
                                url
                        )
                {
                    Image(
                        nsImage:
                            image
                    )
                    .resizable()
                    .scaledToFit()

                } else {

                    Image(
                        systemName:
                            "tortoise.fill"
                    )
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(
                        Color
                            .accentColor
                    )
                }
            }
            .padding(
                showsBackground
                ? size * 0.16
                : 0
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


// ============================================================
// MARK: - Testudo local-user avatar
// ============================================================

struct TestudoUserAvatarView:
    View
{
    let profile:
        LocalUserProfile

    var size:
        CGFloat


    private var initials:
        String
    {
        let first =
            profile
                .firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .first

        let last =
            profile
                .lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .first


        let characters =
            [
                first,
                last,
            ]
            .compactMap {
                $0
            }


        guard
            !characters.isEmpty
        else {
            return "?"
        }


        return
            String(
                characters
            )
            .uppercased()
    }


    var body:
        some View
    {
        ZStack {

            Circle()
                .fill(
                    Color
                        .accentColor
                        .opacity(
                            0.10
                        )
                )


            if
                let avatarData =
                    profile
                        .avatarData,
                let image =
                    NSImage(
                        data:
                            avatarData
                    )
            {
                Image(
                    nsImage:
                        image
                )
                .resizable()
                .scaledToFill()

            } else {

                Text(
                    initials
                )
                .font(
                    .system(
                        size:
                            size * 0.30,
                        weight:
                            .semibold,
                        design:
                            .rounded
                    )
                )
                .foregroundStyle(
                    Color
                        .accentColor
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
        .overlay {

            Circle()
                .stroke(
                    Color
                        .primary
                        .opacity(
                            0.08
                        ),
                    lineWidth:
                        1
                )
        }
        .shadow(
            color:
                Color
                    .black
                    .opacity(
                        0.08
                    ),
            radius:
                size * 0.10,
            y:
                size * 0.04
        )
    }
}
