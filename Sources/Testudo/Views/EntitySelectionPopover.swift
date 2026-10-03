import SwiftUI


// ============================================================
// MARK: - Entity selector tabs
// ============================================================

enum EntitySelectionTab:
    String,
    CaseIterable,
    Identifiable,
    Hashable
{
    case people
    case groups
    case organizations


    var id: String {
        rawValue
    }


    var title: String {
        switch self {
        case .people:
            return "People"

        case .groups:
            return "Groups"

        case .organizations:
            return "Organizations"
        }
    }


    var singularTitle: String {
        switch self {
        case .people:
            return "Person"

        case .groups:
            return "Group"

        case .organizations:
            return "Organization"
        }
    }


    var kind:
        EntityKind
    {
        switch self {
        case .people:
            return .person

        case .groups:
            return .group

        case .organizations:
            return .organization
        }
    }


    var systemImage:
        String
    {
        switch self {
        case .people:
            return "person.2"

        case .groups:
            return "person.3"

        case .organizations:
            return "building.2"
        }
    }
}


// ============================================================
// MARK: - Generic selector button
//
// Can be embedded in creation forms, relationship editors,
// account settings, etc.
// ============================================================

struct EntitySelectionButton:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    let title:
        String

    let selectedIDs:
        Set<UUID>

    let tabs:
        [EntitySelectionTab]

    var candidateIDs:
        Set<UUID>? = nil

    var excludedIDs:
        Set<UUID> = []

    var maximumSelectionCount:
        Int? = nil

    var placeholder:
        String =
        "Choose…"

    var selectorMessage:
        String? = nil

    let onSave:
        (Set<UUID>) -> String?


    @State
    private var showingSelector =
        false


    var body: some View {
        Button {
            showingSelector =
                true

        } label: {
            HStack(
                spacing:
                    9
            ) {
                Image(
                    systemName:
                        leadingIcon
                )
                .font(
                    .system(
                        size: 12,
                        weight:
                            .medium
                    )
                )
                .foregroundStyle(
                    selectedIDs.isEmpty
                    ? .secondary
                    : .primary
                )

                Text(
                    summaryText
                )
                .foregroundStyle(
                    selectedIDs.isEmpty
                    ? .secondary
                    : .primary
                )
                .lineLimit(1)

                Spacer(
                    minLength:
                        12
                )

                Image(
                    systemName:
                        "chevron.up.chevron.down"
                )
                .font(
                    .system(
                        size: 9,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    .tertiary
                )
            }
            .padding(
                .horizontal,
                11
            )
            .frame(
                height: 34
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .frame(
            maxWidth: 360,
            alignment:
                .leading
        )
        .background(
            Color.primary
                .opacity(
                    0.035
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        9,
                    style:
                        .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    9,
                style:
                    .continuous
            )
            .stroke(
                Color.primary
                    .opacity(
                        0.10
                    ),
                lineWidth:
                    1
            )
        }
        .popover(
            isPresented:
                $showingSelector,
            arrowEdge:
                .trailing
        ) {
            EntitySelectionPopover(
                title:
                    title,
                message:
                    selectorMessage,
                tabs:
                    tabs,
                candidateIDs:
                    candidateIDs,
                excludedIDs:
                    excludedIDs,
                initialSelection:
                    selectedIDs,
                maximumSelectionCount:
                    maximumSelectionCount,
                onCancel: {
                    showingSelector =
                        false
                },
                onSave: {
                    selection in

                    let error =
                        onSave(
                            selection
                        )

                    if error == nil {
                        showingSelector =
                            false
                    }

                    return error
                }
            )
            .id(
                selectionIdentity
            )
        }
    }


    private var selectionIdentity:
        String
    {
        selectedIDs
            .map(
                \.uuidString
            )
            .sorted()
            .joined(
                separator:
                    "|"
            )
    }


    private var selectedEntities:
        [Entity]
    {
        selectedIDs
            .compactMap {
                store.entity(
                    id:
                        $0
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


    private var summaryText:
        String
    {
        guard
            !selectedEntities.isEmpty
        else {
            return placeholder
        }

        if selectedEntities.count <= 2 {
            return selectedEntities
                .map(
                    \.name
                )
                .joined(
                    separator:
                        ", "
                )
        }

        return
            "\(selectedEntities[0].name), \(selectedEntities[1].name) +\(selectedEntities.count - 2)"
    }


    private var leadingIcon:
        String
    {
        guard
            selectedEntities.count == 1,
            let entity =
                selectedEntities.first
        else {
            return "person.2"
        }

        switch entity.kind {
        case .person:
            return "person.crop.circle"

        case .group:
            return "person.3"

        case .organization:
            return "building.2"
        }
    }
}


// ============================================================
// MARK: - Inspector summary row
//
// Same DetailSelectionRow shell as Theme / Parent / Status /
// Deadline, but backed by the Entity selector.
// ============================================================

struct EntitySelectionSummaryRow:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Environment(
        \.testudoDetailNavigation
    )
    private var detailNavigation

    let label:
        String

    let selectedIDs:
        Set<UUID>

    let tabs:
        [EntitySelectionTab]

    var candidateIDs:
        Set<UUID>? = nil

    var excludedIDs:
        Set<UUID> = []

    var maximumSelectionCount:
        Int? = nil

    var selectorTitle:
        String

    var selectorMessage:
        String? = nil

    var emptyText:
        String = "None"

    var buttonSystemImage:
        String = "pencil"

    let onSave:
        (Set<UUID>) -> String?


    @State
    private var showingSelector =
        false


    var body: some View {
        let entities =
            selectedIDs
                .compactMap {
                    store.entity(
                        id:
                            $0
                    )
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }

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


            if entities.isEmpty {
                Text(
                    emptyText
                )
                .foregroundStyle(
                    .tertiary
                )

            } else {
                TestudoEntityLinks(
                    entities:
                        entities,
                    font:
                        .callout,
                    color:
                        .primary
                )
            }


            Spacer(
                minLength:
                    8
            )


            Button {
                showingSelector =
                    true
            } label: {
                Image(
                    systemName:
                        buttonSystemImage
                )
                .font(
                    .system(
                        size:
                            10,
                        weight:
                            .medium
                    )
                )
                .foregroundStyle(
                    .tertiary
                )
                .frame(
                    width:
                        20,
                    height:
                        20
                )
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .help(
                "Edit \(label)"
            )
            .popover(
                isPresented:
                    $showingSelector
            ) {
                EntitySelectionPopover(
                    title:
                        selectorTitle,
                    message:
                        selectorMessage,
                    tabs:
                        tabs,
                    candidateIDs:
                        candidateIDs,
                    excludedIDs:
                        excludedIDs,
                    initialSelection:
                        selectedIDs,
                    maximumSelectionCount:
                        maximumSelectionCount,
                    onCancel: {
                        showingSelector =
                            false
                    },
                    onSave: {
                        selection in

                        let error =
                            onSave(
                                selection
                            )

                        if error == nil {
                            showingSelector =
                                false
                        }

                        return error
                    }
                )
                .id(
                    selectionIdentity
                )
            }
        }
        .font(
            .callout
        )
    }


    private var selectionIdentity:
        String
    {
        selectedIDs
            .map(
                \.uuidString
            )
            .sorted()
            .joined(
                separator:
                    "|"
            )
    }


    private var selectedNames:
        [String]
    {
        selectedIDs
            .compactMap {
                store.entity(
                    id:
                        $0
                )?
                .name
            }
            .sorted {
                $0.localizedCaseInsensitiveCompare(
                    $1
                )
                == .orderedAscending
            }
    }


    private var summaryText:
        String
    {
        guard
            !selectedNames.isEmpty
        else {
            return emptyText
        }

        if selectedNames.count <= 3 {
            return selectedNames
                .joined(
                    separator:
                        ", "
                )
        }

        return
            "\(selectedNames.prefix(3).joined(separator: ", ")) +\(selectedNames.count - 3) more"
    }
}


// ============================================================
// MARK: - Pop-up
// ============================================================

struct EntitySelectionPopover:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    let title:
        String

    let message:
        String?

    let tabs:
        [EntitySelectionTab]

    let candidateIDs:
        Set<UUID>?

    let excludedIDs:
        Set<UUID>

    let maximumSelectionCount:
        Int?

    let onCancel:
        () -> Void

    let onSave:
        (Set<UUID>) -> String?


    @State
    private var activeTab:
        EntitySelectionTab

    @State
    private var searchText =
        ""

    @State
    private var selection:
        Set<UUID>

    @State
    private var errorMessage:
        String?

    @State
    private var showingAddNew =
        false

    @State
    private var newEntityName =
        ""

    @State
    private var newPersonFirstName =
        ""

    @State
    private var newPersonLastName =
        ""

    @State
    private var creationErrorMessage:
        String?

    @State
    private var locallyCreatedIDs:
        Set<UUID> = []




    init(
        title: String,
        message: String? = nil,
        tabs: [EntitySelectionTab],
        candidateIDs: Set<UUID>? = nil,
        excludedIDs: Set<UUID> = [],
        initialSelection: Set<UUID>,
        maximumSelectionCount: Int? = nil,
        onCancel:
            @escaping () -> Void,
        onSave:
            @escaping (Set<UUID>) -> String?
    ) {
        let normalizedTabs =
            tabs.isEmpty
            ? [.people]
            : tabs

        self.title =
            title

        self.message =
            message

        self.tabs =
            normalizedTabs

        self.candidateIDs =
            candidateIDs

        self.excludedIDs =
            excludedIDs

        self.maximumSelectionCount =
            maximumSelectionCount

        self.onCancel =
            onCancel

        self.onSave =
            onSave

        self._activeTab =
            State(
                initialValue:
                    normalizedTabs[0]
            )

        self._selection =
            State(
                initialValue:
                    initialSelection
            )
    }


    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                0
        ) {
            header

            Divider()

            VStack(
                alignment:
                    .leading,
                spacing:
                    12
            ) {
                if !selection.isEmpty {
                    selectedSection
                }

                if tabs.count > 1 {
                    tabSelector
                }

                searchField

                if showingAddNew {
                    addNewSection
                }

                listHeader

                entityList
            }
            .padding(
                .horizontal,
                18
            )
            .padding(
                .vertical,
                14
            )

            if let errorMessage {
                Text(
                    errorMessage
                )
                .font(.caption)
                .foregroundStyle(
                    .red
                )
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .bottom,
                    8
                )
            }

            Divider()

            footer
        }
        .frame(
            width: 680,
            height: 640
        )
        .background(
            TestudoStyle
                .contentBackground
        )
        .onChange(
            of:
                activeTab
        ) {
            _,
            _ in

            searchText =
                ""

            errorMessage =
                nil

            cancelNewEntity()
        }
    }


    // ========================================================
    // Header
    // ========================================================

    private var header:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                5
        ) {
            Text(title)
                .font(
                    .headline
                )

            if let message {
                Text(message)
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal:
                            false,
                        vertical:
                            true
                    )
            }
        }
        .padding(
            .horizontal,
            20
        )
        .padding(
            .top,
            18
        )
        .padding(
            .bottom,
            14
        )
    }


    // ========================================================
    // Selected
    //
    // Always visible above tabs/search so already selected
    // entities cannot be mistaken for new candidates.
    // ========================================================

    private var selectedSection:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                8
        ) {
            HStack {
                Label(
                    "Selected",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .font(
                    .system(
                        size: 12,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    Color.accentColor
                )

                Spacer()

                Text(
                    "\(selection.count)"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

            ScrollView {
                LazyVStack(
                    spacing:
                        3
                ) {
                    ForEach(
                        selectedEntities
                    ) {
                        entity in

                        selectedEntityRow(
                            entity
                        )
                    }
                }
                .padding(
                    4
                )
            }
            .frame(
                maxHeight:
                    145
            )
        }
        .padding(
            10
        )
        .background(
            Color.accentColor
                .opacity(
                    0.055
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        11,
                    style:
                        .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    11,
                style:
                    .continuous
            )
            .stroke(
                Color.accentColor
                    .opacity(
                        0.18
                    ),
                lineWidth:
                    1
            )
        }
    }


    private func selectedEntityRow(
        _ entity: Entity
    ) -> some View {
        HStack(
            spacing:
                9
        ) {
            Image(
                systemName:
                    entityIcon(
                        entity
                    )
            )
            .font(
                .system(
                    size: 13
                )
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width: 18
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    1
            ) {
                Text(
                    entity.name
                )
                .lineLimit(1)

                Text(
                    entity.kind
                        .displayName
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Button {
                selection.remove(
                    entity.id
                )

            } label: {
                Image(
                    systemName:
                        "xmark.circle.fill"
                )
                .font(
                    .system(
                        size: 14
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 24,
                    height: 24
                )
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .help(
                "Remove \(entity.name)"
            )
        }
        .padding(
            .horizontal,
            8
        )
        .padding(
            .vertical,
            6
        )
        .background(
            Color.primary
                .opacity(
                    0.025
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        8,
                    style:
                        .continuous
                )
        )
    }


    // ========================================================
    // Tabs
    // ========================================================

    private var tabSelector:
        some View
    {
        Picker(
            "",
            selection:
                $activeTab
        ) {
            ForEach(
                tabs
            ) {
                tab in

                Text(tab.title)
                    .tag(tab)
            }
        }
        .labelsHidden()
        .pickerStyle(
            .segmented
        )
    }


    // ========================================================
    // Search
    // ========================================================

    private var searchField:
        some View
    {
        HStack(
            spacing:
                8
        ) {
            Image(
                systemName:
                    "magnifyingglass"
            )
            .foregroundStyle(
                .secondary
            )

            TextField(
                "Search \(activeTab.title.lowercased())",
                text:
                    $searchText
            )
            .textFieldStyle(
                .plain
            )

            if
                !searchText
                    .isEmpty
            {
                Button {
                    searchText =
                        ""

                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                }
                .buttonStyle(
                    .plain
                )
            }
        }
        .padding(
            .horizontal,
            10
        )
        .frame(
            height: 34
        )
        .background(
            Color.primary
                .opacity(
                    0.035
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        9,
                    style:
                        .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    9,
                style:
                    .continuous
            )
            .stroke(
                Color.primary
                    .opacity(
                        0.09
                    ),
                lineWidth:
                    1
            )
        }
    }


    // ========================================================
    // Inline creation
    // ========================================================

    private var addNewSection:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            HStack {
                Label(
                    "New \(activeTab.singularTitle)",
                    systemImage:
                        "plus.circle.fill"
                )
                .font(
                    .system(
                        size: 12,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    Color.accentColor
                )

                Spacer()

                Button {
                    cancelNewEntity()

                } label: {
                    Image(
                        systemName:
                            "xmark"
                    )
                    .font(
                        .system(
                            size: 10,
                            weight:
                                .semibold
                        )
                    )
                }
                .buttonStyle(
                    .plain
                )
                .foregroundStyle(
                    .secondary
                )
            }

            switch activeTab {
            case .people:
                HStack(
                    spacing:
                        8
                ) {
                    creationTextField(
                        "First name",
                        text:
                            $newPersonFirstName
                    )

                    creationTextField(
                        "Last name",
                        text:
                            $newPersonLastName
                    )
                }

            case .groups:
                creationTextField(
                    "Group name",
                    text:
                        $newEntityName
                )

            case .organizations:
                creationTextField(
                    "Organization name",
                    text:
                        $newEntityName
                )
            }

            if let creationErrorMessage {
                Text(
                    creationErrorMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .red
                )
            }

            HStack {
                Text(
                    "The new \(activeTab.singularTitle.lowercased()) will be created and selected immediately."
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )

                Spacer()

                Button(
                    "Cancel"
                ) {
                    cancelNewEntity()
                }

                Button(
                    "Create & Select"
                ) {
                    createNewEntity()
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    !canCreateNewEntity
                )
            }
        }
        .padding(
            12
        )
        .background(
            Color.accentColor
                .opacity(
                    0.045
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
                Color.accentColor
                    .opacity(
                        0.15
                    ),
                lineWidth:
                    1
            )
        }
    }


    private func creationTextField(
        _ prompt: String,
        text:
            Binding<String>
    ) -> some View {
        TextField(
            prompt,
            text:
                text
        )
        .textFieldStyle(
            .plain
        )
        .padding(
            .horizontal,
            10
        )
        .frame(
            height:
                34
        )
        .background(
            Color.primary
                .opacity(
                    0.035
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
                        0.10
                    ),
                lineWidth:
                    1
            )
        }
    }


    private var canCreateNewEntity:
        Bool
    {
        switch activeTab {
        case .people:
            return
                !newPersonFirstName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
                ||
                !newPersonLastName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty

        case .groups,
             .organizations:
            return
                !newEntityName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
        }
    }


    private func beginAddNew() {
        creationErrorMessage =
            nil

        showingAddNew =
            true
    }


    private func cancelNewEntity() {
        showingAddNew =
            false

        newEntityName =
            ""

        newPersonFirstName =
            ""

        newPersonLastName =
            ""

        creationErrorMessage =
            nil
    }


    private func createNewEntity() {
        let newID:
            UUID?

        switch activeTab {
        case .people:
            newID =
                store
                    .createPersonEntity(
                        firstName:
                            newPersonFirstName,
                        lastName:
                            newPersonLastName
                    )

        case .groups:
            newID =
                store
                    .createEntity(
                        kind:
                            .group,
                        name:
                            newEntityName,
                        initialContainerID:
                            nil
                    )

        case .organizations:
            newID =
                store
                    .createEntity(
                        kind:
                            .organization,
                        name:
                            newEntityName,
                        initialContainerID:
                            nil
                    )
        }

        guard
            let newID
        else {
            creationErrorMessage =
                "A name is required."

            return
        }

        locallyCreatedIDs
            .insert(
                newID
            )

        if
            maximumSelectionCount
                == 1
        {
            selection =
                [
                    newID
                ]
        } else {
            selection
                .insert(
                    newID
                )
        }

        searchText =
            ""

        cancelNewEntity()
    }


    // ========================================================
    // List
    // ========================================================

    private var listHeader:
        some View
    {
        HStack(
            spacing:
                10
        ) {
            Label(
                activeTab.title,
                systemImage:
                    activeTab
                        .systemImage
            )
            .font(
                .system(
                    size: 12,
                    weight:
                        .semibold
                )
            )

            Text(
                "\(visibleNodes.count)"
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            Spacer()

            Button {
                beginAddNew()

            } label: {
                Label(
                    "Add New \(activeTab.singularTitle)",
                    systemImage:
                        "plus"
                )
                .font(
                    .system(
                        size: 11,
                        weight:
                            .semibold
                    )
                )
                .padding(
                    .horizontal,
                    9
                )
                .frame(
                    height:
                        28
                )
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .foregroundStyle(
                Color.accentColor
            )
            .background(
                Color.accentColor
                    .opacity(
                        0.08
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
                    Color.accentColor
                        .opacity(
                            0.16
                        ),
                    lineWidth:
                        1
                )
            }
        }
    }


    @ViewBuilder
    private var entityList:
        some View
    {
        if visibleNodes.isEmpty {
            ContentUnavailableView {
                Label(
                    "No \(activeTab.title)",
                    systemImage:
                        activeTab
                            .systemImage
                )
            } description: {
                if
                    searchText
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                {
                    Text(
                        "There are no available \(activeTab.title.lowercased())."
                    )
                } else {
                    Text(
                        "No results match the current search."
                    )
                }
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )

        } else {
            ScrollView {
                LazyVStack(
                    spacing:
                        3
                ) {
                    ForEach(
                        visibleNodes
                    ) {
                        node in

                        entityRow(
                            node
                        )
                    }
                }
                .padding(
                    5
                )
            }
            .background(
                Color.primary
                    .opacity(
                        0.018
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
                            0.08
                        ),
                    lineWidth:
                        1
                )
            }
        }
    }


    private func entityRow(
        _ node:
            HierarchySelectionNode
    ) -> some View {
        let entityID =
            node.selectionID

        let selected =
            entityID
                .map {
                    selection.contains(
                        $0
                    )
                }
            ?? false

        return Button {
            guard
                let entityID
            else {
                return
            }

            toggle(
                entityID
            )

        } label: {
            HStack(
                spacing:
                    10
            ) {
                Image(
                    systemName:
                        selected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(
                    .system(
                        size: 14
                    )
                )
                .foregroundStyle(
                    selected
                    ? Color.accentColor
                    : Color.secondary
                        .opacity(
                            0.6
                        )
                )

                if let systemImage =
                    node.systemImage
                {
                    Image(
                        systemName:
                            systemImage
                    )
                    .font(
                        .system(
                            size: 13
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .frame(
                        width: 18
                    )
                }

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {
                    Text(
                        node.title
                    )
                    .foregroundStyle(
                        .primary
                    )
                    .lineLimit(1)

                    if
                        let subtitle =
                            node.subtitle,
                        !subtitle.isEmpty
                    {
                        Text(
                            subtitle
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                    }
                }

                Spacer()

                if selected {
                    Text(
                        "Selected"
                    )
                    .font(
                        .system(
                            size: 9,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
                    .padding(
                        .horizontal,
                        7
                    )
                    .padding(
                        .vertical,
                        3
                    )
                    .background(
                        Color.accentColor
                            .opacity(
                                0.10
                            ),
                        in:
                            Capsule()
                    )
                }
            }
            .padding(
                .leading,
                CGFloat(
                    node.depth
                ) * 22
            )
            .padding(
                .horizontal,
                9
            )
            .padding(
                .vertical,
                8
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .plain
        )
        .background(
            selected
            ? Color.accentColor
                .opacity(
                    0.08
                )
            : Color.clear,
            in:
                RoundedRectangle(
                    cornerRadius:
                        8,
                    style:
                        .continuous
                )
        )
    }


    // ========================================================
    // Footer
    // ========================================================

    private var footer:
        some View
    {
        HStack {
            Text(
                selection.count == 1
                ? "1 selected"
                : "\(selection.count) selected"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )

            Spacer()

            Button(
                "Cancel"
            ) {
                onCancel()
            }
            .keyboardShortcut(
                .cancelAction
            )

            Button(
                "Save"
            ) {
                let error =
                    onSave(
                        selection
                    )

                errorMessage =
                    error
            }
            .buttonStyle(
                .borderedProminent
            )
            .keyboardShortcut(
                .defaultAction
            )
        }
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            14
        )
    }


    // ========================================================
    // Data
    // ========================================================

    private var selectedEntities:
        [Entity]
    {
        selection
            .compactMap {
                store.entity(
                    id:
                        $0
                )
            }
            .sorted {
                lhs,
                rhs in

                let lhsRank =
                    entityKindRank(
                        lhs.kind
                    )

                let rhsRank =
                    entityKindRank(
                        rhs.kind
                    )

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                if
                    lhs.kind == .person,
                    rhs.kind == .person
                {
                    return personSurnameSort(
                        lhs,
                        rhs
                    )
                }

                return lhs.name
                    .localizedCaseInsensitiveCompare(
                        rhs.name
                    )
                    == .orderedAscending
            }
    }


    private func entityKindRank(
        _ kind: EntityKind
    ) -> Int {
        switch kind {
        case .person:
            return 0

        case .group:
            return 1

        case .organization:
            return 2
        }
    }


    private func entityIcon(
        _ entity: Entity
    ) -> String {
        switch entity.kind {
        case .person:
            return "person.crop.circle"

        case .group:
            return "person.3"

        case .organization:
            return "building.2"
        }
    }


    private var candidates:
        [Entity]
    {
        store.data.entities
            .filter {
                $0.kind
                    == activeTab.kind
            }
            .filter {
                !excludedIDs
                    .contains(
                        $0.id
                    )
            }
            .filter {
                guard
                    let candidateIDs
                else {
                    return true
                }

                return
                    candidateIDs
                        .contains(
                            $0.id
                        )
                    ||
                    locallyCreatedIDs
                        .contains(
                            $0.id
                        )
            }
    }


    private var nodes:
        [HierarchySelectionNode]
    {
        switch activeTab {
        case .people:
            return peopleNodes

        case .groups,
             .organizations:
            return
                HierarchySelectionData
                    .entityNodes(
                        store:
                            store,
                        candidates:
                            candidates
                    )
        }
    }


    private var peopleNodes:
        [HierarchySelectionNode]
    {
        candidates
            .sorted { personSurnameSort($0, $1) }
            .map {
                person in

                let profile =
                    store.personProfile(
                        for:
                            person.id
                    )

                let surname =
                    profile?
                        .lastName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                    ?? ""

                let firstName =
                    profile?
                        .firstName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                    ?? ""

                let searchable =
                    [
                        person.name,
                        firstName,
                        surname
                    ]
                    .filter {
                        !$0.isEmpty
                    }
                    .joined(
                        separator:
                            " "
                    )

                return
                    HierarchySelectionNode(
                        id:
                            "entity-selector-person:\(person.id.uuidString)",
                        selectionID:
                            person.id,
                        parentID:
                            nil,
                        title:
                            person.name,
                        subtitle:
                            nil,
                        systemImage:
                            "person.crop.circle",
                        depth:
                            0,
                        searchText:
                            searchable
                    )
            }
    }


    private func personSurnameSort(
        _ lhs: Entity,
        _ rhs: Entity
    ) -> Bool {
        let lhsProfile =
            store.personProfile(
                for:
                    lhs.id
            )

        let rhsProfile =
            store.personProfile(
                for:
                    rhs.id
            )

        let lhsSurname =
            lhsProfile?
                .lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let rhsSurname =
            rhsProfile?
                .lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let lhsPrimary =
            lhsSurname.isEmpty
            ? lhs.name
            : lhsSurname

        let rhsPrimary =
            rhsSurname.isEmpty
            ? rhs.name
            : rhsSurname

        let surnameComparison =
            lhsPrimary
                .localizedCaseInsensitiveCompare(
                    rhsPrimary
                )

        if surnameComparison
            != .orderedSame
        {
            return surnameComparison
                == .orderedAscending
        }

        let lhsFirst =
            lhsProfile?
                .firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let rhsFirst =
            rhsProfile?
                .firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let firstComparison =
            lhsFirst
                .localizedCaseInsensitiveCompare(
                    rhsFirst
                )

        if firstComparison
            != .orderedSame
        {
            return firstComparison
                == .orderedAscending
        }

        return lhs.name
            .localizedCaseInsensitiveCompare(
                rhs.name
            )
            == .orderedAscending
    }


    private var visibleNodes:
        [HierarchySelectionNode]
    {
        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard
            !query.isEmpty
        else {
            return nodes
        }

        let byID =
            Dictionary(
                uniqueKeysWithValues:
                    nodes.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )

        var included =
            Set(
                nodes
                    .filter {
                        $0.title
                            .lowercased()
                            .contains(
                                query
                            )
                        ||
                        $0.searchText
                            .lowercased()
                            .contains(
                                query
                            )
                    }
                    .map(
                        \.id
                    )
            )

        var queue =
            Array(
                included
            )

        while
            let nodeID =
                queue.popLast()
        {
            guard
                let parentID =
                    byID[nodeID]?
                        .parentID
            else {
                continue
            }

            if
                included
                    .insert(
                        parentID
                    )
                    .inserted
            {
                queue.append(
                    parentID
                )
            }
        }

        return nodes
            .filter {
                included.contains(
                    $0.id
                )
            }
    }


    private func toggle(
        _ id: UUID
    ) {
        if selection.contains(
            id
        ) {
            selection.remove(
                id
            )

            return
        }

        if
            maximumSelectionCount
                == 1
        {
            selection =
                [id]

            return
        }

        if
            let maximumSelectionCount,
            selection.count
                >= maximumSelectionCount
        {
            return
        }

        selection.insert(
            id
        )
    }
}
