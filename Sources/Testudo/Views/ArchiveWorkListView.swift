import SwiftUI


struct ArchiveWorkListView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Binding
    var selection:
        UUID?

    @State
    private var expandedIDs:
        Set<UUID> = []


    var body: some View {
        VStack(
            spacing: 0
        ) {
            WorkColumnHeader(
                title:
                    "Archive",
                subtitle:
                    subtitle
            )

            if archivedRoots.isEmpty {
                ContentUnavailableView {
                    Label(
                        "Archive Empty",
                        systemImage:
                            "archivebox"
                    )
                } description: {
                    Text(
                        "Closed top-level Tasks will appear here."
                    )
                }
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )

            } else {
                List {
                    ForEach(
                        visibleEntries
                    ) { entry in
                        archiveRow(
                            entry
                        )
                        .middleColumnSelectionStyle(
                            selection
                                == entry.item.id,
                            leadingExtension:
                                4,
                            trailingExtension:
                                4
                        )
                        .contentShape(
                            Rectangle()
                        )
                        .onTapGesture {
                            selection =
                                entry.item.id
                        }
                    }
                }
                .listStyle(
                    .inset
                )
            }
        }
        .background(
            TestudoStyle
                .contentBackground
        )
    }


    // ========================================================
    // MARK: - Entry
    // ========================================================

    private struct Entry:
        Identifiable
    {
        let item:
            WorkItem

        let depth:
            Int

        let hasChildren:
            Bool

        var id:
            UUID
        {
            item.id
        }
    }


    // ========================================================
    // MARK: - Hierarchy
    // ========================================================

    private var archivedRoots:
        [WorkItem]
    {
        store
            .archivedRootTasks()
    }


    private var visibleEntries:
        [Entry]
    {
        var result:
            [Entry] = []

        for root in archivedRoots {
            append(
                root,
                depth:
                    0,
                to:
                    &result
            )
        }

        return result
    }


    private func append(
        _ item: WorkItem,
        depth: Int,
        to result:
            inout [Entry]
    ) {
        let children =
            childItems(
                of:
                    item.id
            )

        result.append(
            Entry(
                item:
                    item,
                depth:
                    depth,
                hasChildren:
                    !children.isEmpty
            )
        )

        guard
            expandedIDs
                .contains(
                    item.id
                )
        else {
            return
        }

        for child in children {
            append(
                child,
                depth:
                    depth + 1,
                to:
                    &result
            )
        }
    }


    private func childItems(
        of parentID: UUID
    ) -> [WorkItem] {
        store.data.workItems
            .filter {
                $0.parentWorkItemID
                    == parentID
            }
            .sorted {
                $0.createdAt
                    < $1.createdAt
            }
    }


    // ========================================================
    // MARK: - Row
    // ========================================================

    @ViewBuilder
    private func archiveRow(
        _ entry: Entry
    ) -> some View {
        HStack(
            alignment:
                .top,
            spacing:
                5
        ) {
            if entry.hasChildren {
                Button {
                    toggle(
                        entry.item.id
                    )

                } label: {
                    Image(
                        systemName:
                            expandedIDs
                                .contains(
                                    entry.item.id
                                )
                            ? "chevron.down"
                            : "chevron.right"
                    )
                    .font(
                        .system(
                            size: 10,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .frame(
                        width: 15,
                        height: 20
                    )
                    .contentShape(
                        Rectangle()
                    )
                }
                .buttonStyle(.plain)

            } else {
                Color.clear
                    .frame(
                        width: 15,
                        height: 20
                    )
            }

            HStack(
                alignment:
                    .top,
                spacing:
                    9
            ) {
                Image(
                    systemName:
                        icon(
                            for:
                                entry.item
                        )
                )
                .font(
                    .system(
                        size: 13
                    )
                )
                .frame(
                    width: 17,
                    alignment:
                        .center
                )

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        3
                ) {
                    Text(
                        displayTitle(
                            entry.item
                        )
                    )
                    .lineLimit(1)

                    if let context =
                        context(
                            for:
                                entry.item
                        )
                    {
                        Text(context)
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(
                    kindLabel(
                        entry.item
                    )
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(
            .leading,
            min(
                CGFloat(
                    entry.depth
                ) * 14,
                84
            )
        )
        .padding(
            .vertical,
            2
        )
    }


    private func toggle(
        _ id: UUID
    ) {
        if expandedIDs
            .contains(
                id
            )
        {
            expandedIDs
                .remove(
                    id
                )
        } else {
            expandedIDs
                .insert(
                    id
                )
        }
    }


    // ========================================================
    // MARK: - Display
    // ========================================================

    private var subtitle:
        String
    {
        let count =
            archivedRoots.count

        return count == 1
        ? "1 archived Task"
        : "\(count) archived Tasks"
    }


    private func displayTitle(
        _ item: WorkItem
    ) -> String {
        if
            let title =
                item.title?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !title.isEmpty
        {
            return title
        }

        let body =
            item.body
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !body.isEmpty {
            return body
        }

        return
            item.kind.displayName
    }


    private func kindLabel(
        _ item: WorkItem
    ) -> String {
        if
            item.kind == .task,
            item.parentWorkItemID == nil,
            item.status == .closed
        {
            return "Closed"
        }

        switch item.kind {
        case .task:
            return "Sub-task"

        case .note:
            return "Note"

        case .activity:
            return "Activity"
        }
    }


    private func icon(
        for item: WorkItem
    ) -> String {
        switch item.kind {
        case .task:
            switch item.status {
            case .closed:
                return "archivebox"

            case .completed:
                return "checkmark.circle"

            case .inProgress:
                return "clock"

            case .todo,
                 nil:
                return "circle"
            }

        case .note:
            return "note.text"

        case .activity:
            return "waveform.path.ecg"
        }
    }


    private func context(
        for item: WorkItem
    ) -> String? {
        if
            item.kind == .task,
            item.status == .closed
        {
            return
                "Archived \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        if
            item.kind == .task,
            let deadline =
                item.deadlineAt
        {
            return
                "Deadline \(deadline.formatted(date: .abbreviated, time: .shortened))"
        }

        if
            item.kind == .note,
            let reminder =
                item.reminderAt
        {
            return
                "Reminder \(TestudoTime.displayDateTime(reminder, sourceTimeZoneID: item.reminderTimeZoneID))"
        }

        if
            item.kind == .activity,
            let occurred =
                item.loggedAt
        {
            return
                "Occurred \(TestudoTime.displayDateTime(occurred, sourceTimeZoneID: item.loggedTimeZoneID))"
        }

        return nil
    }
}
