import SwiftUI


// ============================================================
// MARK: - Canonical middle-column selection
//
// Selection appearance is driven entirely by application state,
// never by temporary macOS List focus.
//
// The selected background deliberately fills the complete
// visual row:
//
//   • square edges
//   • reaches the horizontal column edges
//   • reaches the row boundaries / separators
//
// listRowBackground gives direct List rows their exact cell
// background. The extended Rectangle also covers hierarchical
// labels inside DisclosureGroup rows, where the selection
// modifier lives inside the row label rather than directly on
// the List row itself.
//
// Content positioning is not changed.
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


    // Canonical Testudo selection blue:
    // RGB(52, 120, 246) = #3478F6
    private let selectionColor =
        Color(
            red:
                52.0 / 255.0,
            green:
                120.0 / 255.0,
            blue:
                246.0 / 255.0
        )


    private let columnEdgeExtension:
        CGFloat = 24

    private let verticalRowExtension:
        CGFloat = 9


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
                    Rectangle()
                        .fill(
                            selectionColor
                        )
                        .padding(
                            .leading,
                            -(
                                leadingExtension
                                + columnEdgeExtension
                            )
                        )
                        .padding(
                            .trailing,
                            -(
                                trailingExtension
                                + columnEdgeExtension
                            )
                        )
                        .padding(
                            .vertical,
                            -verticalRowExtension
                        )
                }
            }
            .listRowBackground(
                isSelected
                ? selectionColor
                : Color.clear
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
}
