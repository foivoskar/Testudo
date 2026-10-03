import SwiftUI


// ============================================================
// MARK: - Canonical middle-column selection
//
// The selected background fills the real List row:
//
//   • full row width
//   • full row height
//   • subtle 7 pt rounded corners
//   • canonical #3478F6 blue
//
// DisclosureGroup rows need the same background attached to
// the DisclosureGroup itself, because their label is only an
// internal part of the List row.
// ============================================================


private let middleColumnSelectionColor =
    Color(
        red:
            52.0 / 255.0,
        green:
            120.0 / 255.0,
        blue:
            246.0 / 255.0
    )


private let middleColumnSelectionCornerRadius:
    CGFloat = 7


private struct MiddleColumnSelectionBackground:
    View
{
    let isSelected:
        Bool


    var body:
        some View
    {
        Group {
            if isSelected {
                RoundedRectangle(
                    cornerRadius:
                        middleColumnSelectionCornerRadius,
                    style:
                        .continuous
                )
                .fill(
                    middleColumnSelectionColor
                )

            } else {
                Color.clear
            }
        }
    }
}


// ============================================================
// MARK: - Normal row / row-label styling
// ============================================================

struct MiddleColumnSelectionStyle:
    ViewModifier
{
    let isSelected:
        Bool

    /*
     Retained for source compatibility with the existing
     call-sites. Background geometry is now controlled by the
     real List row rather than oversized padding extensions.
    */
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
            .listRowBackground(
                MiddleColumnSelectionBackground(
                    isSelected:
                        isSelected
                )
            )
    }
}


// ============================================================
// MARK: - DisclosureGroup row styling
//
// Theme rows and expandable Work rows are DisclosureGroups.
// Their selection background must live on the DisclosureGroup
// itself, not only on its label.
// ============================================================

private struct MiddleColumnHierarchyRowSelectionStyle:
    ViewModifier
{
    let isSelected:
        Bool


    func body(
        content:
            Content
    ) -> some View {
        content
            .tint(
                isSelected
                ? Color.white
                : Color.accentColor
            )
            .listRowBackground(
                MiddleColumnSelectionBackground(
                    isSelected:
                        isSelected
                )
            )
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


    func middleColumnHierarchyRowSelectionStyle(
        _ isSelected:
            Bool
    ) -> some View {
        modifier(
            MiddleColumnHierarchyRowSelectionStyle(
                isSelected:
                    isSelected
            )
        )
    }
}
