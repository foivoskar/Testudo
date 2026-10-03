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
