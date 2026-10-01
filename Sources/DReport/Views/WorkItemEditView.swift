import SwiftUI

struct WorkItemEditView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Environment(\.dismiss)
    private var dismiss

    let itemID: UUID

    @State
    private var title = ""

    @State
    private var bodyText = ""

    @State
    private var themeID: UUID?

    @State
    private var parentWorkItemID: UUID?

    @State
    private var status:
        TaskStatus = .todo

    @State
    private var hasDeadline = false

    @State
    private var deadlineAt = Date()

    @State
    private var hasReminder = false

    @State
    private var reminderAt = Date()

    @State
    private var hasEventDate = false

    @State
    private var eventDate = Date()

    @State
    private var errorMessage: String?

    var body: some View {
        if let item = store.workItem(id: itemID) {
            VStack(spacing: 0) {
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text(
                            "Edit \(typeLabel(item))"
                        )
                        .font(.title2)
                        .fontWeight(.semibold)

                        Text(
                            displayTitle(item)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }

                    Button("Save") {
                        save(item)
                    }
                    .keyboardShortcut(
                        .defaultAction
                    )
                }
                .padding(18)

                Divider()

                ScrollView {
                    Form {
                        Section("Content") {
                            TextField(
                                "Title",
                                text: $title
                            )

                            VStack(
                                alignment: .leading,
                                spacing: 6
                            ) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )

                                TextEditor(
                                    text: $bodyText
                                )
                                .frame(
                                    minHeight: 130
                                )
                            }
                        }

                        Section("Location") {
                            Picker(
                                "Theme",
                                selection: $themeID
                            ) {
                                Text(
                                    "No Theme"
                                )
                                .tag(
                                    Optional<UUID>.none
                                )

                                ForEach(
                                    sortedThemes
                                ) { theme in
                                    Text(theme.name)
                                        .tag(
                                            Optional(
                                                theme.id
                                            )
                                        )
                                }
                            }

                            Picker(
                                "Parent Task",
                                selection:
                                    $parentWorkItemID
                            ) {
                                Text(
                                    "No Parent"
                                )
                                .tag(
                                    Optional<UUID>.none
                                )

                                ForEach(
                                    availableParentTasks
                                ) { parent in
                                    Text(
                                        displayTitle(
                                            parent
                                        )
                                    )
                                    .tag(
                                        Optional(
                                            parent.id
                                        )
                                    )
                                }
                            }
                        }

                        if item.kind == .task {
                            taskSection
                        }

                        if item.kind == .note {
                            noteSection
                        }

                        if item.kind == .activity {
                            eventSection
                        }

                        Section("System Information") {
                            LabeledContent(
                                "Type",
                                value:
                                    typeLabel(item)
                            )

                            LabeledContent(
                                "Created",
                                value:
                                    item.createdAt
                                        .formatted(
                                            date:
                                                .abbreviated,
                                            time:
                                                .shortened
                                        )
                            )

                            Text(
                                "Creation time and history are read-only."
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        if let errorMessage {
                            Section {
                                Label(
                                    errorMessage,
                                    systemImage:
                                        "exclamationmark.triangle"
                                )
                                .foregroundStyle(.red)
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .padding(.bottom, 16)
                }
            }
            .frame(
                width: 650,
                height: 720
            )
            .onAppear {
                load(item)
            }
        } else {
            ContentUnavailableView(
                "Item Not Found",
                systemImage:
                    "questionmark.circle"
            )
            .frame(
                width: 500,
                height: 300
            )
        }
    }

    private var taskSection:
        some View
    {
        Section("Task") {
            Picker(
                "Status",
                selection: $status
            ) {
                Text("To Do")
                    .tag(
                        TaskStatus.todo
                    )

                Text("In Progress")
                    .tag(
                        TaskStatus.inProgress
                    )

                Text("Completed")
                    .tag(
                        TaskStatus.completed
                    )
            }

            Toggle(
                "Has deadline",
                isOn: $hasDeadline
            )

            if hasDeadline {
                DatePicker(
                    "Deadline",
                    selection:
                        $deadlineAt,
                    displayedComponents:
                        [.date, .hourAndMinute]
                )
            }
        }
    }

    private var noteSection:
        some View
    {
        Section("Note") {
            Toggle(
                "Set reminder",
                isOn: $hasReminder
            )

            if hasReminder {
                DatePicker(
                    "Reminder",
                    selection:
                        $reminderAt,
                    displayedComponents:
                        [.date, .hourAndMinute]
                )
            }
        }
    }

    private var eventSection:
        some View
    {
        Section("Event") {
            Toggle(
                "Set event date",
                isOn: $hasEventDate
            )

            if hasEventDate {
                DatePicker(
                    "Date & time",
                    selection:
                        $eventDate,
                    displayedComponents:
                        [.date, .hourAndMinute]
                )
            }

            Toggle(
                "Set reminder",
                isOn: $hasReminder
            )

            if hasReminder {
                DatePicker(
                    "Reminder",
                    selection:
                        $reminderAt,
                    displayedComponents:
                        [.date, .hourAndMinute]
                )
            }
        }
    }

    private var sortedThemes:
        [Theme]
    {
        store.data.themes
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }

    private var availableParentTasks:
        [WorkItem]
    {
        let excluded =
            descendantIDs(
                of: itemID
            )
            .union([itemID])

        return store.data.workItems
            .filter {
                $0.kind == .task
                && !excluded.contains(
                    $0.id
                )
            }
            .sorted {
                displayTitle($0)
                    .localizedCaseInsensitiveCompare(
                        displayTitle($1)
                    )
                    == .orderedAscending
            }
    }

    private func descendantIDs(
        of parentID: UUID
    ) -> Set<UUID> {
        var result =
            Set<UUID>()

        var queue = [parentID]

        while let current =
            queue.first
        {
            queue.removeFirst()

            let children =
                store.data.workItems
                    .filter {
                        $0.parentWorkItemID
                            == current
                    }

            for child in children {
                if
                    result.insert(
                        child.id
                    ).inserted
                {
                    queue.append(
                        child.id
                    )
                }
            }
        }

        return result
    }

    private func load(
        _ item: WorkItem
    ) {
        title =
            item.title ?? ""

        bodyText =
            item.body

        themeID =
            item.themeID

        parentWorkItemID =
            item.parentWorkItemID

        status =
            item.status ?? .todo

        if let deadline =
            item.deadlineAt
        {
            hasDeadline = true
            deadlineAt = deadline
        } else {
            hasDeadline = false
            deadlineAt = Date()
        }

        if let reminder =
            item.reminderAt
        {
            hasReminder = true
            reminderAt = reminder
        } else {
            hasReminder = false
            reminderAt =
                Calendar.current.date(
                    byAdding: .hour,
                    value: 1,
                    to: Date()
                ) ?? Date()
        }

        if let scheduled =
            item.scheduledAt
        {
            hasEventDate = true
            eventDate = scheduled
        } else {
            hasEventDate = false
            eventDate = Date()
        }

        errorMessage = nil
    }

    private func save(
        _ item: WorkItem
    ) {
        guard let themeID else {
            errorMessage =
                "A Theme is required."
            return
        }

        let error =
            store.updateWorkItemDetails(
                itemID: item.id,
                title: title,
                body: bodyText,
                themeID: themeID,
                parentWorkItemID:
                    parentWorkItemID,
                status:
                    item.kind == .task
                    ? status
                    : nil,
                deadlineAt:
                    item.kind == .task
                    && hasDeadline
                    ? deadlineAt
                    : nil,
                reminderAt:
                    item.kind != .task
                    && hasReminder
                    ? reminderAt
                    : nil,
                scheduledAt:
                    item.kind == .activity
                    && hasEventDate
                    ? eventDate
                    : nil
            )

        if let error {
            errorMessage = error
        } else {
            dismiss()
        }
    }

    private func displayTitle(
        _ item: WorkItem
    ) -> String {
        if
            let title = item.title,
            !title
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
        {
            return title
        }

        if !item.body.isEmpty {
            return item.body
        }

        return typeLabel(item)
    }

    private func typeLabel(
        _ item: WorkItem
    ) -> String {
        switch item.kind {
        case .task:
            return "Task"

        case .note:
            return "Note"

        case .activity:
            return "Event"
        }
    }
}
