import SwiftUI

struct WorkEntryCreationView: View {
    @EnvironmentObject
    private var store: DReportStore

    let request:
        WorkCreationRequest

    @Binding
    var workCreationRequest:
        WorkCreationRequest?

    @Binding
    var selectedWorkItemID:
        UUID?

    @State
    private var kind:
        WorkItemKind

    @State
    private var themeID:
        UUID?

    @State
    private var parentWorkItemID:
        UUID?

    @State
    private var title = ""

    @State
    private var bodyText = ""

    @State
    private var status:
        TaskStatus = .todo

    @State
    private var hasDeadline =
        false

    @State
    private var deadlineAt =
        Calendar.current.date(
            byAdding:
                .day,
            value:
                1,
            to:
                Date()
        )
        ?? Date()

    @State
    private var deadlineTimeZoneID =
        DReportTime
            .deviceTimeZoneID

    @State
    private var hasReminder =
        false

    @State
    private var reminderAt =
        Date()

    @State
    private var reminderTimeZoneID =
        DReportTime
            .deviceTimeZoneID

    @State
    private var occurredAt =
        Date()

    @State
    private var occurredTimeZoneID =
        DReportTime
            .deviceTimeZoneID

    @State
    private var relationships:
        [RelationshipDraft] = []

    @State
    private var errorMessage:
        String?

    private struct RelationshipDraft:
        Identifiable
    {
        let id =
            UUID()

        var role:
            WorkRelationshipRole =
            .relatedTo

        var entityID:
            UUID?

        var inheritedByChildren =
            true
    }

    init(
        request:
            WorkCreationRequest,
        workCreationRequest:
            Binding<WorkCreationRequest?>,
        selectedWorkItemID:
            Binding<UUID?>
    ) {
        self.request =
            request

        self._workCreationRequest =
            workCreationRequest

        self._selectedWorkItemID =
            selectedWorkItemID

        self._kind =
            State(
                initialValue:
                    request.initialKind
            )

        self._themeID =
            State(
                initialValue:
                    request.themeID
            )

        self._parentWorkItemID =
            State(
                initialValue:
                    request
                        .parentWorkItemID
            )
    }

    var body: some View {
        ZStack {
            DReportStyle
                .contentBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        28
                ) {
                    header

                    section(
                        title:
                            "Work"
                    ) {
                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                14
                        ) {
                            typeRow

                            themeRow

                            parentRow
                        }
                    }

                    section(
                        title:
                            "Content"
                    ) {
                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                12
                        ) {
                            TextField(
                                "Title (optional)",
                                text:
                                    $title
                            )

                            TextEditor(
                                text:
                                    $bodyText
                            )
                            .frame(
                                minHeight:
                                    150
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius:
                                        6
                                )
                                .stroke(
                                    Color.secondary
                                        .opacity(
                                            0.18
                                        )
                                )
                            }
                        }
                    }

                    timingSection

                    relationshipSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(
                                .red
                            )
                    }

                    actionBar
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
                    maxWidth:
                        760,
                    alignment:
                        .leading
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .center
                )
            }
        }
        .onAppear {
            synchroniseInitialParent()
        }
        .onChange(
            of:
                parentWorkItemID
        ) {
            _,
            newValue in

            guard
                let newValue,
                let parent =
                    store.workItem(
                        id:
                            newValue
                    )
            else {
                return
            }

            themeID =
                parent.themeID
        }
        .onChange(
            of:
                themeID
        ) {
            _,
            newValue in

            guard
                let parentWorkItemID,
                let parent =
                    store.workItem(
                        id:
                            parentWorkItemID
                    )
            else {
                return
            }

            if parent.themeID
                != newValue
            {
                self.parentWorkItemID =
                    nil
            }
        }
    }

    private var header:
        some View
    {
        HStack(
            alignment:
                .top,
            spacing:
                14
        ) {
            Image(
                systemName:
                    "square.and.pencil"
            )
            .font(.title2)
            .frame(width: 28)

            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(
                    "New Work Entry"
                )
                .font(.title2)
                .fontWeight(
                    .semibold
                )

                Text(
                    "Create a Task, Note or Event"
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
    }

    private var typeRow:
        some View
    {
        LabeledContent(
            "Type"
        ) {
            Picker(
                "",
                selection:
                    $kind
            ) {
                ForEach(
                    WorkItemKind
                        .allCases
                ) { candidate in
                    Text(
                        candidate
                            .displayName
                    )
                    .tag(candidate)
                }
            }
            .labelsHidden()
            .pickerStyle(
                .segmented
            )
            .frame(
                maxWidth:
                    330
            )
        }
    }

    private var themeRow:
        some View
    {
        LabeledContent(
            "Theme"
        ) {
            Picker(
                "",
                selection:
                    $themeID
            ) {
                Text("No Theme")
                    .tag(
                        Optional<UUID>
                            .none
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
            .labelsHidden()
            .frame(
                maxWidth:
                    320
            )
        }
    }

    private var parentRow:
        some View
    {
        LabeledContent(
            "Parent"
        ) {
            Picker(
                "",
                selection:
                    $parentWorkItemID
            ) {
                Text("No Parent")
                    .tag(
                        Optional<UUID>
                            .none
                    )

                ForEach(
                    availableParents
                ) { task in
                    Text(
                        parentLabel(
                            task
                        )
                    )
                    .tag(
                        Optional(
                            task.id
                        )
                    )
                }
            }
            .labelsHidden()
            .frame(
                maxWidth:
                    380
            )
        }
    }

    @ViewBuilder
    private var timingSection:
        some View
    {
        if kind == .task {
            section(
                title:
                    "Task"
            ) {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        14
                ) {
                    LabeledContent(
                        "Status"
                    ) {
                        Picker(
                            "",
                            selection:
                                $status
                        ) {
                            ForEach(
                                TaskStatus
                                    .allCases
                            ) { candidate in
                                Text(
                                    candidate
                                        .displayName
                                )
                                .tag(
                                    candidate
                                )
                            }
                        }
                        .labelsHidden()
                        .frame(
                            maxWidth:
                                240
                        )
                    }

                    Toggle(
                        "Deadline",
                        isOn:
                            $hasDeadline
                    )

                    if hasDeadline {
                        TimeZoneAwareDateEditor(
                            label:
                                "Due",
                            date:
                                $deadlineAt,
                            timeZoneID:
                                $deadlineTimeZoneID
                        )
                    }
                }
            }
        }

        if kind == .note {
            section(
                title:
                    "Note"
            ) {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        14
                ) {
                    Toggle(
                        "Reminder",
                        isOn:
                            $hasReminder
                    )

                    if hasReminder {
                        TimeZoneAwareDateEditor(
                            label:
                                "Remind",
                            date:
                                $reminderAt,
                            timeZoneID:
                                $reminderTimeZoneID
                        )
                    }
                }
            }
        }

        if kind == .activity {
            section(
                title:
                    "Event"
            ) {
                TimeZoneAwareDateEditor(
                    label:
                        "Occurred",
                    date:
                        $occurredAt,
                    timeZoneID:
                        $occurredTimeZoneID
                )
            }
        }
    }

    private var relationshipSection:
        some View
    {
        section(
            title:
                "Relationships"
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    12
            ) {
                if relationships
                    .isEmpty
                {
                    Text(
                        "No relationships"
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                }

                ForEach(
                    $relationships
                ) {
                    $relationship in

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            9
                    ) {
                        HStack(
                            spacing:
                                10
                        ) {
                            Picker(
                                "Role",
                                selection:
                                    $relationship.role
                            ) {
                                ForEach(
                                    WorkRelationshipRole
                                        .allCases
                                ) {
                                    role in

                                    Text(
                                        role
                                            .displayName
                                    )
                                    .tag(role)
                                }
                            }
                            .frame(
                                width:
                                    170
                            )

                            Picker(
                                "Entity",
                                selection:
                                    $relationship.entityID
                            ) {
                                Text(
                                    "Choose…"
                                )
                                .tag(
                                    Optional<UUID>
                                        .none
                                )

                                ForEach(
                                    sortedEntities
                                ) {
                                    entity in

                                    Text(
                                        entityLabel(
                                            entity
                                        )
                                    )
                                    .tag(
                                        Optional(
                                            entity.id
                                        )
                                    )
                                }
                            }
                            .frame(
                                maxWidth:
                                    320
                            )

                            Button(
                                role:
                                    .destructive
                            ) {
                                removeRelationship(
                                    relationship.id
                                )
                            } label: {
                                Image(
                                    systemName:
                                        "minus.circle"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Toggle(
                            "Inherited by child items",
                            isOn:
                                $relationship
                                    .inheritedByChildren
                        )
                        .font(.caption)
                    }
                    .padding(
                        .vertical,
                        4
                    )
                }

                Button {
                    relationships
                        .append(
                            RelationshipDraft()
                        )
                } label: {
                    Label(
                        "Add Relationship",
                        systemImage:
                            "plus"
                    )
                }
                .buttonStyle(
                    .borderless
                )
            }
        }
    }

    private var actionBar:
        some View
    {
        HStack {
            Spacer()

            Button(
                "Cancel"
            ) {
                workCreationRequest =
                    nil
            }

            Button(
                "Create"
            ) {
                create()
            }
            .keyboardShortcut(
                .defaultAction
            )
            .disabled(
                !canCreate
            )
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        title:
            String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            Text(title)
                .font(.headline)

            content()
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

    private var availableParents:
        [WorkItem]
    {
        store.data.workItems
            .filter {
                item in

                guard
                    item.kind
                        == .task
                else {
                    return false
                }

                if let themeID {
                    return
                        item.themeID
                        == themeID
                }

                return true
            }
            .sorted {
                parentLabel($0)
                    .localizedCaseInsensitiveCompare(
                        parentLabel($1)
                    )
                    == .orderedAscending
            }
    }

    private var sortedEntities:
        [Entity]
    {
        store.data.entities
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }

    private var canCreate:
        Bool
    {
        let hasText =
            !title
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
            || !bodyText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty

        let relationshipsValid =
            relationships.allSatisfy {
                $0.entityID != nil
            }

        return
            hasText
            && relationshipsValid
    }

    private func parentLabel(
        _ item:
            WorkItem
    ) -> String {
        let value =
            item.title?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let title =
            value?.isEmpty == false
            ? value!
            : (
                item.body.isEmpty
                ? "Untitled Task"
                : item.body
            )

        if
            let theme =
                store.theme(
                    id:
                        item.themeID
                )
        {
            return
                "\(title) — \(theme.name)"
        }

        return title
    }

    private func entityLabel(
        _ entity:
            Entity
    ) -> String {
        "\(entity.name) — \(entity.kind.rawValue.capitalized)"
    }

    private func removeRelationship(
        _ id:
            UUID
    ) {
        relationships
            .removeAll {
                $0.id == id
            }
    }

    private func synchroniseInitialParent() {
        guard
            let parentWorkItemID,
            let parent =
                store.workItem(
                    id:
                        parentWorkItemID
                )
        else {
            return
        }

        themeID =
            parent.themeID
    }

    private func create() {
        errorMessage =
            nil

        let effectiveThemeID =
            parentWorkItemID
                .flatMap {
                    store.workItem(
                        id:
                            $0
                    )?
                    .themeID
                }
            ?? themeID

        guard
            let newID =
                store.createWorkItem(
                    themeID:
                        effectiveThemeID,
                    parentWorkItemID:
                        parentWorkItemID,
                    kind:
                        kind,
                    title:
                        title,
                    body:
                        bodyText,
                    deadlineAt:
                        nil,
                    deadlineTimeZoneID:
                        nil
                )
        else {
            errorMessage =
                "Enter a title or description."
            return
        }

        let updateError =
            store
                .updateWorkItemDetails(
                    itemID:
                        newID,
                    title:
                        title,
                    body:
                        bodyText,
                    themeID:
                        effectiveThemeID,
                    parentWorkItemID:
                        parentWorkItemID,
                    status:
                        kind == .task
                        ? status
                        : nil,
                    deadlineAt:
                        kind == .task
                        && hasDeadline
                        ? deadlineAt
                        : nil,
                    reminderAt:
                        kind == .note
                        && hasReminder
                        ? reminderAt
                        : nil,
                    scheduledAt:
                        nil,
                    loggedAt:
                        kind == .activity
                        ? occurredAt
                        : nil,
                    deadlineTimeZoneID:
                        kind == .task
                        && hasDeadline
                        ? deadlineTimeZoneID
                        : nil,
                    reminderTimeZoneID:
                        kind == .note
                        && hasReminder
                        ? reminderTimeZoneID
                        : nil,
                    loggedTimeZoneID:
                        kind == .activity
                        ? occurredTimeZoneID
                        : nil
                )

        if let updateError {
            errorMessage =
                updateError
            return
        }

        for relationship
            in relationships
        {
            guard
                let entityID =
                    relationship.entityID
            else {
                continue
            }

            if
                let relationshipError =
                    store
                        .addWorkRelationship(
                            workItemID:
                                newID,
                            entityID:
                                entityID,
                            role:
                                relationship.role,
                            inheritedByChildren:
                                relationship
                                    .inheritedByChildren
                        )
            {
                errorMessage =
                    relationshipError
                return
            }
        }

        selectedWorkItemID =
            newID

        workCreationRequest =
            nil
    }
}
