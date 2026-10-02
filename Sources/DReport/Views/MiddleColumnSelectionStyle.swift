import SwiftUI


// ============================================================
// MARK: - Canonical middle-column selection
//
// Selection appearance is driven entirely by application state,
// never by temporary macOS List focus.
//
// This prevents the inactive-grey -> active-blue transition and
// gives browser rows one stable appearance whether selection
// came from:
//   • mouse click
//   • Back / Forward
//   • programmatic navigation
// ============================================================

struct MiddleColumnSelectionStyle:
    ViewModifier
{
    let isSelected:
        Bool

    let leadingExtension:
        CGFloat

    let trailingExtension:
        CGFloat


    func body(
        content:
            Content
    ) -> some View {
        content
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
            .foregroundStyle(
                isSelected
                ? Color.white
                : Color.primary
            )
            .tint(
                isSelected
                ? Color.white
                : Color.accentColor
            )
            .background {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius:
                            5,
                        style:
                            .continuous
                    )
                    .fill(
                        Color.accentColor
                    )
                    .padding(
                        .leading,
                        -leadingExtension
                    )
                    .padding(
                        .trailing,
                        -trailingExtension
                    )
                }
            }
    }
}


extension View {

    func middleColumnSelectionStyle(
        _ isSelected:
            Bool,
        leadingExtension:
            CGFloat = 0,
        trailingExtension:
            CGFloat = 4
    ) -> some View {
        modifier(
            MiddleColumnSelectionStyle(
                isSelected:
                    isSelected,
                leadingExtension:
                    leadingExtension,
                trailingExtension:
                    trailingExtension
            )
        )
    }
}
