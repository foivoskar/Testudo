import SwiftUI


// ============================================================
// MARK: - Task status visual language
//
// Navigation/sidebar icons remain unchanged.
//
// These colors are used only for task-state indicators in
// work content and task-status selectors.
// ============================================================

extension TaskStatus {

    var testudoStatusIconColor:
        Color
    {
        switch self {

        case .todo:
            return .red

        case .inProgress:
            return .orange

        case .completed:
            return .green

        case .closed:
            return .secondary
        }
    }
}



// ============================================================
// MARK: - Task-status SF Symbol tint
//
// This modifier is intentionally symbol-based so it can be
// safely applied to the whole Work detail pane.
//
// Non-task symbols such as note, event, pencil, chevrons, plus,
// etc. are returned completely unchanged.
// ============================================================

extension View {

    @ViewBuilder
    func testudoTaskStatusSymbolColor(
        _ systemName:
            String
    ) -> some View {

        switch systemName {

        case "circle":
            self
                .foregroundStyle(
                    Color.red
                )

        case "clock":
            self
                .foregroundStyle(
                    Color.orange
                )

        case "checkmark.circle":
            self
                .foregroundStyle(
                    Color.green
                )

        default:
            self
        }
    }
}
