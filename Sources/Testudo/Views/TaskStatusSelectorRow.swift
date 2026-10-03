import SwiftUI


struct TaskStatusSelectorRow:
    View
{
    let status:
        TaskStatus

    let allowsClosed:
        Bool

    let onSave:
        (TaskStatus) -> String?


    var body: some View {
        HierarchicalSelectionSummaryRow(
            label:
                "Status",
            selectedTitles:
                [
                    status.displayName
                ],
            selectorTitle:
                "Task Status",
            selectorMessage:
                allowsClosed
                ? "Choose the current state of this Task. Closed archives the complete top-level Task tree."
                : "Choose the current state of this Sub-task.",
            nodes:
                statusNodes,
            initialSelection:
                Set(
                    [
                        selectionID(
                            for:
                                status
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


    private var availableStatuses:
        [TaskStatus]
    {
        TaskStatus.allCases
            .filter {
                $0 != .closed
                || allowsClosed
            }
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
        for status: TaskStatus
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

        case .completed:
            return UUID(
                uuidString:
                    "10000000-0000-0000-0000-000000000003"
            )!

        case .closed:
            return UUID(
                uuidString:
                    "10000000-0000-0000-0000-000000000004"
            )!
        }
    }


    private func status(
        for id: UUID
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
        _ status: TaskStatus
    ) -> String {
        switch status {
        case .todo:
            return "circle"

        case .inProgress:
            return "clock"

        case .completed:
            return "checkmark.circle"

        case .closed:
            return "archivebox"
        }
    }


    private func statusDescription(
        _ status: TaskStatus
    ) -> String {
        switch status {
        case .todo:
            return
                "Work that has not started yet."

        case .inProgress:
            return
                "Work currently being carried out."

        case .completed:
            return
                "Finished work that remains active."

        case .closed:
            return
                "Archive this top-level Task and its complete subtree."
        }
    }
}
