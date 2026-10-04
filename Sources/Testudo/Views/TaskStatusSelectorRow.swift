import SwiftUI


struct TaskStatusSelectorRow:
    View
{
    let status:
        TaskStatus

    let onSave:
        (TaskStatus) -> String?


    var body: some View {
        HierarchicalSelectionSummaryRow(
            label:
                "Status",
            selectedTitles:
                [
                    normalizedStatus.displayName
                ],
            selectorTitle:
                "Task Status",
            selectorMessage:
                "Choose the current workflow state of this Task.",
            nodes:
                statusNodes,
            initialSelection:
                Set(
                    [
                        selectionID(
                            for:
                                normalizedStatus
                        )
                    ]
                ),
            buttonSystemImage:
                "pencil",
            maximumSelectionCount:
                1,
            onSave: {
                selection in

                guard
                    let selectedID =
                        selection.first,
                    let newStatus =
                        status(
                            for:
                                selectedID
                        )
                else {
                    return
                        "A Task must have a status."
                }

                return onSave(
                    newStatus
                )
            }
        )
    }


    private var normalizedStatus:
        TaskStatus
    {
        status == .closed
        ? .completed
        : status
    }


    private var availableStatuses:
        [TaskStatus]
    {
        TaskStatus.allCases
    }


    private var statusNodes:
        [HierarchySelectionNode]
    {
        availableStatuses.map {
            value in

            HierarchySelectionNode(
                id:
                    "task-status-\(value.rawValue)",
                selectionID:
                    selectionID(
                        for:
                            value
                    ),
                parentID:
                    nil,
                title:
                    value.displayName,
                subtitle:
                    statusDescription(
                        value
                    ),
                systemImage:
                    statusIcon(
                        value
                    ),
                systemImageColor:
                    value
                        .testudoStatusIconColor,
                depth:
                    0,
                searchText:
                    [
                        value.displayName,
                        statusDescription(
                            value
                        )
                    ]
                    .joined(
                        separator:
                            " "
                    )
            )
        }
    }


    private func selectionID(
        for status:
            TaskStatus
    ) -> UUID {
        switch status {
        case .todo:
            return UUID(
                uuidString:
                    "10000000-0000-0000-0000-000000000001"
            )!

        case .inProgress:
            return UUID(
                uuidString:
                    "10000000-0000-0000-0000-000000000002"
            )!

        case .completed,
             .closed:
            return UUID(
                uuidString:
                    "10000000-0000-0000-0000-000000000003"
            )!

        case .discontinued:
            return UUID(
                uuidString:
                    "10000000-0000-0000-0000-000000000005"
            )!
        }
    }


    private func status(
        for id:
            UUID
    ) -> TaskStatus? {
        availableStatuses.first {
            selectionID(
                for:
                    $0
            )
            == id
        }
    }


    private func statusIcon(
        _ status:
            TaskStatus
    ) -> String {
        switch status {
        case .todo:
            return "circle"

        case .inProgress:
            return "clock"

        case .completed,
             .closed:
            return "checkmark.circle"

        case .discontinued:
            return "xmark.circle"
        }
    }


    private func statusDescription(
        _ status:
            TaskStatus
    ) -> String {
        switch status {
        case .todo:
            return
                "Work that has not started yet."

        case .inProgress:
            return
                "Work currently being carried out."

        case .completed,
             .closed:
            return
                "Work that was completed successfully."

        case .discontinued:
            return
                "Work that ended without successful completion."
        }
    }
}
