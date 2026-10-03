import SwiftUI


// ============================================================
// MARK: - Shared Rich Inspector Components
// ============================================================

private struct StructureInspectorSection<
    Content: View
>: View {
    let title: String

    @ViewBuilder
    let content: () -> Content

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(title)
                .font(.headline)

            content()
        }
    }
}


private struct StructureEditButton:
    View
{
    let action: () -> Void

    var body: some View {
        Button(
            action:
                action
        ) {
            Image(
                systemName:
                    "pencil"
            )
            .font(
                .system(
                    size: 10,
                    weight:
                        .medium
                )
            )
            .foregroundStyle(
                .tertiary
            )
            .frame(
                width: 20,
                height: 20
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
    }
}


private struct StructureEditActions:
    View
{
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button(
                "Cancel",
                action:
                    onCancel
            )

            Button(
                "Save",
                action:
                    onSave
            )
            .keyboardShortcut(
                .defaultAction
            )
        }
        .buttonStyle(
            .borderless
        )
    }
}


private struct StructureValueRow:
    View
{
    @Environment(
        \.testudoDetailNavigation
    )
    private var detailNavigation

    let label: String
    let value: String

    var navigationDestination:
        TestudoDetailDestination? =
            nil

    let onEdit: () -> Void

    var body: some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing:
                14
        ) {

            Text(
                label
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width:
                    120,
                alignment:
                    .leading
            )


            if
                let navigationDestination
            {
                Button {
                    detailNavigation(
                        navigationDestination
                    )
                } label: {
                    Text(
                        value.isEmpty
                        ? "None"
                        : value
                    )
                    .foregroundStyle(
                        value.isEmpty
                        ? .tertiary
                        : .primary
                    )
                }
                .buttonStyle(
                    .plain
                )
                .help(
                    "Open \(value)"
                )

            } else {
                Text(
                    value.isEmpty
                    ? "None"
                    : value
                )
                .foregroundStyle(
                    value.isEmpty
                    ? .tertiary
                    : .primary
                )
                .textSelection(
                    .enabled
                )
            }


            Spacer()


            StructureEditButton(
                action:
                    onEdit
            )
        }
        .font(
            .callout
        )
    }
}


private struct StructureReadOnlyRow:
    View
{
    let label: String
    let value: String

    var body: some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing: 14
        ) {
            Text(label)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 120,
                    alignment:
                        .leading
                )

            Text(value)
                .textSelection(
                    .enabled
                )

            Spacer()
        }
        .font(.callout)
    }
}


private struct OrganizationDetailCardModifier:
    ViewModifier
{
    let enabled:
        Bool

    @ViewBuilder
    func body(
        content:
            Content
    ) -> some View {
        if enabled {
            content
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

        } else {
            content
        }
    }
}


private extension View {

    func organizationDetailCard(
        _ enabled:
            Bool
    ) -> some View {
        modifier(
            OrganizationDetailCardModifier(
                enabled:
                    enabled
            )
        )
    }
}


// ============================================================
// MARK: - Rich Theme Inspector
// ============================================================

struct RichThemeDetailView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let themeID: UUID

    private let detailDeleteFooter:
        AnyView


    init<DeleteFooter: View>(
        themeID: UUID,
        @ViewBuilder
        deleteFooter:
            () -> DeleteFooter
    ) {
        self.themeID =
            themeID

        self.detailDeleteFooter =
            AnyView(
                deleteFooter()
            )
    }

    @State
    private var editingField:
        EditableField?

    @State
    private var textDraft =
        ""

    @State
    private var uuidDraft:
        UUID?

    @State
    private var statusDraft:
        StructureStatus =
        .active

    @State
    private var priorityDraft:
        StructurePriority =
        .normal

    @State
    private var dateDraft =
        Date()

    @State
    private var dateEnabledDraft =
        true

    @State
    private var errorMessage:
        String?

    private enum EditableField:
        Hashable
    {
        case name
        case parent
        case summary
        case notes
        case code
        case status
        case priority
        case owner
        case startDate
        case targetDate
        case tags
        case url
        case symbol
    }


    var body: some View {
        ZStack {
            TestudoStyle
                .contentBackground
                .ignoresSafeArea()

            if
                let theme =
                    store.theme(
                        id:
                            themeID
                    )
            {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 26
                    ) {
                        header(theme)

                        StructureInspectorSection(
                            title:
                                "Classification"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                parentRow(theme)
                                statusRow(theme)
                                priorityRow(theme)
                                ownerRow(theme)

                                textRow(
                                    theme,
                                    label:
                                        "Code",
                                    value:
                                        theme.code,
                                    field:
                                        .code
                                )
                            }
                        }

                        StructureInspectorSection(
                            title:
                                "Description"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                textRow(
                                    theme,
                                    label:
                                        "Summary",
                                    value:
                                        theme.summary,
                                    field:
                                        .summary
                                )

                                textRow(
                                    theme,
                                    label:
                                        "Notes",
                                    value:
                                        theme.notes,
                                    field:
                                        .notes,
                                    multiline:
                                        true
                                )
                            }
                        }

                        relatedEntitiesSection(
                            theme
                        )

                        StructureInspectorSection(
                            title:
                                "Schedule"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                dateRow(
                                    theme,
                                    label:
                                        "Start",
                                    value:
                                        theme.startDate,
                                    field:
                                        .startDate
                                )

                                dateRow(
                                    theme,
                                    label:
                                        "Target",
                                    value:
                                        theme.targetDate,
                                    field:
                                        .targetDate
                                )
                            }
                        }

                        StructureInspectorSection(
                            title:
                                "Metadata"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                textRow(
                                    theme,
                                    label:
                                        "Tags",
                                    value:
                                        theme.tags,
                                    field:
                                        .tags
                                )

                                textRow(
                                    theme,
                                    label:
                                        "URL",
                                    value:
                                        theme.url,
                                    field:
                                        .url
                                )

                                textRow(
                                    theme,
                                    label:
                                        "SF Symbol",
                                    value:
                                        theme.symbolName,
                                    field:
                                        .symbol
                                )
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(
                                    .red
                                )
                        }

                        StructureInspectorSection(
                            title:
                                "History"
                        ) {
                            VStack(
                                spacing: 9
                            ) {
                                StructureReadOnlyRow(
                                    label:
                                        "Created",
                                    value:
                                        TestudoTime
                                            .dateTime(
                                                theme.createdAt
                                            )
                                )

                                StructureReadOnlyRow(
                                    label:
                                        "Updated",
                                    value:
                                        TestudoTime
                                            .dateTime(
                                                theme.updatedAt
                                            )
                                )
                            }
                        }

                        // DETAIL DELETE FOOTER
                        HStack {
                            Spacer()

                            detailDeleteFooter

                            Spacer()
                        }
                        .padding(.top, 8)
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
                        28
                    )
                    .frame(
                        maxWidth: 760,
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
            } else {
                ContentUnavailableView(
                    "Theme Not Found",
                    systemImage:
                        "folder.badge.questionmark"
                )
            }
        }
    }


    @ViewBuilder
    private func relatedEntitiesSection(
        _ theme: Theme
    ) -> some View {
        let current =
            store.relatedEntities(
                forThemeID:
                    theme.id
            )

        return StructureInspectorSection(
            title:
                "Related People, Groups & Organizations"
        ) {
            EntitySelectionSummaryRow(
                label:
                    "Related",
                selectedIDs:
                    Set(
                        current.map(
                            \.id
                        )
                    ),
                tabs:
                    [
                        .people,
                        .groups,
                        .organizations
                    ],
                selectorTitle:
                    "Related People, Groups & Organizations",
                selectorMessage:
                    "Choose People, Groups or Organizations related to this Theme. Existing relationships remain visible in Selected at the top.",
                emptyText:
                    "None",
                buttonSystemImage:
                    "pencil",
                onSave: {
                    selection in

                    store
                        .setThemeRelatedEntities(
                            themeID:
                                theme.id,
                            entityIDs:
                                selection
                        )
                }
            )
        }
    }


    private func header(
        _ theme: Theme
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName:
                    theme.symbolName
                        ?? "folder"
            )
            .font(.title2)
            .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                if editingField == .name {
                    TextField(
                        "Theme name",
                        text:
                            $textDraft
                    )
                    .font(.title2)

                    StructureEditActions(
                        onCancel:
                            cancelEdit,
                        onSave: {
                            saveText(
                                theme,
                                field:
                                    .name
                            )
                        }
                    )
                } else {
                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 8
                    ) {
                        Text(theme.name)
                            .font(.title2)
                            .fontWeight(
                                .semibold
                            )

                        StructureEditButton {
                            beginText(
                                .name,
                                value:
                                    theme.name
                            )
                        }
                    }
                }

                Text("Theme")
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()
        }
    }


    @ViewBuilder
    private func textRow(
        _ theme: Theme,
        label: String,
        value: String?,
        field: EditableField,
        multiline: Bool = false
    ) -> some View {
        if editingField == field {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                if multiline {
                    TextEditor(
                        text:
                            $textDraft
                    )
                    .frame(
                        minHeight: 90
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 6
                        )
                        .stroke(
                            Color.secondary
                                .opacity(0.15)
                        )
                    }
                } else {
                    TextField(
                        label,
                        text:
                            $textDraft
                    )
                }

                StructureEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveText(
                            theme,
                            field:
                                field
                        )
                    }
                )
            }
        } else {
            StructureValueRow(
                label:
                    label,
                value:
                    value ?? "",
                onEdit: {
                    beginText(
                        field,
                        value:
                            value ?? ""
                    )
                }
            )
        }
    }


    @ViewBuilder
    private func parentRow(
        _ theme: Theme
    ) -> some View {
        if editingField == .parent {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Picker(
                    "Parent",
                    selection:
                        $uuidDraft
                ) {
                    Text("None")
                        .tag(
                            Optional<UUID>.none
                        )

                    ForEach(
                        availableParents(
                            theme
                        )
                    ) { candidate in
                        Text(candidate.name)
                            .tag(
                                Optional(
                                    candidate.id
                                )
                            )
                    }
                }

                StructureEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        var updated =
                            theme

                        updated.parentThemeID =
                            uuidDraft

                        finish(
                            store.saveThemeMetadata(
                                updated
                            )
                        )
                    }
                )
            }
        } else {
            StructureValueRow(
                label:
                    "Parent",
                value:
                    store.theme(
                        id:
                            theme.parentThemeID
                    )?.name
                    ?? "None",
                navigationDestination:
                    theme.parentThemeID
                        .map {
                            .theme(
                                $0
                            )
                        },
                onEdit: {
                    uuidDraft =
                        theme.parentThemeID

                    editingField =
                        .parent
                }
            )
        }
    }


    @ViewBuilder
    private func statusRow(
        _ theme: Theme
    ) -> some View {
        if editingField == .status {
            pickerEditor(
                label:
                    "Status"
            ) {
                Picker(
                    "",
                    selection:
                        $statusDraft
                ) {
                    ForEach(
                        StructureStatus
                            .allCases
                    ) { status in
                        Text(
                            status.displayName
                        )
                        .tag(status)
                    }
                }
                .labelsHidden()
            } onSave: {
                var updated =
                    theme

                updated.status =
                    statusDraft

                finish(
                    store.saveThemeMetadata(
                        updated
                    )
                )
            }
        } else {
            StructureValueRow(
                label:
                    "Status",
                value:
                    theme.status?
                        .displayName
                    ?? "None",
                onEdit: {
                    statusDraft =
                        theme.status
                        ?? .active

                    editingField =
                        .status
                }
            )
        }
    }


    @ViewBuilder
    private func priorityRow(
        _ theme: Theme
    ) -> some View {
        if editingField == .priority {
            pickerEditor(
                label:
                    "Priority"
            ) {
                Picker(
                    "",
                    selection:
                        $priorityDraft
                ) {
                    ForEach(
                        StructurePriority
                            .allCases
                    ) { priority in
                        Text(
                            priority.displayName
                        )
                        .tag(priority)
                    }
                }
                .labelsHidden()
            } onSave: {
                var updated =
                    theme

                updated.priority =
                    priorityDraft

                finish(
                    store.saveThemeMetadata(
                        updated
                    )
                )
            }
        } else {
            StructureValueRow(
                label:
                    "Priority",
                value:
                    theme.priority?
                        .displayName
                    ?? "None",
                onEdit: {
                    priorityDraft =
                        theme.priority
                        ?? .normal

                    editingField =
                        .priority
                }
            )
        }
    }


    @ViewBuilder
    private func ownerRow(
        _ theme: Theme
    ) -> some View {
        if editingField == .owner {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Picker(
                    "Owner",
                    selection:
                        $uuidDraft
                ) {
                    Text("None")
                        .tag(
                            Optional<UUID>.none
                        )

                    ForEach(
                        people
                    ) { person in
                        Text(person.name)
                            .tag(
                                Optional(
                                    person.id
                                )
                            )
                    }
                }

                StructureEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        var updated =
                            theme

                        updated.ownerEntityID =
                            uuidDraft

                        finish(
                            store.saveThemeMetadata(
                                updated
                            )
                        )
                    }
                )
            }
        } else {
            StructureValueRow(
                label:
                    "Owner",
                value:
                    theme.ownerEntityID
                        .flatMap {
                            store.entity(
                                id: $0
                            )?.name
                        }
                    ?? "None",
                navigationDestination:
                    theme.ownerEntityID
                        .map {
                            .person(
                                $0
                            )
                        },
                onEdit: {
                    uuidDraft =
                        theme.ownerEntityID

                    editingField =
                        .owner
                }
            )
        }
    }


    @ViewBuilder
    private func dateRow(
        _ theme: Theme,
        label: String,
        value: Date?,
        field: EditableField
    ) -> some View {
        if editingField == field {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Toggle(
                    label,
                    isOn:
                        $dateEnabledDraft
                )

                if dateEnabledDraft {
                    LargeDateTimeEditor(
                        date:
                            $dateDraft,
                        timeZoneID:
                            .constant(
                                TestudoTime
                                    .deviceTimeZoneID
                            ),
                        includesTime:
                            false,
                        showsTimeZone:
                            false
                    )
                }

                StructureEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        var updated =
                            theme

                        let value =
                            dateEnabledDraft
                            ? dateDraft
                            : nil

                        if field == .startDate {
                            updated.startDate =
                                value
                        } else {
                            updated.targetDate =
                                value
                        }

                        finish(
                            store.saveThemeMetadata(
                                updated
                            )
                        )
                    }
                )
            }
        } else {
            StructureValueRow(
                label:
                    label,
                value:
                    value.map {
                        $0.formatted(
                            date:
                                .abbreviated,
                            time:
                                .omitted
                        )
                    }
                    ?? "None",
                onEdit: {
                    dateEnabledDraft =
                        value != nil

                    dateDraft =
                        value ?? Date()

                    editingField =
                        field
                }
            )
        }
    }


    @ViewBuilder
    private func pickerEditor<
        Content: View
    >(
        label: String,
        @ViewBuilder content:
            () -> Content,
        onSave:
            @escaping () -> Void
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            Text(label)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            content()

            StructureEditActions(
                onCancel:
                    cancelEdit,
                onSave:
                    onSave
            )
        }
    }


    private func beginText(
        _ field: EditableField,
        value: String
    ) {
        textDraft =
            value

        errorMessage =
            nil

        editingField =
            field
    }


    private func saveText(
        _ theme: Theme,
        field: EditableField
    ) {
        var updated =
            theme

        switch field {
        case .name:
            updated.name =
                textDraft

        case .summary:
            updated.summary =
                textDraft

        case .notes:
            updated.notes =
                textDraft

        case .code:
            updated.code =
                textDraft

        case .tags:
            updated.tags =
                textDraft

        case .url:
            updated.url =
                textDraft

        case .symbol:
            updated.symbolName =
                textDraft

        default:
            return
        }

        finish(
            store.saveThemeMetadata(
                updated
            )
        )
    }


    private func finish(
        _ error: String?
    ) {
        errorMessage =
            error

        if error == nil {
            cancelEdit()
        }
    }


    private func cancelEdit() {
        editingField =
            nil

        errorMessage =
            nil
    }


    private var people:
        [Entity]
    {
        store.data.entities
            .filter {
                $0.kind == .person
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }


    private func availableParents(
        _ theme: Theme
    ) -> [Theme] {
        let descendants =
            Set(
                store
                    .themeDescendantIDs(
                        of:
                            theme.id
                    )
            )

        return store.data.themes
            .filter {
                $0.id != theme.id
                && !descendants
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
}


// ============================================================
// MARK: - Rich Organization / Group Inspector
// ============================================================

// ============================================================
// MARK: - Organization Detail
//
// Same structural behaviour as PersonDetailView:
//
// No Related Tasks:
//     full-height Organization details
//
// Related Tasks present:
//     upper 50% = Related Tasks
//     lower 50% = Organization details
//     independent scrolling
//
// ============================================================

// ============================================================
// MARK: - Shared Related Tasks Split Pane
//
// Shared by Theme, Organization and Group.
//
// No related Tasks:
//     full-height details.
//
// Related Tasks:
//     upper 50% = independently scrollable Task list
//     lower 50% = independently scrollable detail view
//
// This mirrors PersonDetailView structurally.
// ============================================================

private struct RelatedTasksSplitPane<
    DetailContent:
        View
>: View {

    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.testudoDetailNavigation
    )
    private var detailNavigation

    let tasks:
        [WorkItem]

    private let detailContent:
        () -> DetailContent


    init(
        tasks:
            [WorkItem],
        @ViewBuilder
        detailContent:
            @escaping () -> DetailContent
    ) {
        self.tasks =
            tasks

        self.detailContent =
            detailContent
    }


    var body:
        some View
    {
        Group {
            if tasks.isEmpty {
                detailContent()

            } else {
                splitDetailContent
            }
        }
        .background(
            TestudoStyle
                .contentBackground
        )
    }


    private var splitDetailContent:
        some View
    {
        GeometryReader {
            geometry in

            let separatorHeight:
                CGFloat = 1

            let paneHeight =
                max(
                    0,
                    (
                        geometry
                            .size
                            .height
                        - separatorHeight
                    )
                    / 2
                )


            VStack(
                spacing:
                    0
            ) {
                relatedTasksScroll
                    .frame(
                        height:
                            paneHeight
                    )

                Divider()

                detailContent()
                    .frame(
                        height:
                            paneHeight
                    )
            }
            .frame(
                width:
                    geometry
                        .size
                        .width,
                height:
                    geometry
                        .size
                        .height,
                alignment:
                    .top
            )
        }
    }


    private var relatedTasksScroll:
        some View
    {
        ScrollView {
            relatedTasksSection
                .padding(
                    .horizontal,
                    24
                )
                .padding(
                    .top,
                    4
                )
                .padding(
                    .bottom,
                    20
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )
        }
        .background(
            TestudoStyle
                .contentBackground
        )
    }


    private var relatedTasksSection:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {
            HStack {
                Text(
                    "Related Tasks"
                )
                .font(
                    .title3
                )
                .fontWeight(
                    .semibold
                )

                Spacer()

                Text(
                    "\(tasks.count)"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            VStack(
                spacing:
                    0
            ) {
                ForEach(
                    tasks
                ) {
                    task in

                    Button {
                        detailNavigation(
                            .work(
                                task.id
                            )
                        )

                    } label: {
                        taskRow(
                            task
                        )
                    }
                    .buttonStyle(
                        .plain
                    )


                    if
                        task.id
                            != tasks
                                .last?
                                .id
                    {
                        Divider()
                            .padding(
                                .leading,
                                30
                            )
                    }
                }
            }
        }
    }


    private func taskRow(
        _ task:
            WorkItem
    ) -> some View
    {
        HStack(
            alignment:
                .top,
            spacing:
                10
        ) {
            Image(
                systemName:
                    taskIcon(
                        task
                    )
            )
            .testudoTaskStatusSymbolColor(
                taskIcon(
                    task
                )
            )
            .frame(
                width:
                    20
            )
            .padding(
                .top,
                2
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {
                Text(
                    taskTitle(
                        task
                    )
                )
                .font(
                    .callout
                )
                .fontWeight(
                    .medium
                )
                .foregroundStyle(
                    .primary
                )


                HStack(
                    spacing:
                        6
                ) {
                    Text(
                        "Task"
                    )

                    if
                        let status =
                            task.status
                    {
                        Text("·")

                        Text(
                            status
                                .displayName
                        )
                    }


                    if
                        let theme =
                            store.theme(
                                id:
                                    task.themeID
                            )
                    {
                        Text("·")

                        Text(
                            theme.name
                        )
                    }


                    if
                        let deadline =
                            task.deadlineAt
                    {
                        Text("·")

                        Text(
                            "Due \(TestudoTime.displayDateTime(deadline, sourceTimeZoneID: task.deadlineTimeZoneID))"
                        )
                    }
                }
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )


                let body =
                    task.body
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                let explicitTitle =
                    task.title?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                    ?? ""


                if
                    !body.isEmpty,
                    !explicitTitle.isEmpty
                {
                    Text(
                        body
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(
                        2
                    )
                    .fixedSize(
                        horizontal:
                            false,
                        vertical:
                            true
                    )
                }
            }


            Spacer(
                minLength:
                    0
            )
        }
        .padding(
            .vertical,
            7
        )
        .contentShape(
            Rectangle()
        )
    }


    private func taskTitle(
        _ task:
            WorkItem
    ) -> String {

        if
            let title =
                task.title?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !title.isEmpty
        {
            return title
        }


        let body =
            task.body
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !body.isEmpty {
            return body
        }


        return "Task"
    }


    private func taskIcon(
        _ task:
            WorkItem
    ) -> String {

        switch task.status {
        case .completed:
            return
                "checkmark.circle"

        case .closed:
            return
                "archivebox"

        case .inProgress:
            return
                "clock"

        case .todo,
             nil:
            return
                "circle"
        }
    }
}


// ============================================================
// MARK: - Entity Related Tasks
//
// Organization and Group share the same Work relationship
// semantics.
// ============================================================

private struct EntityRelatedTasksDetail<
    DetailContent:
        View
>: View {

    @EnvironmentObject
    private var store:
        TestudoStore

    let entityID:
        UUID

    private let detailContent:
        () -> DetailContent


    init(
        entityID:
            UUID,
        @ViewBuilder
        detailContent:
            @escaping () -> DetailContent
    ) {
        self.entityID =
            entityID

        self.detailContent =
            detailContent
    }


    var body:
        some View
    {
        RelatedTasksSplitPane(
            tasks:
                relatedTasks
        ) {
            detailContent()
        }
    }


    private var relatedTasks:
        [WorkItem]
    {
        store.data
            .workItems
            .filter {
                item in

                item.kind
                    == .task
                &&
                workItemIsRelated(
                    item
                )
            }
            .sorted {
                $0.updatedAt
                    > $1.updatedAt
            }
    }


    private func workItemIsRelated(
        _ item:
            WorkItem
    ) -> Bool {

        if
            store.data
                .workEntityRelationships
                .contains(
                    where: {
                        $0.workItemID
                            == item.id
                        &&
                        $0.entityID
                            == entityID
                    }
                )
        {
            return true
        }


        var currentParent =
            item.parentWorkItemID

        var visited =
            Set<UUID>()


        while
            let parentID =
                currentParent
        {
            guard
                visited
                    .insert(
                        parentID
                    )
                    .inserted
            else {
                break
            }


            if
                store.data
                    .workEntityRelationships
                    .contains(
                        where: {
                            $0.workItemID
                                == parentID
                            &&
                            $0.entityID
                                == entityID
                            &&
                            $0.inheritedByChildren
                        }
                    )
            {
                return true
            }


            currentParent =
                store.workItem(
                    id:
                        parentID
                )?
                .parentWorkItemID
        }


        return false
    }
}


// ============================================================
// MARK: - Organization Detail
// ============================================================

struct OrganizationDetailView:
    View
{
    let organizationID:
        UUID

    private let detailDeleteFooter:
        AnyView


    init<DeleteFooter: View>(
        organizationID:
            UUID,
        @ViewBuilder
        deleteFooter:
            () -> DeleteFooter
    ) {
        self.organizationID =
            organizationID

        self.detailDeleteFooter =
            AnyView(
                deleteFooter()
            )
    }


    var body:
        some View
    {
        EntityRelatedTasksDetail(
            entityID:
                organizationID
        ) {
            RichStructureEntityDetailView(
                entityID:
                    organizationID
            ) {
                detailDeleteFooter
            }
        }
    }
}


// ============================================================
// MARK: - Group Detail
// ============================================================

struct GroupDetailView:
    View
{
    let groupID:
        UUID

    private let detailDeleteFooter:
        AnyView


    init<DeleteFooter: View>(
        groupID:
            UUID,
        @ViewBuilder
        deleteFooter:
            () -> DeleteFooter
    ) {
        self.groupID =
            groupID

        self.detailDeleteFooter =
            AnyView(
                deleteFooter()
            )
    }


    var body:
        some View
    {
        EntityRelatedTasksDetail(
            entityID:
                groupID
        ) {
            RichStructureEntityDetailView(
                entityID:
                    groupID
            ) {
                detailDeleteFooter
            }
        }
    }
}


// ============================================================
// MARK: - Theme Detail
// ============================================================

struct ThemeRelatedTasksDetailView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    let themeID:
        UUID

    private let detailDeleteFooter:
        AnyView


    init<DeleteFooter: View>(
        themeID:
            UUID,
        @ViewBuilder
        deleteFooter:
            () -> DeleteFooter
    ) {
        self.themeID =
            themeID

        self.detailDeleteFooter =
            AnyView(
                deleteFooter()
            )
    }


    var body:
        some View
    {
        RelatedTasksSplitPane(
            tasks:
                relatedTasks
        ) {
            RichThemeDetailView(
                themeID:
                    themeID
            ) {
                detailDeleteFooter
            }
        }
    }


    // Tasks directly assigned to this Theme.
    //
    // Tasks belonging to descendant Themes remain associated
    // with those descendant Themes rather than being duplicated
    // in every ancestor's Related Tasks pane.
    private var relatedTasks:
        [WorkItem]
    {
        store.data
            .workItems
            .filter {
                $0.kind
                    == .task
                &&
                $0.themeID
                    == themeID
            }
            .sorted {
                $0.updatedAt
                    > $1.updatedAt
            }
    }
}


struct RichStructureEntityDetailView:
    View
{
    @EnvironmentObject
    private var store: TestudoStore

    let entityID: UUID

    private let detailDeleteFooter:
        AnyView


    init<DeleteFooter: View>(
        entityID: UUID,
        @ViewBuilder
        deleteFooter:
            () -> DeleteFooter
    ) {
        self.entityID =
            entityID

        self.detailDeleteFooter =
            AnyView(
                deleteFooter()
            )
    }

    @State
    private var editingField:
        EditableField?

    @State
    private var textDraft =
        ""

    @State
    private var uuidDraft:
        UUID?

    @State
    private var statusDraft:
        StructureStatus =
        .active

    @State
    private var priorityDraft:
        StructurePriority =
        .normal

    @State
    private var dateDraft =
        Date()

    @State
    private var dateEnabledDraft =
        true

    @State
    private var membershipIDsDraft:
        Set<UUID> = []


    @State
    private var affiliatedPeopleIDsDraft:
        Set<UUID> = []

    @State
    private var errorMessage:
        String?

    private enum EditableField:
        Hashable
    {
        case name
        case shortName
        case code
        case notes
        case status
        case priority
        case owner
        case startDate
        case targetDate
        case website
        case email
        case phone
        case address
        case city
        case postalCode
        case country
        case tags
        case symbol
        case memberships
        case affiliatedPeople
    }


    var body: some View {
        ZStack {
            TestudoStyle
                .contentBackground
                .ignoresSafeArea()

            if
                let entity =
                    store.entity(
                        id:
                            entityID
                    )
            {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing:
                            entity.kind
                                == .organization
                            ? 18
                            : 26
                    ) {
                        header(entity)

                        StructureInspectorSection(
                            title:
                                "Details"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                StructureReadOnlyRow(
                                    label:
                                        "Type",
                                    value:
                                        entity.kind
                                            .displayName
                                )

                                textRow(
                                    entity,
                                    label:
                                        "Short name",
                                    value:
                                        entity.shortName,
                                    field:
                                        .shortName
                                )

                                textRow(
                                    entity,
                                    label:
                                        "Code",
                                    value:
                                        entity.code,
                                    field:
                                        .code
                                )

                                statusRow(entity)
                                priorityRow(entity)
                                ownerRow(entity)
                            }
                        }
                        .organizationDetailCard(
                            entity.kind
                                == .organization
                        )

                        membershipsSection(
                            entity
                        )
                        .organizationDetailCard(
                            entity.kind
                                == .organization
                        )


                        if
                            entity.kind == .organization
                            || entity.kind == .group
                        {
                            affiliatedPeopleSection(
                                entity
                            )
                            .organizationDetailCard(
                                entity.kind
                                    == .organization
                            )
                        }

                        StructureInspectorSection(
                            title:
                                "Schedule"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                dateRow(
                                    entity,
                                    label:
                                        "Start",
                                    value:
                                        entity.startDate,
                                    field:
                                        .startDate
                                )

                                dateRow(
                                    entity,
                                    label:
                                        "Target",
                                    value:
                                        entity.targetDate,
                                    field:
                                        .targetDate
                                )
                            }
                        }
                        .organizationDetailCard(
                            entity.kind
                                == .organization
                        )

                        StructureInspectorSection(
                            title:
                                "Contact & Location"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                textRow(
                                    entity,
                                    label:
                                        "Website",
                                    value:
                                        entity.website,
                                    field:
                                        .website
                                )

                                textRow(
                                    entity,
                                    label:
                                        "Email",
                                    value:
                                        entity.email,
                                    field:
                                        .email
                                )

                                textRow(
                                    entity,
                                    label:
                                        "Phone",
                                    value:
                                        entity.phone,
                                    field:
                                        .phone
                                )

                                textRow(
                                    entity,
                                    label:
                                        "Address",
                                    value:
                                        entity.address,
                                    field:
                                        .address
                                )

                                textRow(
                                    entity,
                                    label:
                                        "City",
                                    value:
                                        entity.city,
                                    field:
                                        .city
                                )

                                textRow(
                                    entity,
                                    label:
                                        "Postal code",
                                    value:
                                        entity.postalCode,
                                    field:
                                        .postalCode
                                )

                                textRow(
                                    entity,
                                    label:
                                        "Country",
                                    value:
                                        entity.country,
                                    field:
                                        .country
                                )
                            }
                        }
                        .organizationDetailCard(
                            entity.kind
                                == .organization
                        )

                        StructureInspectorSection(
                            title:
                                "Metadata"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                textRow(
                                    entity,
                                    label:
                                        "Tags",
                                    value:
                                        entity.tags,
                                    field:
                                        .tags
                                )

                                textRow(
                                    entity,
                                    label:
                                        "SF Symbol",
                                    value:
                                        entity.symbolName,
                                    field:
                                        .symbol
                                )

                                textRow(
                                    entity,
                                    label:
                                        "Notes",
                                    value:
                                        entity.notes,
                                    field:
                                        .notes,
                                    multiline:
                                        true
                                )
                            }
                        }
                        .organizationDetailCard(
                            entity.kind
                                == .organization
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(
                                    .red
                                )
                        }

                        StructureInspectorSection(
                            title:
                                "History"
                        ) {
                            VStack(
                                spacing: 9
                            ) {
                                StructureReadOnlyRow(
                                    label:
                                        "Created",
                                    value:
                                        TestudoTime
                                            .dateTime(
                                                entity.createdAt
                                            )
                                )

                                StructureReadOnlyRow(
                                    label:
                                        "Updated",
                                    value:
                                        TestudoTime
                                            .dateTime(
                                                entity.updatedAt
                                            )
                                )
                            }
                        }
                        .organizationDetailCard(
                            entity.kind
                                == .organization
                        )

                        // DETAIL DELETE FOOTER
                        HStack {
                            Spacer()

                            detailDeleteFooter

                            Spacer()
                        }
                        .padding(.top, 8)
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
                        28
                    )
                    .frame(
                        maxWidth: 760,
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
            } else {
                ContentUnavailableView(
                    "Item Not Found",
                    systemImage:
                        "questionmark.circle"
                )
            }
        }
    }


    @ViewBuilder
    private func header(
        _ entity: Entity
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName:
                    entity.symbolName
                    ?? defaultIcon(
                        entity
                    )
            )
            .font(.title2)
            .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                if editingField == .name {
                    TextField(
                        "Name",
                        text:
                            $textDraft
                    )
                    .font(.title2)

                    StructureEditActions(
                        onCancel:
                            cancelEdit,
                        onSave: {
                            saveText(
                                entity,
                                field:
                                    .name
                            )
                        }
                    )
                } else {
                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 8
                    ) {
                        Text(entity.name)
                            .font(.title2)
                            .fontWeight(
                                .semibold
                            )

                        StructureEditButton {
                            beginText(
                                .name,
                                value:
                                    entity.name
                            )
                        }
                    }
                }

                Text(
                    entity.kind
                        .displayName
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
    }


    @ViewBuilder
    private func textRow(
        _ entity: Entity,
        label: String,
        value: String?,
        field: EditableField,
        multiline: Bool = false
    ) -> some View {
        if editingField == field {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                if multiline {
                    TextEditor(
                        text:
                            $textDraft
                    )
                    .frame(
                        minHeight: 90
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 6
                        )
                        .stroke(
                            Color.secondary
                                .opacity(0.15)
                        )
                    }
                } else {
                    TextField(
                        label,
                        text:
                            $textDraft
                    )
                }

                StructureEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveText(
                            entity,
                            field:
                                field
                        )
                    }
                )
            }
        } else {
            StructureValueRow(
                label:
                    label,
                value:
                    value ?? "",
                onEdit: {
                    beginText(
                        field,
                        value:
                            value ?? ""
                    )
                }
            )
        }
    }


    @ViewBuilder
    private func statusRow(
        _ entity: Entity
    ) -> some View {
        if editingField == .status {
            pickerEditor(
                label:
                    "Status"
            ) {
                Picker(
                    "",
                    selection:
                        $statusDraft
                ) {
                    ForEach(
                        StructureStatus
                            .allCases
                    ) { status in
                        Text(
                            status.displayName
                        )
                        .tag(status)
                    }
                }
                .labelsHidden()
            } onSave: {
                var updated =
                    entity

                updated.status =
                    statusDraft

                finish(
                    store.saveEntityMetadata(
                        updated
                    )
                )
            }
        } else {
            StructureValueRow(
                label:
                    "Status",
                value:
                    entity.status?
                        .displayName
                    ?? "None",
                onEdit: {
                    statusDraft =
                        entity.status
                        ?? .active

                    editingField =
                        .status
                }
            )
        }
    }


    @ViewBuilder
    private func priorityRow(
        _ entity: Entity
    ) -> some View {
        if editingField == .priority {
            pickerEditor(
                label:
                    "Priority"
            ) {
                Picker(
                    "",
                    selection:
                        $priorityDraft
                ) {
                    ForEach(
                        StructurePriority
                            .allCases
                    ) { priority in
                        Text(
                            priority.displayName
                        )
                        .tag(priority)
                    }
                }
                .labelsHidden()
            } onSave: {
                var updated =
                    entity

                updated.priority =
                    priorityDraft

                finish(
                    store.saveEntityMetadata(
                        updated
                    )
                )
            }
        } else {
            StructureValueRow(
                label:
                    "Priority",
                value:
                    entity.priority?
                        .displayName
                    ?? "None",
                onEdit: {
                    priorityDraft =
                        entity.priority
                        ?? .normal

                    editingField =
                        .priority
                }
            )
        }
    }


    @ViewBuilder
    private func ownerRow(
        _ entity: Entity
    ) -> some View {
        if editingField == .owner {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Picker(
                    "Owner",
                    selection:
                        $uuidDraft
                ) {
                    Text("None")
                        .tag(
                            Optional<UUID>.none
                        )

                    ForEach(
                        people
                    ) { person in
                        Text(person.name)
                            .tag(
                                Optional(
                                    person.id
                                )
                            )
                    }
                }

                StructureEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        var updated =
                            entity

                        updated.ownerEntityID =
                            uuidDraft

                        finish(
                            store.saveEntityMetadata(
                                updated
                            )
                        )
                    }
                )
            }
        } else {
            StructureValueRow(
                label:
                    "Owner",
                value:
                    entity.ownerEntityID
                        .flatMap {
                            store.entity(
                                id:
                                    $0
                            )?.name
                        }
                    ?? "None",
                navigationDestination:
                    entity.ownerEntityID
                        .map {
                            .person(
                                $0
                            )
                        },
                onEdit: {
                    uuidDraft =
                        entity.ownerEntityID

                    editingField =
                        .owner
                }
            )
        }
    }


    @ViewBuilder
    private func dateRow(
        _ entity: Entity,
        label: String,
        value: Date?,
        field: EditableField
    ) -> some View {
        if editingField == field {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Toggle(
                    label,
                    isOn:
                        $dateEnabledDraft
                )

                if dateEnabledDraft {
                    LargeDateTimeEditor(
                        date:
                            $dateDraft,
                        timeZoneID:
                            .constant(
                                TestudoTime
                                    .deviceTimeZoneID
                            ),
                        includesTime:
                            false,
                        showsTimeZone:
                            false
                    )
                }

                StructureEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        var updated =
                            entity

                        let date =
                            dateEnabledDraft
                            ? dateDraft
                            : nil

                        if field == .startDate {
                            updated.startDate =
                                date
                        } else {
                            updated.targetDate =
                                date
                        }

                        finish(
                            store.saveEntityMetadata(
                                updated
                            )
                        )
                    }
                )
            }
        } else {
            StructureValueRow(
                label:
                    label,
                value:
                    value.map {
                        $0.formatted(
                            date:
                                .abbreviated,
                            time:
                                .omitted
                        )
                    }
                    ?? "None",
                onEdit: {
                    dateEnabledDraft =
                        value != nil

                    dateDraft =
                        value ?? Date()

                    editingField =
                        field
                }
            )
        }
    }


    @ViewBuilder
    private func membershipsSection(
        _ entity: Entity
    ) -> some View {
        let current =
            store.containers(
                for:
                    entity.id
            )

        let candidates =
            availableContainers(
                entity
            )

        let tabs:
            [EntitySelectionTab] =
            entity.kind == .organization
            ? [
                .organizations
            ]
            : [
                .groups,
                .organizations
            ]

        StructureInspectorSection(
            title:
                "Structure"
        ) {
            EntitySelectionSummaryRow(
                label:
                    entity.kind == .organization
                    ? "Parent"
                    : "Containers",
                selectedIDs:
                    Set(
                        current.map(
                            \.id
                        )
                    ),
                tabs:
                    tabs,
                candidateIDs:
                    Set(
                        candidates.map(
                            \.id
                        )
                    ),
                selectorTitle:
                    entity.kind == .organization
                    ? "Parent Organization"
                    : "Group Structure",
                selectorMessage:
                    entity.kind == .organization
                    ? "Choose the parent Organization. Existing selections remain visible in Selected at the top."
                    : "Choose Groups and Organizations that structurally contain this Group. Existing selections remain visible in Selected at the top.",
                emptyText:
                    "Independent",
                buttonSystemImage:
                    "pencil",
                onSave: {
                    selection in

                    store
                        .updateEntityMemberships(
                            entityID:
                                entity.id,
                            containerIDs:
                                selection
                        )
                }
            )
        }
    }


    @ViewBuilder
    private func affiliatedPeopleSection(
        _ entity: Entity
    ) -> some View {
        let current =
            store.affiliatedPeople(
                to:
                    entity.id
            )

        let peopleIDs =
            Set(
                store.data.entities
                    .filter {
                        $0.kind
                            == .person
                    }
                    .map(
                        \.id
                    )
            )

        StructureInspectorSection(
            title:
                "Affiliated People"
        ) {
            EntitySelectionSummaryRow(
                label:
                    "People",
                selectedIDs:
                    Set(
                        current.map(
                            \.id
                        )
                    ),
                tabs:
                    [
                        .people
                    ],
                candidateIDs:
                    peopleIDs,
                selectorTitle:
                    entity.kind == .organization
                    ? "People Affiliated with Organization"
                    : "People Affiliated with Group",
                selectorMessage:
                    "People are sorted alphabetically by surname. Existing affiliations remain visible in Selected at the top.",
                emptyText:
                    "None",
                buttonSystemImage:
                    "pencil",
                onSave: {
                    selection in

                    store
                        .updateAffiliatedPeople(
                            containerID:
                                entity.id,
                            personIDs:
                                selection
                        )
                }
            )
        }
    }


    private func affiliatedPersonBinding(
        _ personID: UUID
    ) -> Binding<Bool> {
        Binding(
            get: {
                affiliatedPeopleIDsDraft
                    .contains(
                        personID
                    )
            },
            set: {
                enabled in

                if enabled {
                    affiliatedPeopleIDsDraft
                        .insert(
                            personID
                        )
                } else {
                    affiliatedPeopleIDsDraft
                        .remove(
                            personID
                        )
                }
            }
        )
    }


    private func membershipBinding(
        _ id: UUID
    ) -> Binding<Bool> {
        Binding(
            get: {
                membershipIDsDraft
                    .contains(id)
            },
            set: {
                enabled in

                if enabled {
                    membershipIDsDraft
                        .insert(id)
                } else {
                    membershipIDsDraft
                        .remove(id)
                }
            }
        )
    }


    @ViewBuilder
    private func pickerEditor<
        Content: View
    >(
        label: String,
        @ViewBuilder content:
            () -> Content,
        onSave:
            @escaping () -> Void
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            Text(label)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            content()

            StructureEditActions(
                onCancel:
                    cancelEdit,
                onSave:
                    onSave
            )
        }
    }


    private func beginText(
        _ field: EditableField,
        value: String
    ) {
        textDraft =
            value

        errorMessage =
            nil

        editingField =
            field
    }


    private func saveText(
        _ entity: Entity,
        field: EditableField
    ) {
        var updated =
            entity

        switch field {
        case .name:
            updated.name =
                textDraft

        case .shortName:
            updated.shortName =
                textDraft

        case .code:
            updated.code =
                textDraft

        case .notes:
            updated.notes =
                textDraft

        case .website:
            updated.website =
                textDraft

        case .email:
            updated.email =
                textDraft

        case .phone:
            updated.phone =
                textDraft

        case .address:
            updated.address =
                textDraft

        case .city:
            updated.city =
                textDraft

        case .postalCode:
            updated.postalCode =
                textDraft

        case .country:
            updated.country =
                textDraft

        case .tags:
            updated.tags =
                textDraft

        case .symbol:
            updated.symbolName =
                textDraft

        default:
            return
        }

        finish(
            store.saveEntityMetadata(
                updated
            )
        )
    }


    private func finish(
        _ error: String?
    ) {
        errorMessage =
            error

        if error == nil {
            cancelEdit()
        }
    }


    private func cancelEdit() {
        editingField =
            nil

        errorMessage =
            nil
    }


    private var people:
        [Entity]
    {
        store.data.entities
            .filter {
                $0.kind == .person
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }


    private func availableContainers(
        _ entity: Entity
    ) -> [Entity] {
        let descendants =
            Set(
                store
                    .entityDescendantIDs(
                        of:
                            entity.id
                    )
            )

        return store
            .possibleContainers(
                for:
                    entity.kind
            )
            .filter {
                $0.id != entity.id
                && !descendants
                    .contains(
                        $0.id
                    )
            }
    }


    private func defaultIcon(
        _ entity: Entity
    ) -> String {
        switch entity.kind {
        case .organization:
            return "building.2"

        case .group:
            return "person.3"

        case .person:
            return "person.crop.circle"
        }
    }
}
