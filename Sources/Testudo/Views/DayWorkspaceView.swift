import SwiftUI
import Foundation


struct DayWorkspaceView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let date: Date

    @Binding
    var selectedWorkItemID: UUID?

    @Binding
    var selectedCalendarEventID: UUID?


    @State
    private var isAppLogExpanded =
        false


    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
    }


    private var dayStart: Date {
        calendar.startOfDay(
            for: date
        )
    }


    private var dayEnd: Date {
        calendar.date(
            byAdding: .day,
            value: 1,
            to: dayStart
        )
        ?? dayStart.addingTimeInterval(
            86400
        )
    }


    private var todayStart: Date {
        calendar.startOfDay(
            for: Date()
        )
    }


    private var isPastDay: Bool {
        dayStart < todayStart
    }


    var body: some View {
        ZStack {
            TestudoStyle
                .contentBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {
                    header

                    daySection(
                        "Schedule"
                    ) {
                        schedule
                    }

                    dayDivider

                    daySection(
                        "Planned Work"
                    ) {
                        plannedWork
                    }

                    dayDivider

                    daySection(
                        "Due & Reminders"
                    ) {
                        dueAndReminders
                    }

                    dayDivider

                    daySection(
                        "Day History",
                        count:
                            workDayLogEntries.count
                    ) {
                        workDayLog
                    }

                    dayDivider

                    appLog
                }
                .padding(
                    .horizontal,
                    28
                )
                .padding(
                    .top,
                    8
                )
                .padding(
                    .bottom,
                    32
                )
                .frame(
                    maxWidth: 760,
                    alignment: .leading
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
            }
        }
    }


    private var header: some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName:
                    "calendar"
            )
            .font(.title2)
            .frame(
                width: 28
            )

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(
                    date.formatted(
                        .dateTime
                            .weekday(.wide)
                            .day()
                            .month(.wide)
                            .year()
                    )
                )
                .font(.title2)
                .fontWeight(
                    .semibold
                )

                Text("Day")
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()
        }
    }


    private func daySection<Content: View>(
        _ title: String,
        count: Int? = nil,
        @ViewBuilder
        content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 11
        ) {
            HStack(
                alignment: .firstTextBaseline,
                spacing: 7
            ) {
                Text(title)
                    .font(.headline)

                if let count {
                    Text(
                        "\(count)"
                    )
                    .font(
                        .caption2
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            content()
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }


    private var dayDivider: some View {
        Divider()
            .opacity(
                0.55
            )
    }


    private func emptyText(
        _ text: String
    ) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(
                .secondary
            )
            .padding(
                .vertical,
                2
            )
    }


    private var dayEvents: [CalendarEvent] {
        store.calendarEvents(
            on: date
        )
    }


    @ViewBuilder
    private var schedule: some View {
        if dayEvents.isEmpty {
            emptyText(
                "No calendar events."
            )

        } else {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                ForEach(
                    dayEvents
                ) { event in
                    Button {
                        selectedWorkItemID =
                            nil

                        selectedCalendarEventID =
                            event.id
                    } label: {
                        CalendarEventAgendaRow(
                            event: event
                        )
                        .padding(
                            .vertical,
                            3
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    private struct PlannedWorkstream:
        Identifiable
    {
        let root: WorkItem
        var tasks: [WorkItem]

        var id: UUID {
            root.id
        }
    }


    private var activeCandidates: [WorkItem] {
        store.activeWorkItems
            .filter { item in
                guard
                    item.kind == .task,
                    item.status == .todo
                    || item.status == .inProgress,
                    item.createdAt < dayEnd
                else {
                    return false
                }

                // Today keeps overdue work visible.
                //
                // For a future Day, however, a Task whose own
                // deadline has already passed before that Day
                // must not be carried forward as planned work.
                if
                    dayStart > todayStart,
                    let deadline =
                        item.deadlineAt,
                    deadline < dayStart
                {
                    return false
                }

                return true
            }
    }


    private var actionableTasks: [WorkItem] {
        let candidateIDs =
            Set(
                activeCandidates.map(
                    \.id
                )
            )

        let parentIDsWithActiveChildren:
            Set<UUID> =
            Set(
                activeCandidates
                    .compactMap { item in
                        guard
                            let parentID =
                                item.parentWorkItemID,
                            candidateIDs.contains(
                                parentID
                            )
                        else {
                            return nil
                        }

                        return parentID
                    }
            )

        return activeCandidates
            .filter {
                !parentIDsWithActiveChildren
                    .contains(
                        $0.id
                    )
            }
    }


    private var plannedTasks: [WorkItem] {
        let ranked =
            actionableTasks
                .sorted {
                    lhs,
                    rhs in

                    let left =
                        plannerScore(
                            lhs
                        )

                    let right =
                        plannerScore(
                            rhs
                        )

                    if left != right {
                        return left > right
                    }

                    switch (
                        lhs.deadlineAt,
                        rhs.deadlineAt
                    ) {
                    case let (
                        leftDate?,
                        rightDate?
                    ):
                        if leftDate != rightDate {
                            return
                                leftDate
                                < rightDate
                        }

                    case (_?, nil):
                        return true

                    case (nil, _?):
                        return false

                    case (nil, nil):
                        break
                    }

                    if
                        lhs.updatedAt
                            != rhs.updatedAt
                    {
                        return
                            lhs.updatedAt
                            > rhs.updatedAt
                    }

                    return
                        lhs.id.uuidString
                        < rhs.id.uuidString
                }

        var selected: [WorkItem] = []
        var selectedIDs = Set<UUID>()
        var representedRoots = Set<UUID>()

        for task in ranked {
            if isMandatory(
                task
            ) {
                selected.append(
                    task
                )

                selectedIDs.insert(
                    task.id
                )

                representedRoots.insert(
                    topLevelTask(
                        for: task
                    ).id
                )
            }
        }

        for task in ranked {
            if selectedIDs.contains(
                task.id
            ) {
                continue
            }

            if selected.count >= 10 {
                break
            }

            let root =
                topLevelTask(
                    for: task
                )

            guard
                representedRoots.count < 4
                || representedRoots.contains(
                    root.id
                )
            else {
                continue
            }

            selected.append(
                task
            )

            selectedIDs.insert(
                task.id
            )

            representedRoots.insert(
                root.id
            )
        }

        return selected
    }


    private var plannedWorkstreams:
        [PlannedWorkstream]
    {
        var result:
            [PlannedWorkstream] = []

        for task in plannedTasks {
            let root =
                topLevelTask(
                    for: task
                )

            if
                let index =
                    result.firstIndex(
                        where: {
                            $0.root.id
                                == root.id
                        }
                    )
            {
                result[index]
                    .tasks
                    .append(
                        task
                    )

            } else {
                result.append(
                    PlannedWorkstream(
                        root: root,
                        tasks: [
                            task
                        ]
                    )
                )
            }
        }

        return result
    }


    @ViewBuilder
    private var plannedWork: some View {
        if isPastDay {
            emptyText(
                "Historical plan snapshots are not stored yet for this day."
            )

        } else if
            plannedWorkstreams.isEmpty
        {
            emptyText(
                "No active work is currently suggested for this day."
            )

        } else {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                ForEach(
                    plannedWorkstreams
                ) { workstream in
                    VStack(
                        alignment: .leading,
                        spacing: 7
                    ) {
                        if
                            workstream.tasks.count > 1
                            || workstream.tasks
                                .first?
                                .id
                                != workstream.root.id
                        {
                            Button {
                                selectWork(
                                    workstream.root.id
                                )
                            } label: {
                                HStack(
                                    spacing: 7
                                ) {
                                    Image(
                                        systemName:
                                            "folder"
                                    )
                                    .font(
                                        .system(
                                            size: 12,
                                            weight:
                                                .semibold
                                        )
                                    )

                                    Text(
                                        workTitle(
                                            workstream.root
                                        )
                                    )
                                    .font(.callout)
                                    .fontWeight(
                                        .semibold
                                    )

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(
                            workstream.tasks
                        ) { task in
                            Button {
                                selectWork(
                                    task.id
                                )
                            } label: {
                                VStack(
                                    alignment:
                                        .leading,
                                    spacing: 2
                                ) {
                                    WorkGuideRow(
                                        item: task,
                                        context:
                                            plannerReason(
                                                task
                                            )
                                    )

                                    if
                                        let path =
                                            hierarchyPath(
                                                for: task,
                                                root:
                                                    workstream.root
                                            )
                                    {
                                        Text(path)
                                            .font(
                                                .caption2
                                            )
                                            .foregroundStyle(
                                                .secondary
                                            )
                                            .padding(
                                                .leading,
                                                26
                                            )
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }


    private func isMandatory(
        _ task: WorkItem
    ) -> Bool {
        if
            let deadline =
                task.deadlineAt
        {
            if dayStart == todayStart {
                if deadline < dayEnd {
                    return true
                }

            } else if
                deadline >= dayStart,
                deadline < dayEnd
            {
                return true
            }
        }

        if task.status == .inProgress {
            return true
        }

        if isRelatedToDayEvent(
            task
        ) {
            return true
        }

        return false
    }


    private func plannerScore(
        _ task: WorkItem
    ) -> Int {
        var score = 0

        if
            let deadline =
                task.deadlineAt
        {
            if
                dayStart == todayStart,
                deadline < dayStart
            {
                score += 1000

            } else if
                deadline >= dayStart,
                deadline < dayEnd
            {
                score += 950

            } else if
                deadline >= dayEnd
            {
                let deadlineDay =
                    calendar.startOfDay(
                        for: deadline
                    )

                let days =
                    calendar.dateComponents(
                        [.day],
                        from: dayStart,
                        to: deadlineDay
                    )
                    .day
                    ?? 999

                if days == 1 {
                    score += 520

                } else if
                    days > 1,
                    days <= 7
                {
                    score +=
                        max(
                            160,
                            480
                            - days * 45
                        )
                }
            }
        }

        if task.status == .inProgress {
            score += 700
        }

        if isRelatedToDayEvent(
            task
        ) {
            score += 650
        }

        if
            let ancestorDeadline =
                nearestAncestorDeadline(
                    for: task
                )
        {
            if
                dayStart == todayStart,
                ancestorDeadline < dayStart
            {
                score += 300

            } else if
                ancestorDeadline >= dayStart,
                ancestorDeadline < dayEnd
            {
                score += 280

            } else if
                ancestorDeadline >= dayEnd
            {
                let ancestorDay =
                    calendar.startOfDay(
                        for:
                            ancestorDeadline
                    )

                let days =
                    calendar.dateComponents(
                        [.day],
                        from: dayStart,
                        to: ancestorDay
                    )
                    .day
                    ?? 999

                if
                    days >= 1,
                    days <= 7
                {
                    score +=
                        max(
                            80,
                            240
                            - days * 25
                        )
                }
            }
        }

        return score
    }


    private var eventWorkIDs: Set<UUID> {
        var result =
            Set<UUID>()

        for event in dayEvents {
            for item in
                store.linkedWorkItems(
                    forCalendarEventID:
                        event.id
                )
            {
                result.insert(
                    item.id
                )
            }
        }

        return result
    }


    private func isRelatedToDayEvent(
        _ task: WorkItem
    ) -> Bool {
        var current:
            WorkItem? =
            task

        var visited =
            Set<UUID>()

        while
            let item = current,
            visited.insert(
                item.id
            ).inserted
        {
            if eventWorkIDs.contains(
                item.id
            ) {
                return true
            }

            guard
                let parentID =
                    item.parentWorkItemID
            else {
                break
            }

            current =
                store.workItem(
                    id: parentID
                )
        }

        return false
    }


    private func nearestAncestorDeadline(
        for task: WorkItem
    ) -> Date? {
        var parentID =
            task.parentWorkItemID

        var visited =
            Set<UUID>()

        var result:
            Date?

        while
            let id = parentID,
            visited.insert(
                id
            ).inserted,
            let parent =
                store.workItem(
                    id: id
                )
        {
            if
                parent.kind == .task,
                let deadline =
                    parent.deadlineAt
            {
                if
                    result == nil
                    || deadline < result!
                {
                    result =
                        deadline
                }
            }

            parentID =
                parent.parentWorkItemID
        }

        return result
    }


    private func plannerReason(
        _ task: WorkItem
    ) -> String {
        if
            let deadline =
                task.deadlineAt
        {
            if
                dayStart == todayStart,
                deadline < dayStart
            {
                return "Overdue"
            }

            if
                deadline >= dayStart,
                deadline < dayEnd
            {
                return
                    dayStart == todayStart
                    ? "Due today"
                    : "Due this day"
            }

            if deadline >= dayEnd {
                let deadlineDay =
                    calendar.startOfDay(
                        for: deadline
                    )

                let days =
                    calendar.dateComponents(
                        [.day],
                        from: dayStart,
                        to: deadlineDay
                    )
                    .day
                    ?? 999

                if days == 1 {
                    return "Due next day"
                }

                if
                    days > 1,
                    days <= 7
                {
                    return
                        "Due in \(days) days"
                }
            }
        }

        if isRelatedToDayEvent(
            task
        ) {
            return
                "Related to event"
        }

        if task.status == .inProgress {
            return
                "In progress"
        }

        if
            nearestAncestorDeadline(
                for: task
            ) != nil
        {
            return
                "Workstream deadline"
        }

        return
            "Next action"
    }


    private func topLevelTask(
        for task: WorkItem
    ) -> WorkItem {
        var current =
            task

        var visited =
            Set<UUID>()

        while
            let parentID =
                current.parentWorkItemID,
            visited.insert(
                parentID
            ).inserted,
            let parent =
                store.workItem(
                    id: parentID
                ),
            parent.kind == .task
        {
            current =
                parent
        }

        return current
    }


    private func hierarchyPath(
        for task: WorkItem,
        root: WorkItem
    ) -> String? {
        guard task.id != root.id
        else {
            return nil
        }

        var parents:
            [WorkItem] = []

        var parentID =
            task.parentWorkItemID

        var visited =
            Set<UUID>()

        while
            let id = parentID,
            visited.insert(
                id
            ).inserted,
            let parent =
                store.workItem(
                    id: id
                )
        {
            if parent.id == root.id {
                break
            }

            parents.append(
                parent
            )

            parentID =
                parent.parentWorkItemID
        }

        if parents.isEmpty {
            return nil
        }

        return
            parents
                .reversed()
                .map {
                    workTitle(
                        $0
                    )
                }
                .joined(
                    separator: " › "
                )
    }


    private var deadlineTasks: [WorkItem] {
        store.data.workItems
            .filter { item in
                guard
                    item.kind == .task,
                    let deadline =
                        item.deadlineAt
                else {
                    return false
                }

                return
                    calendar.isDate(
                        deadline,
                        inSameDayAs:
                            date
                    )
            }
            .sorted {
                (
                    $0.deadlineAt
                    ?? .distantFuture
                )
                <
                (
                    $1.deadlineAt
                    ?? .distantFuture
                )
            }
    }


    private var reminderNotes: [WorkItem] {
        store.data.workItems
            .filter { item in
                guard
                    item.kind == .note,
                    let reminder =
                        item.reminderAt
                else {
                    return false
                }

                return
                    calendar.isDate(
                        reminder,
                        inSameDayAs:
                            date
                    )
            }
            .sorted {
                (
                    $0.reminderAt
                    ?? .distantFuture
                )
                <
                (
                    $1.reminderAt
                    ?? .distantFuture
                )
            }
    }


    @ViewBuilder
    private var dueAndReminders: some View {
        if
            deadlineTasks.isEmpty,
            reminderNotes.isEmpty
        {
            emptyText(
                "No deadlines or reminders."
            )

        } else {
            VStack(
                alignment: .leading,
                spacing: 15
            ) {
                if !deadlineTasks.isEmpty {
                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        Text("Deadlines")
                            .font(.caption)
                            .fontWeight(
                                .semibold
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        ForEach(
                            deadlineTasks
                        ) { task in
                            Button {
                                selectWork(
                                    task.id
                                )
                            } label: {
                                WorkGuideRow(
                                    item: task,
                                    context:
                                        deadlineContext(
                                            task
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !reminderNotes.isEmpty {
                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        Text("Reminders")
                            .font(.caption)
                            .fontWeight(
                                .semibold
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        ForEach(
                            reminderNotes
                        ) { note in
                            Button {
                                selectWork(
                                    note.id
                                )
                            } label: {
                                WorkGuideRow(
                                    item: note,
                                    context:
                                        reminderContext(
                                            note
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }


    private func deadlineContext(
        _ task: WorkItem
    ) -> String? {
        guard
            let deadline =
                task.deadlineAt
        else {
            return nil
        }

        return
            "Due \(TestudoTime.displayTime(deadline, sourceTimeZoneID: task.deadlineTimeZoneID))"
    }


    private func reminderContext(
        _ note: WorkItem
    ) -> String? {
        guard
            let reminder =
                note.reminderAt
        else {
            return nil
        }

        return
            "Reminder \(TestudoTime.displayTime(reminder, sourceTimeZoneID: note.reminderTimeZoneID))"
    }


    // ========================================================
    // MARK: - Day History
    //
    // Real Work-domain chronology.
    //
    // Creation / Note / Activity occurrence use their canonical
    // WorkItem timestamps.
    //
    // Task lifecycle changes use semantic HistoryEvents so that
    // earlier Started / Completed / Discontinued cycles remain
    // historically visible even if the Task later changes state.
    // ========================================================

    private struct WorkDayLogEntry:
        Identifiable
    {
        let id:
            String

        let timestamp:
            Date

        let workItemID:
            UUID

        let title:
            String

        let action:
            String

        let detail:
            String?

        let icon:
            String

        let taskStatus:
            TaskStatus?
    }


    private var workDayLogEntries:
        [WorkDayLogEntry]
    {
        var entries:
            [WorkDayLogEntry] = []


        let tasks =
            store.data.workItems
                .filter {
                    $0.kind == .task
                }

        let taskByID =
            Dictionary(
                uniqueKeysWithValues:
                    tasks.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )


        // ----------------------------------------------------
        // Created Tasks, Notes and Activities.
        // ----------------------------------------------------

        for item in
            store.data.workItems
        {
            switch item.kind {

            case .task:

                if isInSelectedDay(
                    item.createdAt
                ) {
                    entries.append(
                        WorkDayLogEntry(
                            id:
                                "task-created-\(item.id.uuidString)",
                            timestamp:
                                item.createdAt,
                            workItemID:
                                item.id,
                            title:
                                workTitle(
                                    item
                                ),
                            action:
                                "Created · To Do",
                            detail:
                                compactWorkDescription(
                                    item
                                ),
                            icon:
                                "circle",
                            taskStatus:
                                .todo
                        )
                    )
                }


            case .note:

                if isInSelectedDay(
                    item.createdAt
                ) {
                    entries.append(
                        WorkDayLogEntry(
                            id:
                                "note-created-\(item.id.uuidString)",
                            timestamp:
                                item.createdAt,
                            workItemID:
                                item.id,
                            title:
                                workTitle(
                                    item
                                ),
                            action:
                                "Note added",
                            detail:
                                compactWorkDescription(
                                    item
                                ),
                            icon:
                                "note.text",
                            taskStatus:
                                nil
                        )
                    )
                }


            case .activity:

                if
                    let occurred =
                        item.loggedAt,
                    isInSelectedDay(
                        occurred
                    )
                {
                    entries.append(
                        WorkDayLogEntry(
                            id:
                                "activity-\(item.id.uuidString)",
                            timestamp:
                                occurred,
                            workItemID:
                                item.id,
                            title:
                                workTitle(
                                    item
                                ),
                            action:
                                "Occurred",
                            detail:
                                compactWorkDescription(
                                    item
                                ),
                            icon:
                                "waveform.path.ecg",
                            taskStatus:
                                nil
                        )
                    )
                }
            }
        }


        // ----------------------------------------------------
        // Canonical Task lifecycle events.
        //
        // These are preferable to reading only the current
        // startedAt/completedAt/discontinuedAt fields because
        // HistoryEvent retains earlier lifecycle cycles.
        // ----------------------------------------------------

        let lifecycleEvents =
            store.data.historyEvents
                .filter {
                    event in

                    guard
                        isInSelectedDay(
                            event.timestamp
                        )
                    else {
                        return false
                    }

                    switch event.kind {
                    case .started,
                         .completed,
                         .discontinued:
                        return true

                    default:
                        return false
                    }
                }


        for event in lifecycleEvents {
            guard
                let task =
                    taskByID[
                        event.workItemID
                    ]
            else {
                continue
            }


            switch event.kind {

            case .started:

                let transition =
                    statusTransition(
                        for:
                            event,
                        target:
                            .inProgress
                    )

                entries.append(
                    WorkDayLogEntry(
                        id:
                            "lifecycle-\(event.id.uuidString)",
                        timestamp:
                            event.timestamp,
                        workItemID:
                            task.id,
                        title:
                            workTitle(
                                task
                            ),
                        action:
                            transition.map {
                                "Started · \($0)"
                            }
                            ?? "Started · In Progress",
                        detail:
                            nil,
                        icon:
                            "clock",
                        taskStatus:
                            .inProgress
                    )
                )


            case .completed:

                let transition =
                    statusTransition(
                        for:
                            event,
                        target:
                            .completed
                    )

                entries.append(
                    WorkDayLogEntry(
                        id:
                            "lifecycle-\(event.id.uuidString)",
                        timestamp:
                            event.timestamp,
                        workItemID:
                            task.id,
                        title:
                            workTitle(
                                task
                            ),
                        action:
                            transition.map {
                                "Completed · \($0)"
                            }
                            ?? "Completed",
                        detail:
                            nil,
                        icon:
                            "checkmark.circle",
                        taskStatus:
                            .completed
                    )
                )


            case .discontinued:

                let transition =
                    statusTransition(
                        for:
                            event,
                        target:
                            .discontinued
                    )

                let reason =
                    discontinuationReason(
                        for:
                            event,
                        item:
                            task
                    )

                var components:
                    [String] = [
                        "Discontinued"
                    ]

                if let transition {
                    components.append(
                        transition
                    )
                }

                if let reason {
                    components.append(
                        reason
                    )
                }

                entries.append(
                    WorkDayLogEntry(
                        id:
                            "lifecycle-\(event.id.uuidString)",
                        timestamp:
                            event.timestamp,
                        workItemID:
                            task.id,
                        title:
                            workTitle(
                                task
                            ),
                        action:
                            components.joined(
                                separator:
                                    " · "
                            ),
                        detail:
                            discontinuationOutcome(
                                for:
                                    event,
                                item:
                                    task
                            ),
                        icon:
                            "xmark.circle",
                        taskStatus:
                            .discontinued
                    )
                )


            default:
                break
            }
        }


        // ----------------------------------------------------
        // Legacy fallback.
        //
        // Older Environment data may contain lifecycle fields
        // without the matching semantic HistoryEvent.
        // ----------------------------------------------------

        for task in tasks {

            if
                let started =
                    task.startedAt,
                isInSelectedDay(
                    started
                ),
                !hasLifecycleEvent(
                    workItemID:
                        task.id,
                    kind:
                        .started,
                    timestamp:
                        started
                )
            {
                entries.append(
                    WorkDayLogEntry(
                        id:
                            "legacy-started-\(task.id.uuidString)",
                        timestamp:
                            started,
                        workItemID:
                            task.id,
                        title:
                            workTitle(
                                task
                            ),
                        action:
                            "Started · In Progress",
                        detail:
                            nil,
                        icon:
                            "clock",
                        taskStatus:
                            .inProgress
                    )
                )
            }


            if
                let completed =
                    task.completedAt,
                isInSelectedDay(
                    completed
                ),
                !hasLifecycleEvent(
                    workItemID:
                        task.id,
                    kind:
                        .completed,
                    timestamp:
                        completed
                )
            {
                entries.append(
                    WorkDayLogEntry(
                        id:
                            "legacy-completed-\(task.id.uuidString)",
                        timestamp:
                            completed,
                        workItemID:
                            task.id,
                        title:
                            workTitle(
                                task
                            ),
                        action:
                            "Completed",
                        detail:
                            nil,
                        icon:
                            "checkmark.circle",
                        taskStatus:
                            .completed
                    )
                )
            }


            if
                let discontinued =
                    task.discontinuedAt,
                isInSelectedDay(
                    discontinued
                ),
                !hasLifecycleEvent(
                    workItemID:
                        task.id,
                    kind:
                        .discontinued,
                    timestamp:
                        discontinued
                )
            {
                let reason =
                    task
                        .discontinuationReason?
                        .displayName

                entries.append(
                    WorkDayLogEntry(
                        id:
                            "legacy-discontinued-\(task.id.uuidString)",
                        timestamp:
                            discontinued,
                        workItemID:
                            task.id,
                        title:
                            workTitle(
                                task
                            ),
                        action:
                            reason.map {
                                "Discontinued · \($0)"
                            }
                            ?? "Discontinued",
                        detail:
                            task
                                .discontinuationNote,
                        icon:
                            "xmark.circle",
                        taskStatus:
                            .discontinued
                    )
                )
            }
        }


        // ----------------------------------------------------
        // A transition back to To Do has no separate lifecycle
        // timestamp, so its statusChanged event is itself the
        // meaningful Work-history event.
        // ----------------------------------------------------

        let returnedToDoEvents =
            store.data.historyEvents
                .filter {
                    event in

                    event.kind
                        == .statusChanged
                    && event.newValue
                        == TaskStatus
                            .todo
                            .rawValue
                    && isInSelectedDay(
                        event.timestamp
                    )
                }


        for event in returnedToDoEvents {
            guard
                let task =
                    taskByID[
                        event.workItemID
                    ]
            else {
                continue
            }


            let transition =
                statusTransitionText(
                    previousRawValue:
                        event.previousValue,
                    newRawValue:
                        event.newValue
                )

            entries.append(
                WorkDayLogEntry(
                    id:
                        "status-\(event.id.uuidString)",
                    timestamp:
                        event.timestamp,
                    workItemID:
                        task.id,
                    title:
                        workTitle(
                            task
                        ),
                    action:
                        transition
                        ?? "Status changed · To Do",
                    detail:
                        nil,
                    icon:
                        "circle",
                    taskStatus:
                        .todo
                )
            )
        }


        // Day History is a reverse chronology:
        // newest Work event first, oldest last.
        return entries
            .sorted {
                lhs,
                rhs in

                if
                    lhs.timestamp
                        != rhs.timestamp
                {
                    return
                        lhs.timestamp
                        > rhs.timestamp
                }

                return
                    lhs.id
                    > rhs.id
            }
    }


    @ViewBuilder
    private var workDayLog:
        some View
    {
        if workDayLogEntries.isEmpty {
            emptyText(
                "No Work history was recorded for this day."
            )

        } else {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                ForEach(
                    workDayLogEntries
                ) {
                    entry in

                    workDayLogRow(
                        entry
                    )
                }
            }
        }
    }


    private func workDayLogRow(
        _ entry:
            WorkDayLogEntry
    ) -> some View
    {
        Button {
            selectWork(
                entry.workItemID
            )

        } label: {
            HStack(
                alignment: .top,
                spacing: 10
            ) {

                Text(
                    entry.timestamp
                        .formatted(
                            date:
                                .omitted,
                            time:
                                .shortened
                        )
                )
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 54,
                    alignment:
                        .leading
                )


                Image(
                    systemName:
                        entry.icon
                )
                .font(
                    .system(
                        size: 13,
                        weight:
                            .medium
                    )
                )
                .foregroundStyle(
                    workDayHistoryIconStyle(
                        entry
                    )
                )
                .frame(
                    width: 18,
                    height: 18
                )


                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        entry.title
                    )
                    .font(.callout)
                    .fontWeight(
                        .medium
                    )
                    .foregroundStyle(
                        .primary
                    )
                    .lineLimit(2)


                    Text(
                        entry.action
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(2)


                    if
                        let detail =
                            entry.detail,
                        !detail.isEmpty
                    {
                        Text(
                            detail
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(2)
                        .padding(
                            .top,
                            1
                        )
                    }
                }


                Spacer(
                    minLength: 0
                )
            }
            .padding(
                .vertical,
                5
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .plain
        )
    }


    private func workDayHistoryIconStyle(
        _ entry:
            WorkDayLogEntry
    ) -> AnyShapeStyle
    {
        if
            let status =
                entry.taskStatus
        {
            return AnyShapeStyle(
                status
                    .testudoStatusIconColor
            )
        }

        return AnyShapeStyle(
            Color.secondary
        )
    }


    private func isInSelectedDay(
        _ timestamp:
            Date
    ) -> Bool
    {
        timestamp >= dayStart
        && timestamp < dayEnd
    }


    private func hasLifecycleEvent(
        workItemID:
            UUID,
        kind:
            HistoryEventKind,
        timestamp:
            Date
    ) -> Bool
    {
        store.data.historyEvents
            .contains {
                event in

                event.workItemID
                    == workItemID
                && event.kind
                    == kind
                && timestampsMatch(
                    event.timestamp,
                    timestamp
                )
            }
    }


    private func timestampsMatch(
        _ lhs:
            Date,
        _ rhs:
            Date
    ) -> Bool
    {
        abs(
            lhs.timeIntervalSince(
                rhs
            )
        ) < 0.001
    }


    private func statusTransition(
        for lifecycleEvent:
            HistoryEvent,
        target:
            TaskStatus
    ) -> String?
    {
        let statusEvent =
            store.data.historyEvents
                .last {
                    event in

                    event.workItemID
                        == lifecycleEvent
                            .workItemID
                    && event.kind
                        == .statusChanged
                    && event.newValue
                        == target.rawValue
                    && timestampsMatch(
                        event.timestamp,
                        lifecycleEvent.timestamp
                    )
                }


        guard let statusEvent
        else {
            return nil
        }


        return statusTransitionText(
            previousRawValue:
                statusEvent
                    .previousValue,
            newRawValue:
                statusEvent
                    .newValue
        )
    }


    private func statusTransitionText(
        previousRawValue:
            String?,
        newRawValue:
            String?
    ) -> String?
    {
        guard
            let newRawValue,
            let newStatus =
                TaskStatus(
                    rawValue:
                        newRawValue
                )
        else {
            return nil
        }


        guard
            let previousRawValue,
            let previousStatus =
                TaskStatus(
                    rawValue:
                        previousRawValue
                )
        else {
            return
                newStatus
                    .displayName
        }


        return
            "\(previousStatus.displayName) → \(newStatus.displayName)"
    }


    private func discontinuationReason(
        for event:
            HistoryEvent,
        item:
            WorkItem
    ) -> String?
    {
        if
            let text =
                event.text,
            let range =
                text.range(
                    of:
                        "discontinued — "
                )
        {
            let value =
                String(
                    text[
                        range.upperBound...
                    ]
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            if !value.isEmpty {
                return value
            }
        }


        if
            let currentDate =
                item.discontinuedAt,
            timestampsMatch(
                currentDate,
                event.timestamp
            )
        {
            return
                item
                    .discontinuationReason?
                    .displayName
        }


        return nil
    }


    private func discontinuationOutcome(
        for event:
            HistoryEvent,
        item:
            WorkItem
    ) -> String?
    {
        let eventOutcome =
            event.newValue?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if
            let eventOutcome,
            !eventOutcome.isEmpty
        {
            return eventOutcome
        }


        if
            let currentDate =
                item.discontinuedAt,
            timestampsMatch(
                currentDate,
                event.timestamp
            )
        {
            let currentOutcome =
                item
                    .discontinuationNote?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if
                let currentOutcome,
                !currentOutcome.isEmpty
            {
                return currentOutcome
            }
        }


        return nil
    }


    private func compactWorkDescription(
        _ item:
            WorkItem
    ) -> String?
    {
        let explicitTitle =
            item.title?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""


        // Without an explicit title, workTitle() already uses
        // the body as the visible title. Do not repeat it.
        guard !explicitTitle.isEmpty
        else {
            return nil
        }


        let normalized =
            item.body
                .split(
                    whereSeparator:
                        \.isWhitespace
                )
                .joined(
                    separator:
                        " "
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard !normalized.isEmpty
        else {
            return nil
        }


        let maximumLength =
            180


        if normalized.count
            <= maximumLength
        {
            return normalized
        }


        let prefix =
            normalized.prefix(
                maximumLength
            )

        return
            String(
                prefix
            )
            + "…"
    }


    // ========================================================
    // MARK: - App Log
    //
    // This is deliberately visually subordinate to Day Log.
    //
    // It contains every Work HistoryEvent currently recorded by
    // Testudo for the selected day rather than filtering out
    // edits, status changes or relationship changes.
    // ========================================================

    private var appHistoryEvents:
        [HistoryEvent]
    {
        let membershipID =
            store
                .currentEnvironmentMembership?
                .id

        return store.data.historyEvents
            .filter {
                event in

                guard
                    isInSelectedDay(
                        event.timestamp
                    )
                else {
                    return false
                }


                // Environment history predating membership audit
                // may have no actor. Preserve those entries.
                guard let membershipID
                else {
                    return true
                }

                return
                    event.actorMembershipID
                        == membershipID
                    || event.actorMembershipID
                        == nil
            }
            .sorted {
                lhs,
                rhs in

                if
                    lhs.timestamp
                        != rhs.timestamp
                {
                    return
                        lhs.timestamp
                        > rhs.timestamp
                }

                return
                    lhs.id.uuidString
                    > rhs.id.uuidString
            }
    }


    private var appLog:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Button {
                withAnimation(
                    .easeInOut(
                        duration: 0.16
                    )
                ) {
                    isAppLogExpanded
                        .toggle()
                }

            } label: {
                HStack(
                    spacing: 7
                ) {
                    Image(
                        systemName:
                            isAppLogExpanded
                            ? "chevron.down"
                            : "chevron.right"
                    )
                    .font(
                        .system(
                            size: 9,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .frame(
                        width: 12
                    )


                    Text(
                        "App Log"
                    )
                    .font(.subheadline)
                    .fontWeight(
                        .semibold
                    )
                    .foregroundStyle(
                        .secondary
                    )


                    if !appHistoryEvents.isEmpty {
                        Text(
                            "\(appHistoryEvents.count)"
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            .tertiary
                        )
                    }


                    Spacer()
                }
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .help(
                isAppLogExpanded
                ? "Collapse App Log"
                : "Expand App Log"
            )


            if isAppLogExpanded {
                if appHistoryEvents.isEmpty {
                    Text(
                        "No recorded Testudo actions for this day."
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .tertiary
                    )
                    .padding(
                        .leading,
                        19
                    )

                } else {
                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        ForEach(
                            appHistoryEvents
                        ) {
                            event in

                            appLogRow(
                                event
                            )
                        }
                    }
                    .padding(
                        .leading,
                        19
                    )
                    .transition(
                        .opacity
                    )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }


    private func appLogRow(
        _ event:
            HistoryEvent
    ) -> some View
    {
        let item =
            store.workItem(
                id:
                    event.workItemID
            )

        return HStack(
            alignment: .firstTextBaseline,
            spacing: 7
        ) {
            Text(
                event.timestamp
                    .formatted(
                        date:
                            .omitted,
                        time:
                            .shortened
                    )
            )
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(
                .tertiary
            )
            .frame(
                width: 45,
                alignment:
                    .leading
            )


            Image(
                systemName:
                    historyIcon(
                        event.kind
                    )
            )
            .font(
                .system(
                    size: 9
                )
            )
            .foregroundStyle(
                .tertiary
            )
            .frame(
                width: 12
            )


            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text(
                    event.text
                    ?? historyLabel(
                        event.kind
                    )
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )


                if let item {
                    Text(
                        workTitle(
                            item
                        )
                    )
                    .font(
                        .system(
                            size: 9
                        )
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                    .lineLimit(1)
                }
            }


            Spacer(
                minLength: 0
            )
        }
        .padding(
            .vertical,
            1
        )
        .contentShape(
            Rectangle()
        )
        .onTapGesture {
            if let item {
                selectWork(
                    item.id
                )
            }
        }
    }


    private func historyLabel(
        _ kind:
            HistoryEventKind
    ) -> String
    {
        switch kind {
        case .created:
            return "Created"

        case .edited:
            return "Edited"

        case .statusChanged:
            return "Status changed"

        case .scheduled:
            return "Scheduled"

        case .started:
            return "Started"

        case .completed:
            return "Completed"

        case .discontinued:
            return "Discontinued"

        case .closed:
            return "Closed"

        case .reopened:
            return "Reopened"

        case .activityLogged:
            return "Activity logged"

        case .relationshipAdded:
            return "Relationship added"

        case .relationshipRemoved:
            return "Relationship removed"

        case .moved:
            return "Moved"
        }
    }


    private func historyIcon(
        _ kind:
            HistoryEventKind
    ) -> String
    {
        switch kind {
        case .created:
            return "plus.circle"

        case .edited:
            return "pencil"

        case .statusChanged:
            return "arrow.triangle.2.circlepath"

        case .scheduled:
            return "calendar"

        case .started:
            return "play.circle"

        case .completed:
            return "checkmark.circle"

        case .discontinued:
            return "xmark.circle"

        case .closed:
            return "archivebox"

        case .reopened:
            return "arrow.uturn.backward.circle"

        case .activityLogged:
            return "waveform.path.ecg"

        case .relationshipAdded:
            return "link.badge.plus"

        case .relationshipRemoved:
            return "link.badge.minus"

        case .moved:
            return "arrow.turn.down.right"
        }
    }



    private func workTitle(
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
            return
                String(
                    body.prefix(
                        80
                    )
                )
        }

        return
            item.kind.displayName
    }


    private func selectWork(
        _ id: UUID
    ) {
        selectedCalendarEventID =
            nil

        selectedWorkItemID =
            id
    }
}
