import SwiftUI


// ============================================================
// MARK: - Existing New Entry entry point
//
// The router keeps using WorkEntryCreationView.
// Internally it now uses the exact same editor as existing
// Tasks / Notes / Activities.
// ============================================================

struct WorkEntryCreationView:
    View
{
    let request:
        WorkCreationRequest

    @Binding
    var workCreationRequest:
        WorkCreationRequest?

    @Binding
    var selectedWorkItemID:
        UUID?


    var body:
        some View
    {
        WorkEntryEditorView(
            request:
                request,
            workCreationRequest:
                $workCreationRequest,
            selectedWorkItemID:
                $selectedWorkItemID
        )
    }
}


// ============================================================
// MARK: - Shared Work Editor
// ============================================================

struct WorkEntryEditorView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.dismiss
    )
    private var dismiss


    private enum Mode
    {
        case create(
            WorkCreationRequest
        )

        case edit(
            UUID
        )
    }


    private let mode:
        Mode


    @Binding
    private var workCreationRequest:
        WorkCreationRequest?

    @Binding
    private var selectedWorkItemID:
        UUID?


    @State
    private var didLoad =
        false

    @State
    private var kind:
        WorkItemKind = .task

    @State
    private var themeIDs:
        Set<UUID> = []

    @State
    private var parentWorkItemID:
        UUID?

    @State
    private var originalParentWorkItemID:
        UUID?

    @State
    private var title =
        ""

    @State
    private var bodyText =
        ""

    @State
    private var status:
        TaskStatus = .todo


    // --------------------------------------------------------
    // Task lifecycle
    // --------------------------------------------------------

    @State
    private var hasStarted =
        false

    @State
    private var startedAt =
        Date()

    @State
    private var startedTimeZoneID =
        TestudoTime
            .deviceTimeZoneID

    @State
    private var hasDeadline =
        false

    @State
    private var deadlineAt =
        Calendar
            .autoupdatingCurrent
            .date(
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
        TestudoTime
            .deviceTimeZoneID

    @State
    private var discontinuedAt =
        Date()

    @State
    private var discontinuedTimeZoneID =
        TestudoTime
            .deviceTimeZoneID

    @State
    private var discontinuationReason:
        TaskDiscontinuationReason?

    @State
    private var discontinuationNote =
        ""


    // --------------------------------------------------------
    // Note
    // --------------------------------------------------------

    @State
    private var hasReminder =
        false

    @State
    private var reminderAt =
        Date()

    @State
    private var reminderTimeZoneID =
        TestudoTime
            .deviceTimeZoneID


    // --------------------------------------------------------
    // Activity / Event
    // --------------------------------------------------------

    @State
    private var occurredAt =
        Date()

    @State
    private var occurredTimeZoneID =
        TestudoTime
            .deviceTimeZoneID


    // --------------------------------------------------------
    // Relationships
    // --------------------------------------------------------

    @State
    private var relationships:
        [RelationshipDraft] = []

    @State
    private var errorMessage:
        String?

    @State
    private var showingParentRelationshipChoice =
        false

    @State
    private var pendingParentRelationshipSourceID:
        UUID?


    private struct RelationshipDraft:
        Identifiable
    {
        var id:
            UUID

        var existingRelationshipID:
            UUID?

        var role:
            WorkRelationshipRole

        var entityID:
            UUID?

        var inheritedByChildren:
            Bool


        init(
            id:
                UUID = UUID(),
            existingRelationshipID:
                UUID? = nil,
            role:
                WorkRelationshipRole = .relatedTo,
            entityID:
                UUID? = nil,
            inheritedByChildren:
                Bool = true
        ) {
            self.id =
                id

            self.existingRelationshipID =
                existingRelationshipID

            self.role =
                role

            self.entityID =
                entityID

            self.inheritedByChildren =
                inheritedByChildren
        }
    }


    // ========================================================
    // MARK: Initializers
    // ========================================================

    init(
        request:
            WorkCreationRequest,
        workCreationRequest:
            Binding<WorkCreationRequest?>,
        selectedWorkItemID:
            Binding<UUID?>
    ) {
        self.mode =
            .create(
                request
            )

        self._workCreationRequest =
            workCreationRequest

        self._selectedWorkItemID =
            selectedWorkItemID

        self._kind =
            State(
                initialValue:
                    request
                        .initialKind
            )

        self._themeIDs =
            State(
                initialValue:
                    Set(
                        request
                            .themeID
                            .map {
                                [$0]
                            }
                        ?? []
                    )
            )

        self._parentWorkItemID =
            State(
                initialValue:
                    request
                        .parentWorkItemID
            )
    }


    init(
        itemID:
            UUID,
        selectedWorkItemID:
            Binding<UUID?>
    ) {
        self.mode =
            .edit(
                itemID
            )

        self._workCreationRequest =
            .constant(
                nil
            )

        self._selectedWorkItemID =
            selectedWorkItemID
    }


    // ========================================================
    // MARK: Body
    // ========================================================

    @ViewBuilder
    var body:
        some View
    {
        if isEditing {
            editorBody
                .frame(
                    width:
                        860,
                    height:
                        780
                )
        } else {
            editorBody
        }
    }


    private var editorBody:
        some View
    {
        ZStack {
            TestudoStyle
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
                        contentFields
                    }

                    timingSection

                    relationshipSection

                    if let errorMessage {
                        Text(
                            errorMessage
                        )
                        .font(
                            .caption
                        )
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
            loadIfNeeded()
        }
        .onChange(
            of:
                parentWorkItemID
        ) {
            _,
            newValue in

            parentDidChange(
                newValue
            )
        }
        .onChange(
            of:
                themeIDs
        ) {
            _,
            newValue in

            themesDidChange(
                newValue
            )
        }
        .confirmationDialog(
            "Use Parent Relationships?",
            isPresented:
                $showingParentRelationshipChoice,
            titleVisibility:
                .visible
        ) {
            Button(
                "Copy Parent Relationships"
            ) {
                copyParentRelationshipsAndClose()
            }

            Button(
                "Keep Current Relationships"
            ) {
                pendingParentRelationshipSourceID =
                    nil

                dismiss()
            }
        } message: {
            Text(
                "The Parent Task has changed. Copying will replace this item's current related People, Groups and Organizations with the Parent's relationships marked “Inherited by child items”."
            )
        }
    }


    // ========================================================
    // MARK: Header
    // ========================================================

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
                    isEditing
                    ? editorIcon
                    : "square.and.pencil"
            )
            .font(
                .title2
            )
            .frame(
                width:
                    28
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(
                    editorTitle
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )

                Text(
                    editorSubtitle
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
    }


    private var editorTitle:
        String
    {
        if !isEditing {
            return
                "New Work Entry"
        }

        switch kind {
        case .task:
            return
                "Edit Task"

        case .note:
            return
                "Edit Note"

        case .activity:
            return
                "Edit Activity"
        }
    }


    private var editorSubtitle:
        String
    {
        if !isEditing {
            return
                "Create a Task, Note or Event"
        }

        return
            "Edit the complete \(kind.displayName.lowercased())"
    }


    private var editorIcon:
        String
    {
        switch kind {
        case .task:
            return
                "checkmark.circle"

        case .note:
            return
                "note.text"

        case .activity:
            return
                "waveform.path.ecg"
        }
    }


    // ========================================================
    // MARK: Type / Theme / Parent
    // ========================================================

    @ViewBuilder
    private var typeRow:
        some View
    {
        if isEditing {
            LabeledContent(
                "Type"
            ) {
                Text(
                    kind.displayName
                )
                .foregroundStyle(
                    .secondary
                )
            }
        } else {
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
                    ) {
                        candidate in

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
                .pickerStyle(
                    .segmented
                )
                .frame(
                    maxWidth:
                        330
                )
            }
        }
    }


    private var themeRow:
        some View
    {
        HierarchicalSelectionSummaryRow(
            label:
                "Themes",
            selectedTitles:
                selectedThemes
                    .map(
                        \.name
                    ),
            selectorTitle:
                "Themes",
            selectorMessage:
                "Choose one or more Themes from the existing Theme hierarchy.",
            nodes:
                HierarchySelectionData
                    .themeNodes(
                        store:
                            store
                    ),
            initialSelection:
                themeIDs,
            buttonSystemImage:
                "chevron.right",
            onSave: {
                selection in

                themeIDs =
                    selection

                return nil
            }
        )
    }


    private var parentRow:
        some View
    {
        let currentParent =
            parentWorkItemID
                .flatMap {
                    store.workItem(
                        id:
                            $0
                    )
                }

        return
            HierarchicalSelectionSummaryRow(
                label:
                    "Parent",
                selectedTitles:
                    currentParent
                        .map {
                            [
                                displayTitle(
                                    $0
                                )
                            ]
                        }
                    ?? [],
                selectorTitle:
                    "Parent Task",
                selectorMessage:
                    "Choose a Parent Task. The current item and its descendants cannot become its Parent.",
                nodes:
                    HierarchySelectionData
                        .taskNodes(
                            store:
                                store,
                            excludingWorkItemIDs:
                                excludedParentIDs,
                            themeID:
                                primaryThemeID
                        ),
                initialSelection:
                    Set(
                        currentParent
                            .map {
                                [$0.id]
                            }
                        ?? []
                    ),
                buttonSystemImage:
                    "chevron.right",
                maximumSelectionCount:
                    1,
                onSave: {
                    selection in

                    parentWorkItemID =
                        selection.first

                    return nil
                }
            )
    }


    // ========================================================
    // MARK: Content
    // ========================================================

    private var contentFields:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                16
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    7
            ) {
                Text(
                    "Title"
                )
                .font(
                    .caption
                        .weight(
                            .medium
                        )
                )
                .foregroundStyle(
                    .secondary
                )

                TextField(
                    "Optional title",
                    text:
                        $title
                )
                .textFieldStyle(
                    .plain
                )
                .padding(
                    .horizontal,
                    11
                )
                .frame(
                    height:
                        36
                )
                .background(
                    Color(
                        nsColor:
                            .textBackgroundColor
                    ),
                    in:
                        RoundedRectangle(
                            cornerRadius:
                                8,
                            style:
                                .continuous
                        )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius:
                            8,
                        style:
                            .continuous
                    )
                    .stroke(
                        Color.primary
                            .opacity(
                                0.12
                            ),
                        lineWidth:
                            1
                    )
                }
            }

            VStack(
                alignment:
                    .leading,
                spacing:
                    7
            ) {
                Text(
                    kind == .note
                    ? "Note"
                    : (
                        kind == .activity
                        ? "What happened?"
                        : "Description"
                    )
                )
                .font(
                    .caption
                        .weight(
                            .medium
                        )
                )
                .foregroundStyle(
                    .secondary
                )

                TextEditor(
                    text:
                        $bodyText
                )
                .font(
                    .body
                )
                .scrollContentBackground(
                    .hidden
                )
                .padding(
                    8
                )
                .frame(
                    minHeight:
                        120
                )
                .background(
                    Color(
                        nsColor:
                            .textBackgroundColor
                    ),
                    in:
                        RoundedRectangle(
                            cornerRadius:
                                10,
                            style:
                                .continuous
                        )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius:
                            10,
                        style:
                            .continuous
                    )
                    .stroke(
                        Color.primary
                            .opacity(
                                0.12
                            ),
                        lineWidth:
                            1
                    )
                }
            }
        }
    }


    // ========================================================
    // MARK: Timing
    // ========================================================

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
                            ) {
                                candidate in

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

                    if status == .discontinued {
                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                12
                        ) {
                            LabeledContent(
                                "Reason"
                            ) {
                                Picker(
                                    "",
                                    selection:
                                        $discontinuationReason
                                ) {
                                    Text(
                                        "Choose…"
                                    )
                                    .tag(
                                        Optional<
                                            TaskDiscontinuationReason
                                        >
                                        .none
                                    )

                                    ForEach(
                                        TaskDiscontinuationReason
                                            .allCases
                                    ) {
                                        reason in

                                        Text(
                                            reason
                                                .displayName
                                        )
                                        .tag(
                                            Optional(
                                                reason
                                            )
                                        )
                                    }
                                }
                                .labelsHidden()
                                .frame(
                                    maxWidth:
                                        260
                                )
                            }

                            TimeZoneAwareDateEditor(
                                label:
                                    "Discontinued",
                                date:
                                    $discontinuedAt,
                                timeZoneID:
                                    $discontinuedTimeZoneID
                            )

                            LabeledContent(
                                "Outcome / note"
                            ) {
                                TextField(
                                    "Optional explanation",
                                    text:
                                        $discontinuationNote
                                )
                                .textFieldStyle(
                                    .roundedBorder
                                )
                                .frame(
                                    maxWidth:
                                        420
                                )
                            }
                        }
                    }

                    Toggle(
                        "Started",
                        isOn:
                            $hasStarted
                    )

                    if hasStarted {
                        TimeZoneAwareDateEditor(
                            label:
                                "Started",
                            date:
                                $startedAt,
                            timeZoneID:
                                $startedTimeZoneID
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
                    "Activity"
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


    // ========================================================
    // MARK: Relationships
    // ========================================================

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
                if relationships.isEmpty {
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
                                    $relationship
                                        .role
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
                                    .tag(
                                        role
                                    )
                                }
                            }
                            .frame(
                                width:
                                    170
                            )

                            Picker(
                                "Entity",
                                selection:
                                    $relationship
                                        .entityID
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
                            .buttonStyle(
                                .plain
                            )
                        }

                        Toggle(
                            "Inherited by child items",
                            isOn:
                                $relationship
                                    .inheritedByChildren
                        )
                        .font(
                            .caption
                        )
                    }
                    .padding(
                        .vertical,
                        4
                    )
                }

                Button {
                    relationships.append(
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


    // ========================================================
    // MARK: Actions
    // ========================================================

    private var actionBar:
        some View
    {
        HStack {
            Spacer()

            Button(
                "Cancel"
            ) {
                cancel()
            }
            .keyboardShortcut(
                .cancelAction
            )

            Button(
                isEditing
                ? "Save"
                : "Create"
            ) {
                save()
            }
            .buttonStyle(
                .borderedProminent
            )
            .keyboardShortcut(
                .defaultAction
            )
            .disabled(
                !canSave
            )
        }
    }


    // ========================================================
    // MARK: Section shell
    // ========================================================

    @ViewBuilder
    private func section<
        Content:
            View
    >(
        title:
            String,
        @ViewBuilder
        content:
            () -> Content
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {
            Text(
                title
            )
            .font(
                .headline
            )

            content()
        }
        .padding(
            16
        )
        .background(
            Color.primary
                .opacity(
                    0.025
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        12,
                    style:
                        .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    12,
                style:
                    .continuous
            )
            .stroke(
                Color.primary
                    .opacity(
                        0.06
                    ),
                lineWidth:
                    1
            )
        }
    }


    // ========================================================
    // MARK: Loading
    // ========================================================

    private func loadIfNeeded() {
        guard !didLoad
        else {
            return
        }

        didLoad =
            true

        switch mode {
        case .create:
            synchroniseInitialParent()

        case
            .edit(
                let itemID
            ):

            guard
                let item =
                    store.workItem(
                        id:
                            itemID
                    )
            else {
                errorMessage =
                    "Work item not found."

                return
            }

            kind =
                item.kind

            title =
                item.title
                ?? ""

            bodyText =
                item.body

            themeIDs =
                Set(
                    store
                        .workThemes(
                            for:
                                item.id
                        )
                        .map(
                            \.id
                        )
                )

            parentWorkItemID =
                item.parentWorkItemID

            originalParentWorkItemID =
                item.parentWorkItemID

            status =
                item.status
                ?? .todo

            hasStarted =
                item.startedAt
                != nil

            startedAt =
                item.startedAt
                ?? Date()

            startedTimeZoneID =
                TestudoTime
                    .validTimeZoneIdentifier(
                        item
                            .startedTimeZoneID
                    )
                ?? TestudoTime
                    .deviceTimeZoneID

            hasDeadline =
                item.deadlineAt
                != nil

            deadlineAt =
                item.deadlineAt
                ?? (
                    Calendar
                        .autoupdatingCurrent
                        .date(
                            byAdding:
                                .day,
                            value:
                                1,
                            to:
                                Date()
                        )
                    ?? Date()
                )

            deadlineTimeZoneID =
                TestudoTime
                    .validTimeZoneIdentifier(
                        item
                            .deadlineTimeZoneID
                    )
                ?? TestudoTime
                    .deviceTimeZoneID

            discontinuedAt =
                item.discontinuedAt
                ?? Date()

            discontinuedTimeZoneID =
                TestudoTime
                    .validTimeZoneIdentifier(
                        item
                            .discontinuedTimeZoneID
                    )
                ?? TestudoTime
                    .deviceTimeZoneID

            discontinuationReason =
                item.discontinuationReason

            discontinuationNote =
                item.discontinuationNote
                ?? ""

            hasReminder =
                item.reminderAt
                != nil

            reminderAt =
                item.reminderAt
                ?? Date()

            reminderTimeZoneID =
                TestudoTime
                    .validTimeZoneIdentifier(
                        item
                            .reminderTimeZoneID
                    )
                ?? TestudoTime
                    .deviceTimeZoneID

            occurredAt =
                item.loggedAt
                ?? item.createdAt

            occurredTimeZoneID =
                TestudoTime
                    .validTimeZoneIdentifier(
                        item
                            .loggedTimeZoneID
                    )
                ?? TestudoTime
                    .deviceTimeZoneID

            relationships =
                store.data
                    .workEntityRelationships
                    .filter {
                        $0.workItemID
                            == item.id
                    }
                    .sorted {
                        left,
                        right in

                        if left.role
                            == right.role
                        {
                            return
                                entityName(
                                    left.entityID
                                )
                                .localizedCaseInsensitiveCompare(
                                    entityName(
                                        right.entityID
                                    )
                                )
                                == .orderedAscending
                        }

                        return
                            left.role.rawValue
                            < right.role.rawValue
                    }
                    .map {
                        relationship in

                        RelationshipDraft(
                            id:
                                relationship.id,
                            existingRelationshipID:
                                relationship.id,
                            role:
                                relationship.role,
                            entityID:
                                relationship
                                    .entityID,
                            inheritedByChildren:
                                relationship
                                    .inheritedByChildren
                        )
                    }
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

        let parentThemeIDs =
            Set(
                store
                    .workThemes(
                        for:
                            parent.id
                    )
                    .map(
                        \.id
                    )
            )

        themeIDs.formUnion(
            parentThemeIDs
        )
    }


    private func parentDidChange(
        _ newValue:
            UUID?
    ) {
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

        let parentThemeIDs =
            Set(
                store
                    .workThemes(
                        for:
                            parent.id
                    )
                    .map(
                        \.id
                    )
            )

        themeIDs.formUnion(
            parentThemeIDs
        )
    }


    private func themesDidChange(
        _ newValue:
            Set<UUID>
    ) {
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

        let parentThemeIDs =
            Set(
                store
                    .workThemes(
                        for:
                            parent.id
                    )
                    .map(
                        \.id
                    )
            )

        if
            !parentThemeIDs.isEmpty,
            !parentThemeIDs
                .isSubset(
                    of:
                        newValue
                )
        {
            self.parentWorkItemID =
                nil
        }
    }


    // ========================================================
    // MARK: Save
    // ========================================================

    private func save() {
        errorMessage =
            nil

        if
            let validationError =
                validateDraft()
        {
            errorMessage =
                validationError

            return
        }

        switch mode {
        case .create:
            createNewItem()

        case
            .edit(
                let itemID
            ):
            saveExistingItem(
                itemID:
                    itemID
            )
        }
    }


    private func createNewItem() {
        guard
            let newID =
                store.createWorkItem(
                    themeID:
                        primaryThemeID,
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
                        primaryThemeID,
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
            failNewItem(
                newID,
                error:
                    updateError
            )

            return
        }

        if
            let themeError =
                store
                    .setWorkThemes(
                        workItemID:
                            newID,
                        themeIDs:
                            themeIDs
                    )
        {
            failNewItem(
                newID,
                error:
                    themeError
            )

            return
        }

        if
            kind == .task,
            hasStarted
        {
            if
                let startedError =
                    store
                        .updateTaskStartedAt(
                            workItemID:
                                newID,
                            startedAt:
                                startedAt,
                            startedTimeZoneID:
                                startedTimeZoneID,
                            recordAudit:
                                false
                        )
            {
                failNewItem(
                    newID,
                    error:
                        startedError
                )

                return
            }
        }

        if
            kind == .task,
            status == .discontinued,
            let discontinuationReason
        {
            if
                let discontinuedError =
                    store
                        .updateTaskDiscontinuationDetails(
                            workItemID:
                                newID,
                            discontinuedAt:
                                discontinuedAt,
                            discontinuedTimeZoneID:
                                discontinuedTimeZoneID,
                            reason:
                                discontinuationReason,
                            note:
                                discontinuationNote,
                            recordAudit:
                                false
                        )
            {
                failNewItem(
                    newID,
                    error:
                        discontinuedError
                )

                return
            }
        }

        if
            let relationshipError =
                addNewRelationships(
                    to:
                        newID
                )
        {
            failNewItem(
                newID,
                error:
                    relationshipError
            )

            return
        }

        if
            kind == .task,
            let parentWorkItemID
        {
            if
                let inheritanceError =
                    store
                        .copyInheritedWorkRelationships(
                            fromParentTaskID:
                                parentWorkItemID,
                            toWorkItemID:
                                newID,
                            replacingExisting:
                                false
                        )
            {
                failNewItem(
                    newID,
                    error:
                        inheritanceError
                )

                return
            }
        }

        selectedWorkItemID =
            newID

        workCreationRequest =
            nil
    }


    private func saveExistingItem(
        itemID:
            UUID
    ) {
        guard
            let item =
                store.workItem(
                    id:
                        itemID
                )
        else {
            errorMessage =
                "Work item not found."

            return
        }

        let previousParentID =
            item.parentWorkItemID

        let updateError =
            store
                .updateWorkItemDetails(
                    itemID:
                        item.id,
                    title:
                        title,
                    body:
                        bodyText,
                    themeID:
                        primaryThemeID,
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
                        : item.loggedAt,
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
                        : item.loggedTimeZoneID
                )

        if let updateError {
            errorMessage =
                updateError

            return
        }

        if
            let themeError =
                store
                    .setWorkThemes(
                        workItemID:
                            item.id,
                        themeIDs:
                            themeIDs
                    )
        {
            errorMessage =
                themeError

            return
        }

        if kind == .task {
            // Started has two sources:
            //
            // 1. A manual value from this editor.
            // 2. The automatic timestamp generated by the Store
            //    when a Task transitions into In Progress.
            //
            // If this Task previously had no Started value and
            // the user leaves the Started toggle disabled, do
            // NOT write nil after updateWorkItemDetails(). That
            // would erase a Started timestamp that may just have
            // been generated by To Do -> In Progress.
            //
            // We only clear Started when the Task already had
            // one when the editor opened and the user has now
            // disabled it.

            let shouldWriteStarted =
                hasStarted
                || item.startedAt != nil

            if shouldWriteStarted {
                if
                    let startedError =
                        store
                            .updateTaskStartedAt(
                                workItemID:
                                    item.id,
                                startedAt:
                                    hasStarted
                                    ? startedAt
                                    : nil,
                                startedTimeZoneID:
                                    hasStarted
                                    ? startedTimeZoneID
                                    : nil
                            )
                {
                    errorMessage =
                        startedError

                    return
                }
            }
        }

        if
            kind == .task,
            status == .discontinued,
            let discontinuationReason
        {
            if
                let discontinuedError =
                    store
                        .updateTaskDiscontinuationDetails(
                            workItemID:
                                item.id,
                            discontinuedAt:
                                discontinuedAt,
                            discontinuedTimeZoneID:
                                discontinuedTimeZoneID,
                            reason:
                                discontinuationReason,
                            note:
                                discontinuationNote
                        )
            {
                errorMessage =
                    discontinuedError

                return
            }
        }

        if
            let relationshipError =
                syncExistingRelationships(
                    for:
                        item.id
                )
        {
            errorMessage =
                relationshipError

            return
        }

        if
            kind == .task,
            let newParentID =
                parentWorkItemID,
            newParentID
                != previousParentID
        {
            pendingParentRelationshipSourceID =
                newParentID

            showingParentRelationshipChoice =
                true

            return
        }

        originalParentWorkItemID =
            parentWorkItemID

        dismiss()
    }


    // ========================================================
    // MARK: Relationship persistence
    // ========================================================

    private func addNewRelationships(
        to workItemID:
            UUID
    ) -> String? {
        for draft in relationships {
            guard
                let entityID =
                    draft.entityID
            else {
                continue
            }

            if
                let error =
                    store
                        .addWorkRelationship(
                            workItemID:
                                workItemID,
                            entityID:
                                entityID,
                            role:
                                draft.role,
                            inheritedByChildren:
                                draft
                                    .inheritedByChildren
                        )
            {
                return error
            }
        }

        return nil
    }


    private func syncExistingRelationships(
        for workItemID:
            UUID
    ) -> String? {
        let existing =
            store.data
                .workEntityRelationships
                .filter {
                    $0.workItemID
                        == workItemID
                }

        let existingByID =
            Dictionary(
                uniqueKeysWithValues:
                    existing.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )

        let retainedIDs =
            Set(
                relationships
                    .compactMap(
                        \.existingRelationshipID
                    )
            )

        for draft in relationships {
            guard
                let existingID =
                    draft
                        .existingRelationshipID
            else {
                continue
            }

            guard
                existingByID[
                    existingID
                ] != nil
            else {
                return
                    "A relationship changed while the editor was open."
            }

            guard
                let entityID =
                    draft.entityID
            else {
                return
                    "Choose an entity for every relationship."
            }

            if
                let error =
                    store
                        .updateWorkRelationshipDetails(
                            relationshipID:
                                existingID,
                            entityID:
                                entityID,
                            role:
                                draft.role,
                            inheritedByChildren:
                                draft
                                    .inheritedByChildren
                        )
            {
                return error
            }
        }

        for relationship in existing
        where
            !retainedIDs
                .contains(
                    relationship.id
                )
        {
            store
                .removeWorkRelationship(
                    relationshipID:
                        relationship.id
                )
        }

        for draft in relationships
        where
            draft
                .existingRelationshipID
                == nil
        {
            guard
                let entityID =
                    draft.entityID
            else {
                return
                    "Choose an entity for every relationship."
            }

            if
                let error =
                    store
                        .addWorkRelationship(
                            workItemID:
                                workItemID,
                            entityID:
                                entityID,
                            role:
                                draft.role,
                            inheritedByChildren:
                                draft
                                    .inheritedByChildren
                        )
            {
                return error
            }
        }

        return nil
    }


    // ========================================================
    // MARK: Validation
    // ========================================================

    private func validateDraft()
        -> String?
    {
        let cleanedTitle =
            title.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let cleanedBody =
            bodyText.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        if
            cleanedTitle.isEmpty,
            cleanedBody.isEmpty
        {
            return
                "Enter a title or description."
        }

        if
            kind == .task,
            hasStarted,
            startedAt > Date()
        {
            return
                "Started date cannot be in the future."
        }

        if
            kind == .task,
            status == .discontinued
        {
            guard
                discontinuationReason
                    != nil
            else {
                return
                    "Choose a reason for discontinuing this Task."
            }

            if discontinuedAt > Date() {
                return
                    "Discontinued date cannot be in the future."
            }

            if
                hasStarted,
                discontinuedAt < startedAt
            {
                return
                    "Discontinued date cannot be earlier than Started."
            }
        }

        var relationshipKeys =
            Set<String>()

        for draft in relationships {
            guard
                let entityID =
                    draft.entityID
            else {
                return
                    "Choose an entity for every relationship."
            }

            guard
                store.entity(
                    id:
                        entityID
                ) != nil
            else {
                return
                    "A related entity no longer exists."
            }

            let key =
                "\(draft.role.rawValue)|\(entityID.uuidString)"

            guard
                relationshipKeys
                    .insert(
                        key
                    )
                    .inserted
            else {
                return
                    "The same relationship is listed more than once."
            }
        }

        return nil
    }


    // ========================================================
    // MARK: Parent relationship decision
    // ========================================================

    private func copyParentRelationshipsAndClose() {
        guard
            let parentID =
                pendingParentRelationshipSourceID
        else {
            dismiss()

            return
        }

        let error =
            store
                .copyInheritedWorkRelationships(
                    fromParentTaskID:
                        parentID,
                    toWorkItemID:
                        editingItemID
                        ?? UUID(),
                    replacingExisting:
                        true
                )

        if let error {
            errorMessage =
                error

            showingParentRelationshipChoice =
                false

            return
        }

        pendingParentRelationshipSourceID =
            nil

        dismiss()
    }


    // ========================================================
    // MARK: Helpers
    // ========================================================

    private var isEditing:
        Bool
    {
        switch mode {
        case .create:
            return false

        case .edit:
            return true
        }
    }


    private var editingItemID:
        UUID?
    {
        switch mode {
        case .create:
            return nil

        case
            .edit(
                let id
            ):
            return id
        }
    }


    private var canSave:
        Bool
    {
        !title
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        ||
        !bodyText
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
    }


    private var selectedThemes:
        [Theme]
    {
        store.data.themes
            .filter {
                themeIDs
                    .contains(
                        $0.id
                    )
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }


    private var primaryThemeID:
        UUID?
    {
        selectedThemes
            .first?
            .id
    }


    private var excludedParentIDs:
        Set<UUID>
    {
        guard
            let itemID =
                editingItemID
        else {
            return []
        }

        return
            Set(
                store
                    .workItemDescendantIDs(
                        of:
                            itemID
                    )
            )
            .union(
                [
                    itemID
                ]
            )
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


    private func entityLabel(
        _ entity:
            Entity
    ) -> String {
        "\(entity.name) · \(entity.kind.displayName)"
    }


    private func entityName(
        _ id:
            UUID
    ) -> String {
        store.entity(
            id:
                id
        )?
        .name
        ?? "Unknown"
    }


    private func displayTitle(
        _ item:
            WorkItem
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
            item.kind
                .displayName
    }


    private func removeRelationship(
        _ id:
            UUID
    ) {
        relationships.removeAll {
            $0.id
                == id
        }
    }


    private func failNewItem(
        _ id:
            UUID,
        error:
            String
    ) {
        store.deleteWorkItem(
            id:
                id
        )

        errorMessage =
            error
    }


    private func cancel() {
        if isEditing {
            dismiss()
        } else {
            workCreationRequest =
                nil
        }
    }
}
