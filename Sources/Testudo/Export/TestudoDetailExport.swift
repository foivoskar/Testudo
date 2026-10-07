import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers


enum TestudoPDFExportTarget:
    Equatable
{
    case work(UUID)
    case theme(UUID)
    case organization(UUID)
    case group(UUID)
    case person(UUID)
    case calendarEvent(UUID)
    case day(Date)
}


struct TestudoDetailExportAction
{
    let perform:
        () -> Void
}


private struct TestudoDetailExportActionKey:
    FocusedValueKey
{
    typealias Value =
        TestudoDetailExportAction
}


extension FocusedValues
{
    var testudoDetailExportAction:
        TestudoDetailExportAction?
    {
        get {
            self[
                TestudoDetailExportActionKey
                    .self
            ]
        }

        set {
            self[
                TestudoDetailExportActionKey
                    .self
            ] =
                newValue
        }
    }
}


struct TestudoFileExportCommands:
    Commands
{
    @FocusedValue(
        \.testudoDetailExportAction
    )
    private var exportAction:
        TestudoDetailExportAction?


    var body:
        some Commands
    {
        CommandGroup(
            after:
                .saveItem
        ) {
            Button(
                "Export…"
            ) {
                exportAction?
                    .perform()
            }
            .disabled(
                exportAction
                    == nil
            )
        }
    }
}


struct TestudoDetailExportSheet:
    View
{
    @Environment(
        \.dismiss
    )
    private var dismiss

    let maximumDepth:
        Int

    let onExportPDF:
        (Int?) -> Void

    @State
    private var includeNestedItems =
        false

    @State
    private var depth:
        Int


    init(
        maximumDepth:
            Int,
        onExportPDF:
            @escaping (Int?) -> Void
    ) {
        self.maximumDepth =
            max(
                0,
                maximumDepth
            )

        self.onExportPDF =
            onExportPDF

        self._depth =
            State(
                initialValue:
                    max(
                        1,
                        maximumDepth
                    )
            )
    }


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                20
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(
                    "Export"
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )

                Text(
                    "Create a PDF from the current detail content."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Divider()

            LabeledContent(
                "Format"
            ) {
                Text(
                    "PDF"
                )
            }

            if maximumDepth > 0 {
                Divider()

                Toggle(
                    "Include nested items",
                    isOn:
                        $includeNestedItems
                )

                if includeNestedItems {
                    Picker(
                        "Depth",
                        selection:
                            $depth
                    ) {
                        ForEach(
                            1...maximumDepth,
                            id:
                                \.self
                        ) {
                            level in

                            if
                                level
                                    == maximumDepth
                            {
                                Text(
                                    "\(level) — Full depth"
                                )
                                .tag(
                                    level
                                )

                            } else {
                                Text(
                                    "\(level)"
                                )
                                .tag(
                                    level
                                )
                            }
                        }
                    }

                    Text(
                        "Level 1 includes direct children. The maximum value follows the deepest branch of the selected Task."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Divider()

            HStack {
                Spacer()

                Button(
                    "Cancel"
                ) {
                    dismiss()
                }

                Button(
                    "Export PDF…"
                ) {
                    let requestedDepth:
                        Int?

                    if
                        includeNestedItems,
                        maximumDepth > 0
                    {
                        requestedDepth =
                            min(
                                depth,
                                maximumDepth
                            )

                    } else {
                        requestedDepth =
                            nil
                    }

                    onExportPDF(
                        requestedDepth
                    )
                }
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(
            24
        )
        .frame(
            width:
                440
        )
    }
}


@MainActor
enum TestudoSemanticPDFExporter
{
    static func maximumDepth(
        for target:
            TestudoPDFExportTarget?,
        store:
            TestudoStore
    ) -> Int
    {
        guard
            case
                .work(
                    let rootID
                )? =
                target,
            let root =
                store.workItem(
                    id:
                        rootID
                ),
            root.kind
                == .task
        else {
            return 0
        }

        func calculate(
            _ id:
                UUID,
            visited:
                Set<UUID>
        ) -> Int
        {
            guard
                !visited.contains(
                    id
                )
            else {
                return 0
            }

            var nextVisited =
                visited

            nextVisited.insert(
                id
            )

            let children =
                store.childWorkItems(
                    of:
                        id
                )

            guard
                !children.isEmpty
            else {
                return 0
            }

            return
                1
                + (
                    children
                        .map {
                            calculate(
                                $0.id,
                                visited:
                                    nextVisited
                            )
                        }
                        .max()
                    ?? 0
                )
        }

        return
            calculate(
                rootID,
                visited:
                    []
            )
    }


    static func export(
        target:
            TestudoPDFExportTarget,
        store:
            TestudoStore,
        expansionDepth:
            Int?
    )
    {
        let document =
            makeDocument(
                target:
                    target,
                store:
                    store,
                expansionDepth:
                    max(
                        0,
                        expansionDepth
                        ?? 0
                    )
            )

        guard
            document.length > 0
        else {
            NSSound.beep()
            return
        }

        let panel =
            NSSavePanel()

        panel.allowedContentTypes =
            [
                .pdf
            ]

        panel.canCreateDirectories =
            true

        panel.nameFieldStringValue =
            pdfFilename(
                target:
                    target,
                store:
                    store
            )

        guard
            panel.runModal()
                == .OK,
            let destination =
                panel.url
        else {
            return
        }

        let printInfo =
            NSPrintInfo.shared
                .copy()
                as! NSPrintInfo

        printInfo.topMargin =
            42

        printInfo.bottomMargin =
            42

        printInfo.leftMargin =
            48

        printInfo.rightMargin =
            48

        printInfo.horizontalPagination =
            .fit

        printInfo.verticalPagination =
            .automatic

        printInfo.isHorizontallyCentered =
            false

        printInfo.isVerticallyCentered =
            false

        printInfo.scalingFactor =
            1

        printInfo.jobDisposition =
            .save

        printInfo
            .dictionary()[
                NSPrintInfo
                    .AttributeKey
                    .jobSavingURL
            ] =
                destination
                as NSURL

        let width =
            max(
                320,
                printInfo.paperSize.width
                    - printInfo.leftMargin
                    - printInfo.rightMargin
            )

        let textView =
            printableTextView(
                document:
                    document,
                width:
                    width
            )

        let operation =
            NSPrintOperation(
                view:
                    textView,
                printInfo:
                    printInfo
            )

        operation.showsPrintPanel =
            false

        operation.showsProgressPanel =
            true

        if !operation.run() {
            NSSound.beep()
        }
    }


    private static func printableTextView(
        document:
            NSAttributedString,
        width:
            CGFloat
    ) -> NSTextView
    {
        let textView =
            NSTextView(
                frame:
                    NSRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            width,
                        height:
                            100
                    )
            )

        textView.isEditable =
            false

        textView.isSelectable =
            true

        textView.isRichText =
            true

        textView.drawsBackground =
            false

        textView.isHorizontallyResizable =
            false

        textView.isVerticallyResizable =
            true

        textView.textContainerInset =
            NSSize(
                width:
                    0,
                height:
                    8
            )

        if
            let container =
                textView.textContainer
        {
            container.widthTracksTextView =
                true

            container.containerSize =
                NSSize(
                    width:
                        width,
                    height:
                        CGFloat
                            .greatestFiniteMagnitude
                )

            container.lineFragmentPadding =
                0
        }

        textView.textStorage?
            .setAttributedString(
                document
            )

        if
            let layoutManager =
                textView.layoutManager,
            let container =
                textView.textContainer
        {
            layoutManager.ensureLayout(
                for:
                    container
            )

            let used =
                layoutManager.usedRect(
                    for:
                        container
                )

            textView.frame.size.height =
                ceil(
                    used.height
                        + 24
                )
        }

        return
            textView
    }


    private static func makeDocument(
        target:
            TestudoPDFExportTarget,
        store:
            TestudoStore,
        expansionDepth:
            Int
    ) -> NSAttributedString
    {
        let builder =
            TestudoPDFTextBuilder()

        switch target {
        case
            .work(
                let id
            ):

            if
                let item =
                    store.workItem(
                        id:
                            id
                    )
            {
                var visited =
                    Set<UUID>()

                appendWork(
                    item,
                    store:
                        store,
                    builder:
                        builder,
                    hierarchyLevel:
                        0,
                    remainingDepth:
                        expansionDepth,
                    visited:
                        &visited
                )
            }

        case
            .theme(
                let id
            ):

            appendTheme(
                id:
                    id,
                store:
                    store,
                builder:
                    builder
            )

        case
            .organization(
                let id
            ),
            .group(
                let id
            ):

            appendEntity(
                id:
                    id,
                store:
                    store,
                builder:
                    builder
            )

        case
            .person(
                let id
            ):

            appendPerson(
                id:
                    id,
                store:
                    store,
                builder:
                    builder
            )

        case
            .calendarEvent(
                let id
            ):

            appendCalendarEvent(
                id:
                    id,
                store:
                    store,
                builder:
                    builder
            )

        case
            .day(
                let date
            ):

            appendDay(
                date:
                    date,
                store:
                    store,
                builder:
                    builder
            )
        }

        return
            builder.output
    }


    private static func appendWork(
        _ item:
            WorkItem,
        store:
            TestudoStore,
        builder:
            TestudoPDFTextBuilder,
        hierarchyLevel:
            Int,
        remainingDepth:
            Int,
        visited:
            inout Set<UUID>
    )
    {
        guard
            visited
                .insert(
                    item.id
                )
                .inserted
        else {
            return
        }

        let indent =
            CGFloat(
                min(
                    hierarchyLevel,
                    8
                )
            )
            * 18

        if hierarchyLevel > 0 {
            builder.separator(
                indent:
                    indent
            )
        }

        var headerMetadata:
            [String] = []

        if
            item.kind == .task,
            hierarchyLevel > 0
        {
            headerMetadata.append(
                "Sub-task"
            )

        } else {
            headerMetadata.append(
                item.kind
                    .displayName
            )
        }

        let headerThemes =
            store.workThemes(
                for:
                    item.id
            )

        if
            let firstTheme =
                headerThemes.first
        {
            var themeText =
                firstTheme.name

            if headerThemes.count > 1 {
                themeText +=
                    " +\(headerThemes.count - 1)"
            }

            headerMetadata.append(
                themeText
            )
        }

        if
            item.kind == .task,
            let status =
                item.status
        {
            headerMetadata.append(
                status.displayName
            )
        }

        builder.header(
            title:
                workTitle(
                    item
                ),
            symbolName:
                workSymbol(
                    item
                ),
            metadata:
                headerMetadata,
            indent:
                indent,
            nested:
                hierarchyLevel > 0
        )

        builder.section(
            item.kind == .task
            ? "Description"
            : (
                item.kind == .note
                ? "Note"
                : "What happened?"
            ),
            indent:
                indent
        )

        let body =
            item.body
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if body.isEmpty {
            builder.secondary(
                "No content",
                indent:
                    indent
            )

        } else {
            builder.markdown(
                body,
                indent:
                    indent
            )
        }

        builder.section(
            "Details",
            indent:
                indent
        )

        if
            item.kind == .task,
            let status =
                item.status
        {
            builder.field(
                "Status",
                status.displayName,
                indent:
                    indent
            )
        }

        let themeNames =
            themeIDs(
                for:
                    item
            )
            .compactMap {
                store.theme(
                    id:
                        $0
                )?
                .name
            }

        if !themeNames.isEmpty {
            builder.field(
                "Themes",
                themeNames
                    .joined(
                        separator:
                            ", "
                    ),
                indent:
                    indent
            )
        }

        if
            let parentID =
                item.parentWorkItemID,
            let parent =
                store.workItem(
                    id:
                        parentID
                )
        {
            builder.field(
                "Parent Task",
                workTitle(
                    parent
                ),
                indent:
                    indent
            )
        }

        appendDateField(
            "Scheduled",
            date:
                item.scheduledAt,
            timeZoneID:
                item.scheduledTimeZoneID,
            builder:
                builder,
            indent:
                indent
        )

        appendDateField(
            "Deadline",
            date:
                item.deadlineAt,
            timeZoneID:
                item.deadlineTimeZoneID,
            builder:
                builder,
            indent:
                indent
        )

        appendDateField(
            "Reminder",
            date:
                item.reminderAt,
            timeZoneID:
                item.reminderTimeZoneID,
            builder:
                builder,
            indent:
                indent
        )

        if item.kind == .activity {
            appendDateField(
                "Occurred",
                date:
                    item.loggedAt,
                timeZoneID:
                    item.loggedTimeZoneID,
                builder:
                    builder,
                indent:
                    indent
            )
        }

        if
            let reason =
                item.discontinuationReason
        {
            builder.field(
                "Discontinuation reason",
                reason.displayName,
                indent:
                    indent
            )
        }

        if
            let note =
                cleaned(
                    item.discontinuationNote
                )
        {
            builder.field(
                "Outcome",
                note,
                indent:
                    indent
            )
        }

        let children =
            store.childWorkItems(
                of:
                    item.id
            )

        if !children.isEmpty {
            builder.section(
                "Contains",
                indent:
                    indent
            )

            for child in children {
                var text =
                    workTitle(
                        child
                    )

                if
                    child.kind == .task,
                    let status =
                        child.status
                {
                    text +=
                        " · \(status.displayName)"

                } else {
                    text +=
                        " · \(child.kind.displayName)"
                }

                builder.iconRow(
                    symbolName:
                        workSymbol(
                            child
                        ),
                    text:
                        text,
                    indent:
                        indent
                )
            }
        }

        let relationships =
            store.data
                .workEntityRelationships
                .filter {
                    $0.workItemID
                        == item.id
                }

        if !relationships.isEmpty {
            builder.section(
                "Related People, Groups & Organizations",
                indent:
                    indent
            )

            for role in
                WorkRelationshipRole
                    .allCases
            {
                let names =
                    relationships
                        .filter {
                            $0.role
                                == role
                        }
                        .compactMap {
                            store.entity(
                                id:
                                    $0.entityID
                            )?
                            .name
                        }

                if !names.isEmpty {
                    builder.field(
                        role.displayName,
                        names
                            .joined(
                                separator:
                                    ", "
                            ),
                        indent:
                            indent
                    )
                }
            }
        }

        builder.section(
            "History",
            indent:
                indent
        )

        builder.field(
            "Created",
            displayDate(
                item.createdAt,
                timeZoneID:
                    item.createdTimeZoneID
            ),
            indent:
                indent
        )

        builder.field(
            "Updated",
            displayDate(
                item.updatedAt,
                timeZoneID:
                    item.updatedTimeZoneID
            ),
            indent:
                indent
        )

        appendDateField(
            "Started",
            date:
                item.startedAt,
            timeZoneID:
                item.startedTimeZoneID,
            builder:
                builder,
            indent:
                indent
        )

        appendDateField(
            "Completed",
            date:
                item.completedAt,
            timeZoneID:
                item.completedTimeZoneID,
            builder:
                builder,
            indent:
                indent
        )

        appendDateField(
            "Discontinued",
            date:
                item.discontinuedAt,
            timeZoneID:
                item.discontinuedTimeZoneID,
            builder:
                builder,
            indent:
                indent
        )

        appendDateField(
            "Closed",
            date:
                item.closedAt,
            timeZoneID:
                item.closedTimeZoneID,
            builder:
                builder,
            indent:
                indent
        )

        guard
            remainingDepth > 0
        else {
            return
        }

        for child in children {
            appendWork(
                child,
                store:
                    store,
                builder:
                    builder,
                hierarchyLevel:
                    hierarchyLevel
                        + 1,
                remainingDepth:
                    remainingDepth
                        - 1,
                visited:
                    &visited
            )
        }
    }


    private static func appendTheme(
        id:
            UUID,
        store:
            TestudoStore,
        builder:
            TestudoPDFTextBuilder
    )
    {
        guard
            let theme =
                store.theme(
                    id:
                        id
                )
        else {
            return
        }

        builder.header(
            title:
                theme.name,
            symbolName:
                theme.symbolName
                ?? "folder",
            metadata:
                [
                    "Theme"
                ]
        )

        if
            let summary =
                cleaned(
                    theme.summary
                )
        {
            builder.section(
                "Summary"
            )

            builder.markdown(
                summary
            )
        }

        builder.section(
            "Details"
        )

        if
            let parentID =
                theme.parentThemeID,
            let parent =
                store.theme(
                    id:
                        parentID
                )
        {
            builder.field(
                "Parent Theme",
                parent.name
            )
        }

        if let status =
            theme.status
        {
            builder.field(
                "Status",
                status.displayName
            )
        }

        if let priority =
            theme.priority
        {
            builder.field(
                "Priority",
                priority.displayName
            )
        }

        appendOptionalField(
            "Code",
            theme.code,
            builder:
                builder
        )

        if
            let ownerID =
                theme.ownerEntityID,
            let owner =
                store.entity(
                    id:
                        ownerID
                )
        {
            builder.field(
                "Owner",
                owner.name
            )
        }

        appendSimpleDateField(
            "Start",
            date:
                theme.startDate,
            builder:
                builder
        )

        appendSimpleDateField(
            "Target",
            date:
                theme.targetDate,
            builder:
                builder
        )

        appendOptionalField(
            "Tags",
            theme.tags,
            builder:
                builder
        )

        appendOptionalField(
            "URL",
            theme.url,
            builder:
                builder
        )

        let children =
            store.childThemes(
                of:
                    theme.id
            )

        if !children.isEmpty {
            builder.section(
                "Sub-themes"
            )

            for child in children {
                builder.bullet(
                    child.name
                )
            }
        }

        let notes =
            theme.notes
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !notes.isEmpty {
            builder.section(
                "Notes"
            )

            builder.markdown(
                notes
            )
        }

        let relatedWork =
            store.data
                .workItems
                .filter {
                    themeIDs(
                        for:
                            $0
                    )
                    .contains(
                        theme.id
                    )
                }

        appendWorkList(
            title:
                "Related Work",
            work:
                relatedWork,
            builder:
                builder
        )

        builder.section(
            "History"
        )

        builder.field(
            "Created",
            displayDate(
                theme.createdAt,
                timeZoneID:
                    nil
            )
        )

        builder.field(
            "Updated",
            displayDate(
                theme.updatedAt,
                timeZoneID:
                    nil
            )
        )
    }


    private static func appendEntity(
        id:
            UUID,
        store:
            TestudoStore,
        builder:
            TestudoPDFTextBuilder
    )
    {
        guard
            let entity =
                store.entity(
                    id:
                        id
                )
        else {
            return
        }

        builder.header(
            title:
                entity.name,
            symbolName:
                entity.symbolName
                ?? defaultEntitySymbol(
                    entity
                ),
            metadata:
                [
                    entity.kind
                        .displayName
                ]
        )

        builder.section(
            "Details"
        )

        appendOptionalField(
            "Short name",
            entity.shortName,
            builder:
                builder
        )

        appendOptionalField(
            "Code",
            entity.code,
            builder:
                builder
        )

        if let status =
            entity.status
        {
            builder.field(
                "Status",
                status.displayName
            )
        }

        if let priority =
            entity.priority
        {
            builder.field(
                "Priority",
                priority.displayName
            )
        }

        appendOptionalField(
            "Website",
            entity.website,
            builder:
                builder
        )

        appendOptionalField(
            "Email",
            entity.email,
            builder:
                builder
        )

        appendOptionalField(
            "Phone",
            entity.phone,
            builder:
                builder
        )

        appendOptionalField(
            "Address",
            entity.address,
            builder:
                builder
        )

        appendOptionalField(
            "City",
            entity.city,
            builder:
                builder
        )

        appendOptionalField(
            "Postal code",
            entity.postalCode,
            builder:
                builder
        )

        appendOptionalField(
            "Country",
            entity.country,
            builder:
                builder
        )

        appendOptionalField(
            "Tags",
            entity.tags,
            builder:
                builder
        )

        let containers =
            store.data
                .memberships
                .filter {
                    $0.memberEntityID
                        == entity.id
                }
                .compactMap {
                    store.entity(
                        id:
                            $0.containerEntityID
                    )
                }

        if !containers.isEmpty {
            builder.field(
                "Contained in",
                containers
                    .map(
                        \.name
                    )
                    .joined(
                        separator:
                            ", "
                    )
            )
        }

        let notes =
            entity.notes
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !notes.isEmpty {
            builder.section(
                "Notes"
            )

            builder.markdown(
                notes
            )
        }

        appendRelatedWork(
            entityID:
                entity.id,
            store:
                store,
            builder:
                builder
        )

        builder.section(
            "History"
        )

        builder.field(
            "Created",
            displayDate(
                entity.createdAt,
                timeZoneID:
                    nil
            )
        )

        builder.field(
            "Updated",
            displayDate(
                entity.updatedAt,
                timeZoneID:
                    nil
            )
        )
    }


    private static func appendPerson(
        id:
            UUID,
        store:
            TestudoStore,
        builder:
            TestudoPDFTextBuilder
    )
    {
        guard
            let person =
                store.entity(
                    id:
                        id
                )
        else {
            return
        }

        let profile =
            store.personProfile(
                for:
                    id
            )

        let profileName =
            profile?
                .displayName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let personTitle =
            profileName?
                .isEmpty == false
            ? profileName!
            : person.name

        let affiliations =
            store.data
                .memberships
                .filter {
                    $0.memberEntityID
                        == id
                }
                .compactMap {
                    store.entity(
                        id:
                            $0.containerEntityID
                    )
                }

        var personMetadata:
            [String] = []

        if
            let academic =
                cleaned(
                    profile?
                        .academicTitle
                )
        {
            personMetadata.append(
                academic
            )
        }

        if
            let job =
                cleaned(
                    profile?
                        .jobTitle
                )
        {
            personMetadata.append(
                job
            )
        }

        if !affiliations.isEmpty {
            personMetadata.append(
                affiliations
                    .map(
                        \.name
                    )
                    .joined(
                        separator:
                            ", "
                    )
            )
        }

        builder.personHeader(
            title:
                personTitle,
            avatarData:
                profile?
                    .avatarData,
            initial:
                personInitial(
                    person:
                        person,
                    profile:
                        profile
                ),
            metadata:
                personMetadata
        )

        builder.section(
            "Profile"
        )

        if let profile {
            appendOptionalField(
                "First name",
                profile.firstName,
                builder:
                    builder
            )

            appendOptionalField(
                "Middle name",
                profile.middleName,
                builder:
                    builder
            )

            appendOptionalField(
                "Last name",
                profile.lastName,
                builder:
                    builder
            )

            appendOptionalField(
                "Preferred name",
                profile.preferredName,
                builder:
                    builder
            )

            appendOptionalField(
                "Academic title",
                profile.academicTitle,
                builder:
                    builder
            )

            appendOptionalField(
                "Position",
                profile.jobTitle,
                builder:
                    builder
            )

            appendOptionalField(
                "Professional email",
                profile.professionalEmail,
                builder:
                    builder
            )

            appendOptionalField(
                "Secondary email",
                profile.secondaryProfessionalEmail,
                builder:
                    builder
            )

            appendOptionalField(
                "Phone",
                profile.professionalPhone,
                builder:
                    builder
            )

            appendOptionalField(
                "Secondary phone",
                profile.secondaryPhone,
                builder:
                    builder
            )

            appendOptionalField(
                "Office",
                profile.office,
                builder:
                    builder
            )

            appendOptionalField(
                "Website",
                profile.website,
                builder:
                    builder
            )

            appendOptionalField(
                "ORCID",
                profile.orcid,
                builder:
                    builder
            )

            appendOptionalField(
                "ResearcherID",
                profile.researcherID,
                builder:
                    builder
            )

            appendOptionalField(
                "Scopus Author ID",
                profile.scopusAuthorID,
                builder:
                    builder
            )

            appendOptionalField(
                "Google Scholar",
                profile.googleScholarURL,
                builder:
                    builder
            )

            appendOptionalField(
                "LinkedIn",
                profile.linkedIn,
                builder:
                    builder
            )

            appendOptionalField(
                "GitHub",
                profile.github,
                builder:
                    builder
            )

            appendOptionalField(
                "Fields",
                profile.professionalFields,
                builder:
                    builder
            )

            appendOptionalField(
                "Responsibilities",
                profile.responsibilities,
                builder:
                    builder
            )

            appendOptionalField(
                "Preferred language",
                profile.preferredLanguage,
                builder:
                    builder
            )

            appendOptionalField(
                "Time zone",
                profile.timeZone,
                builder:
                    builder
            )
        }

        if !affiliations.isEmpty {
            builder.section(
                "Affiliations"
            )

            for affiliation in
                affiliations
            {
                builder.bullet(
                    "\(affiliation.name) · \(affiliation.kind.displayName)"
                )
            }
        }

        appendRelatedWork(
            entityID:
                id,
            store:
                store,
            builder:
                builder
        )

        let notes =
            profile?
                .notes
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? person.notes
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !notes.isEmpty {
            builder.section(
                "Notes"
            )

            builder.markdown(
                notes
            )
        }

        builder.section(
            "History"
        )

        builder.field(
            "Created",
            displayDate(
                profile?
                    .createdAt
                ?? person.createdAt,
                timeZoneID:
                    nil
            )
        )

        builder.field(
            "Updated",
            displayDate(
                profile?
                    .updatedAt
                ?? person.updatedAt,
                timeZoneID:
                    nil
            )
        )
    }


    private static func appendCalendarEvent(
        id:
            UUID,
        store:
            TestudoStore,
        builder:
            TestudoPDFTextBuilder
    )
    {
        guard
            let event =
                store.calendarEvent(
                    id:
                        id
                )
        else {
            return
        }

        builder.header(
            title:
                event.title,
            symbolName:
                event.isAllDay
                ? "calendar"
                : "calendar.badge.clock",
            metadata:
                [
                    "Calendar Event"
                ]
        )

        builder.section(
            "Details"
        )

        if
            let calendarID =
                event.calendarID,
            let calendar =
                store.data
                    .calendars
                    .first(
                        where: {
                            $0.id
                                == calendarID
                        }
                    )
        {
            builder.field(
                "Calendar",
                calendar.name
            )

            builder.field(
                "Source",
                (
                    calendar.sourceKind
                        ?? .local
                )
                .displayName
            )
        }

        builder.field(
            "Status",
            event.status
                .displayName
        )

        builder.field(
            "All day",
            event.isAllDay
            ? "Yes"
            : "No"
        )

        builder.field(
            "Start",
            displayDate(
                event.startAt,
                timeZoneID:
                    event.startTimeZoneID
            )
        )

        builder.field(
            "End",
            displayDate(
                event.endAt,
                timeZoneID:
                    event.endTimeZoneID
            )
        )

        appendOptionalField(
            "Location",
            event.location,
            builder:
                builder
        )

        appendOptionalField(
            "Organizer",
            event.organizerName,
            builder:
                builder
        )

        appendOptionalField(
            "Organizer email",
            event.organizerEmail,
            builder:
                builder
        )

        if !event.attendeeEmails.isEmpty {
            builder.field(
                "Attendees",
                event.attendeeEmails
                    .joined(
                        separator:
                            ", "
                    )
            )
        }

        appendOptionalField(
            "Conference",
            event.conferenceURL,
            builder:
                builder
        )

        let notes =
            event.notes
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !notes.isEmpty {
            builder.section(
                "Notes"
            )

            builder.markdown(
                notes
            )
        }

        let linkedWork =
            store.data
                .calendarEventWorkLinks
                .filter {
                    $0.calendarEventID
                        == event.id
                }
                .compactMap {
                    store.workItem(
                        id:
                            $0.workItemID
                    )
                }

        appendWorkList(
            title:
                "Related Work",
            work:
                linkedWork,
            builder:
                builder
        )

        let linkedThemes =
            store.data
                .calendarEventThemeLinks
                .filter {
                    $0.calendarEventID
                        == event.id
                }
                .compactMap {
                    store.theme(
                        id:
                            $0.themeID
                    )
                }

        if !linkedThemes.isEmpty {
            builder.section(
                "Related Themes"
            )

            for theme in linkedThemes {
                builder.bullet(
                    theme.name
                )
            }
        }

        builder.section(
            "History"
        )

        builder.field(
            "Created",
            displayDate(
                event.createdAt,
                timeZoneID:
                    nil
            )
        )

        builder.field(
            "Updated",
            displayDate(
                event.updatedAt,
                timeZoneID:
                    nil
            )
        )
    }


    private static func appendDay(
        date:
            Date,
        store:
            TestudoStore,
        builder:
            TestudoPDFTextBuilder
    )
    {
        let calendar =
            Calendar.autoupdatingCurrent

        builder.header(
            title:
                date.formatted(
                    .dateTime
                        .weekday(
                            .wide
                        )
                        .day()
                        .month(
                            .wide
                        )
                        .year()
                ),
            symbolName:
                "calendar",
            metadata:
                [
                    "Day"
                ]
        )

        builder.section(
            "Schedule"
        )

        let events =
            store.calendarEvents(
                on:
                    date
            )

        if events.isEmpty {
            builder.secondary(
                "No calendar events."
            )

        } else {
            for event in events {
                let timeText =
                    event.isAllDay
                    ? "All day"
                    : event.startAt
                        .formatted(
                            date:
                                .omitted,
                            time:
                                .shortened
                        )

                builder.bullet(
                    "\(event.title) · \(timeText)"
                )
            }
        }

        let deadlines =
            store.data
                .workItems
                .filter {
                    item in

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

        let reminders =
            store.data
                .workItems
                .filter {
                    item in

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

        builder.section(
            "Due & Reminders"
        )

        if
            deadlines.isEmpty,
            reminders.isEmpty
        {
            builder.secondary(
                "No deadlines or reminders."
            )

        } else {
            if !deadlines.isEmpty {
                builder.subsection(
                    "Deadlines"
                )

                for item in deadlines {
                    builder.bullet(
                        workTitle(
                            item
                        )
                    )
                }
            }

            if !reminders.isEmpty {
                builder.subsection(
                    "Reminders"
                )

                for item in reminders {
                    builder.bullet(
                        workTitle(
                            item
                        )
                    )
                }
            }
        }

        let start =
            calendar.startOfDay(
                for:
                    date
            )

        let end =
            calendar.date(
                byAdding:
                    .day,
                value:
                    1,
                to:
                    start
            )
            ?? start.addingTimeInterval(
                86400
            )

        var history:
            [(Date, String)] = []

        for item in
            store.data.workItems
        {
            if
                item.createdAt >= start,
                item.createdAt < end
            {
                history.append(
                    (
                        item.createdAt,
                        "\(workTitle(item)) · Created"
                    )
                )
            }

            if
                let started =
                    item.startedAt,
                started >= start,
                started < end
            {
                history.append(
                    (
                        started,
                        "\(workTitle(item)) · Started"
                    )
                )
            }

            if
                let completed =
                    item.completedAt,
                completed >= start,
                completed < end
            {
                history.append(
                    (
                        completed,
                        "\(workTitle(item)) · Completed"
                    )
                )
            }

            if
                let discontinued =
                    item.discontinuedAt,
                discontinued >= start,
                discontinued < end
            {
                history.append(
                    (
                        discontinued,
                        "\(workTitle(item)) · Discontinued"
                    )
                )
            }
        }

        builder.section(
            "Day History"
        )

        if history.isEmpty {
            builder.secondary(
                "No Work history for this day."
            )

        } else {
            for entry in
                history.sorted(
                    by: {
                        $0.0 < $1.0
                    }
                )
            {
                builder.bullet(
                    "\(entry.0.formatted(date: .omitted, time: .shortened)) · \(entry.1)"
                )
            }
        }
    }


    private static func appendRelatedWork(
        entityID:
            UUID,
        store:
            TestudoStore,
        builder:
            TestudoPDFTextBuilder
    )
    {
        let workIDs =
            Set(
                store.data
                    .workEntityRelationships
                    .filter {
                        $0.entityID
                            == entityID
                    }
                    .map(
                        \.workItemID
                    )
            )

        let work =
            store.data
                .workItems
                .filter {
                    workIDs
                        .contains(
                            $0.id
                        )
                }

        appendWorkList(
            title:
                "Related Work",
            work:
                work,
            builder:
                builder
        )
    }


    private static func appendWorkList(
        title:
            String,
        work:
            [WorkItem],
        builder:
            TestudoPDFTextBuilder
    )
    {
        guard
            !work.isEmpty
        else {
            return
        }

        builder.section(
            title
        )

        for item in work {
            var value =
                "\(workTitle(item)) · \(item.kind.displayName)"

            if
                item.kind == .task,
                let status =
                    item.status
            {
                value +=
                    " · \(status.displayName)"
            }

            builder.iconRow(
                symbolName:
                    workSymbol(
                        item
                    ),
                text:
                    value
            )
        }
    }


    private static func appendDateField(
        _ label:
            String,
        date:
            Date?,
        timeZoneID:
            String?,
        builder:
            TestudoPDFTextBuilder,
        indent:
            CGFloat
    )
    {
        guard
            let date
        else {
            return
        }

        builder.field(
            label,
            displayDate(
                date,
                timeZoneID:
                    timeZoneID
            ),
            indent:
                indent
        )
    }


    private static func appendSimpleDateField(
        _ label:
            String,
        date:
            Date?,
        builder:
            TestudoPDFTextBuilder
    )
    {
        guard
            let date
        else {
            return
        }

        builder.field(
            label,
            date.formatted(
                date:
                    .abbreviated,
                time:
                    .omitted
            )
        )
    }


    private static func appendOptionalField(
        _ label:
            String,
        _ value:
            String?,
        builder:
            TestudoPDFTextBuilder
    )
    {
        guard
            let value =
                cleaned(
                    value
                )
        else {
            return
        }

        builder.field(
            label,
            value
        )
    }


    private static func themeIDs(
        for item:
            WorkItem
    ) -> [UUID]
    {
        if
            let explicit =
                item.themeIDs
        {
            return
                explicit
        }

        if
            let legacy =
                item.themeID
        {
            return
                [
                    legacy
                ]
        }

        return []
    }


    private static func workSymbol(
        _ item:
            WorkItem
    ) -> String
    {
        switch item.kind {
        case .task:
            switch item.status {
            case .completed:
                return
                    "checkmark.circle"

            case .discontinued:
                return
                    "xmark.circle"

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

        case .note:
            if item.reminderAt != nil {
                return
                    "bell"
            }

            return
                "note.text"

        case .activity:
            return
                "waveform.path.ecg"
        }
    }


    private static func defaultEntitySymbol(
        _ entity:
            Entity
    ) -> String
    {
        switch entity.kind {
        case .organization:
            return
                "building.2"

        case .group:
            return
                "person.3"

        case .person:
            return
                "person.crop.circle"
        }
    }


    private static func personInitial(
        person:
            Entity,
        profile:
            PersonProfile?
    ) -> String
    {
        if
            let first =
                profile?
                    .firstName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .first
        {
            return
                String(
                    first
                )
                .uppercased()
        }

        return
            String(
                person.name
                    .first
                ?? "?"
            )
            .uppercased()
    }


    private static func workTitle(
        _ item:
            WorkItem
    ) -> String
    {
        let title =
            item.title?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        if !title.isEmpty {
            return
                title
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
            item.kind
                .displayName
    }


    private static func displayDate(
        _ date:
            Date,
        timeZoneID:
            String?
    ) -> String
    {
        TestudoTime
            .displayDateTime(
                date,
                sourceTimeZoneID:
                    timeZoneID
            )
    }


    private static func cleaned(
        _ value:
            String?
    ) -> String?
    {
        guard
            let value
        else {
            return nil
        }

        let result =
            value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return
            result.isEmpty
            ? nil
            : result
    }


    private static func pdfFilename(
        target:
            TestudoPDFExportTarget,
        store:
            TestudoStore
    ) -> String
    {
        var name =
            "Testudo Export"

        switch target {
        case
            .work(
                let id
            ):
            if
                let item =
                    store.workItem(
                        id:
                            id
                    )
            {
                name =
                    workTitle(
                        item
                    )
            }

        case
            .theme(
                let id
            ):
            if
                let theme =
                    store.theme(
                        id:
                            id
                    )
            {
                name =
                    theme.name
            }

        case
            .organization(
                let id
            ),
            .group(
                let id
            ),
            .person(
                let id
            ):
            if
                let entity =
                    store.entity(
                        id:
                            id
                    )
            {
                name =
                    entity.name
            }

        case
            .calendarEvent(
                let id
            ):
            if
                let event =
                    store.calendarEvent(
                        id:
                            id
                    )
            {
                name =
                    event.title
            }

        case
            .day(
                let date
            ):
            name =
                date.formatted(
                    .dateTime
                        .year()
                        .month()
                        .day()
                )
        }

        let unsafe =
            CharacterSet(
                charactersIn:
                    "/:"
            )

        let safe =
            name
                .components(
                    separatedBy:
                        unsafe
                )
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator:
                        "-"
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let base =
            safe.isEmpty
            ? "Testudo Export"
            : safe

        return
            base.lowercased()
                .hasSuffix(
                    ".pdf"
                )
            ? base
            : "\(base).pdf"
    }
}


private final class TestudoPDFTextBuilder
{
    let output =
        NSMutableAttributedString(
            string:
                ""
        )


    func header(
        title:
            String,
        symbolName:
            String,
        metadata:
            [String],
        indent:
            CGFloat = 0,
        nested:
            Bool = false
    )
    {
        let symbolSize:
            CGFloat =
            nested
            ? 18
            : 22

        let titleSize:
            CGFloat =
            nested
            ? 18
            : 24

        let leadingWidth =
            symbolSize
            + 14

        let paragraph =
            NSMutableParagraphStyle()

        paragraph.firstLineHeadIndent =
            indent

        paragraph.headIndent =
            indent
            + leadingWidth

        paragraph.paragraphSpacingBefore =
            nested
            ? 14
            : 0

        paragraph.paragraphSpacing =
            3

        let line =
            NSMutableAttributedString()

        if
            let symbol =
                symbolAttachment(
                    name:
                        symbolName,
                    size:
                        symbolSize
                )
        {
            line.append(
                symbol
            )

            line.append(
                NSAttributedString(
                    string:
                        "  "
                )
            )
        }

        line.append(
            NSAttributedString(
                string:
                    title,
                attributes:
                    [
                        .font:
                            NSFont.systemFont(
                                ofSize:
                                    titleSize,
                                weight:
                                    .semibold
                            ),
                        .foregroundColor:
                            NSColor.labelColor,
                        .paragraphStyle:
                            paragraph,
                    ]
            )
        )

        line.append(
            NSAttributedString(
                string:
                    "\n",
                attributes:
                    [
                        .paragraphStyle:
                            paragraph,
                    ]
            )
        )

        output.append(
            line
        )

        if !metadata.isEmpty {
            let metadataStyle =
                NSMutableParagraphStyle()

            metadataStyle.firstLineHeadIndent =
                indent
                + leadingWidth

            metadataStyle.headIndent =
                indent
                + leadingWidth

            metadataStyle.paragraphSpacing =
                14

            let metadataText =
                metadata
                    .joined(
                        separator:
                            "  ·  "
                    )

            output.append(
                NSAttributedString(
                    string:
                        "\(metadataText)\n",
                    attributes:
                        [
                            .font:
                                NSFont.systemFont(
                                    ofSize:
                                        11.5
                                ),
                            .foregroundColor:
                                NSColor.secondaryLabelColor,
                            .paragraphStyle:
                                metadataStyle,
                        ]
                )
            )
        }
    }


    func personHeader(
        title:
            String,
        avatarData:
            Data?,
        initial:
            String,
        metadata:
            [String]
    )
    {
        let avatarSize:
            CGFloat = 44

        let leadingWidth =
            avatarSize
            + 16

        let paragraph =
            NSMutableParagraphStyle()

        paragraph.firstLineHeadIndent =
            0

        paragraph.headIndent =
            leadingWidth

        paragraph.paragraphSpacing =
            3

        let line =
            NSMutableAttributedString()

        line.append(
            personAvatarAttachment(
                data:
                    avatarData,
                initial:
                    initial,
                size:
                    avatarSize
            )
        )

        line.append(
            NSAttributedString(
                string:
                    "  "
            )
        )

        line.append(
            NSAttributedString(
                string:
                    title,
                attributes:
                    [
                        .font:
                            NSFont.systemFont(
                                ofSize:
                                    24,
                                weight:
                                    .semibold
                            ),
                        .foregroundColor:
                            NSColor.labelColor,
                        .paragraphStyle:
                            paragraph,
                    ]
            )
        )

        line.append(
            NSAttributedString(
                string:
                    "\n",
                attributes:
                    [
                        .paragraphStyle:
                            paragraph,
                    ]
            )
        )

        output.append(
            line
        )

        if !metadata.isEmpty {
            let metadataStyle =
                NSMutableParagraphStyle()

            metadataStyle.firstLineHeadIndent =
                leadingWidth

            metadataStyle.headIndent =
                leadingWidth

            metadataStyle.paragraphSpacing =
                4

            for item in metadata {
                output.append(
                    NSAttributedString(
                        string:
                            "\(item)\n",
                        attributes:
                            [
                                .font:
                                    NSFont.systemFont(
                                        ofSize:
                                            11.5
                                    ),
                                .foregroundColor:
                                    NSColor.secondaryLabelColor,
                                .paragraphStyle:
                                    metadataStyle,
                            ]
                    )
                )
            }
        }

        output.append(
            NSAttributedString(
                string:
                    "\n"
            )
        )
    }


    func iconRow(
        symbolName:
            String,
        text:
            String,
        indent:
            CGFloat = 0
    )
    {
        let iconSize:
            CGFloat = 11

        let leadingWidth =
            iconSize
            + 9

        let paragraph =
            NSMutableParagraphStyle()

        paragraph.firstLineHeadIndent =
            indent

        paragraph.headIndent =
            indent
            + leadingWidth

        paragraph.paragraphSpacing =
            4

        let row =
            NSMutableAttributedString()

        if
            let symbol =
                symbolAttachment(
                    name:
                        symbolName,
                    size:
                        iconSize
                )
        {
            row.append(
                symbol
            )

            row.append(
                NSAttributedString(
                    string:
                        "  "
                )
            )
        }

        row.append(
            NSAttributedString(
                string:
                    text,
                attributes:
                    [
                        .font:
                            NSFont.systemFont(
                                ofSize:
                                    10.8
                            ),
                        .foregroundColor:
                            NSColor.labelColor,
                        .paragraphStyle:
                            paragraph,
                    ]
            )
        )

        row.append(
            NSAttributedString(
                string:
                    "\n",
                attributes:
                    [
                        .paragraphStyle:
                            paragraph,
                    ]
            )
        )

        output.append(
            row
        )
    }


    private func symbolAttachment(
        name:
            String,
        size:
            CGFloat
    ) -> NSAttributedString?
    {
        guard
            let base =
                NSImage(
                    systemSymbolName:
                        name,
                    accessibilityDescription:
                        nil
                )
        else {
            return nil
        }

        let configuration =
            NSImage.SymbolConfiguration(
                pointSize:
                    size,
                weight:
                    .regular
            )

        let image =
            base.withSymbolConfiguration(
                configuration
            )
            ?? base

        image.isTemplate =
            true

        let attachment =
            NSTextAttachment()

        attachment.image =
            image

        attachment.bounds =
            NSRect(
                x:
                    0,
                y:
                    -3,
                width:
                    size,
                height:
                    size
            )

        return
            NSAttributedString(
                attachment:
                    attachment
            )
    }


    private func personAvatarAttachment(
        data:
            Data?,
        initial:
            String,
        size:
            CGFloat
    ) -> NSAttributedString
    {
        let image:
            NSImage

        if
            let data,
            let source =
                NSImage(
                    data:
                        data
                )
        {
            image =
                circularImage(
                    source,
                    size:
                        size
                )

        } else {
            image =
                initialAvatar(
                    initial:
                        initial,
                    size:
                        size
                )
        }

        let attachment =
            NSTextAttachment()

        attachment.image =
            image

        attachment.bounds =
            NSRect(
                x:
                    0,
                y:
                    -(
                        size
                        - 16
                    )
                    / 2,
                width:
                    size,
                height:
                    size
            )

        return
            NSAttributedString(
                attachment:
                    attachment
            )
    }


    private func circularImage(
        _ source:
            NSImage,
        size:
            CGFloat
    ) -> NSImage
    {
        let result =
            NSImage(
                size:
                    NSSize(
                        width:
                            size,
                        height:
                            size
                    )
            )

        result.lockFocus()

        let rect =
            NSRect(
                x:
                    0,
                y:
                    0,
                width:
                    size,
                height:
                    size
            )

        let path =
            NSBezierPath(
                ovalIn:
                    rect
            )

        path.addClip()

        source.draw(
            in:
                rect,
            from:
                .zero,
            operation:
                .sourceOver,
            fraction:
                1
        )

        result.unlockFocus()

        return
            result
    }


    private func initialAvatar(
        initial:
            String,
        size:
            CGFloat
    ) -> NSImage
    {
        let image =
            NSImage(
                size:
                    NSSize(
                        width:
                            size,
                        height:
                            size
                    )
            )

        image.lockFocus()

        let rect =
            NSRect(
                x:
                    0,
                y:
                    0,
                width:
                    size,
                height:
                    size
            )

        NSColor.controlAccentColor
            .withAlphaComponent(
                0.12
            )
            .setFill()

        NSBezierPath(
            ovalIn:
                rect
        )
        .fill()

        let attributes:
            [NSAttributedString.Key: Any] =
            [
                .font:
                    NSFont.systemFont(
                        ofSize:
                            size
                            * 0.42,
                        weight:
                            .semibold
                    ),
                .foregroundColor:
                    NSColor.controlAccentColor,
            ]

        let value =
            NSAttributedString(
                string:
                    initial,
                attributes:
                    attributes
            )

        let textSize =
            value.size()

        value.draw(
            at:
                NSPoint(
                    x:
                        (
                            size
                            - textSize.width
                        )
                        / 2,
                    y:
                        (
                            size
                            - textSize.height
                        )
                        / 2
                        - 1
                )
        )

        image.unlockFocus()

        return
            image
    }


    func title(
        _ text:
            String,
        indent:
            CGFloat = 0,
        nested:
            Bool = false
    )
    {
        append(
            text,
            font:
                NSFont.systemFont(
                    ofSize:
                        nested
                        ? 18
                        : 24,
                    weight:
                        .semibold
                ),
            color:
                .black,
            indent:
                indent,
            before:
                nested
                ? 14
                : 0,
            after:
                4
        )
    }


    func subtitle(
        _ text:
            String,
        indent:
            CGFloat = 0
    )
    {
        append(
            text,
            font:
                NSFont.systemFont(
                    ofSize:
                        11.5
                ),
            color:
                NSColor(
                    calibratedWhite:
                        0.38,
                    alpha:
                        1
                ),
            indent:
                indent,
            after:
                14
        )
    }


    func section(
        _ text:
            String,
        indent:
            CGFloat = 0
    )
    {
        append(
            text,
            font:
                NSFont.systemFont(
                    ofSize:
                        13.5,
                    weight:
                        .semibold
                ),
            color:
                .black,
            indent:
                indent,
            before:
                12,
            after:
                6
        )
    }


    func subsection(
        _ text:
            String,
        indent:
            CGFloat = 0
    )
    {
        append(
            text,
            font:
                NSFont.systemFont(
                    ofSize:
                        11,
                    weight:
                        .semibold
                ),
            color:
                NSColor(
                    calibratedWhite:
                        0.32,
                    alpha:
                        1
                ),
            indent:
                indent,
            before:
                6,
            after:
                4
        )
    }


    func field(
        _ label:
            String,
        _ value:
            String,
        indent:
            CGFloat = 0
    )
    {
        let valueColumn =
            indent
            + 118

        let paragraph =
            NSMutableParagraphStyle()

        paragraph.firstLineHeadIndent =
            indent

        paragraph.headIndent =
            valueColumn

        paragraph.paragraphSpacing =
            5

        paragraph.tabStops =
            [
                NSTextTab(
                    textAlignment:
                        .left,
                    location:
                        valueColumn
                )
            ]

        let line =
            NSMutableAttributedString(
                string:
                    label,
                attributes:
                    [
                        .font:
                            NSFont.systemFont(
                                ofSize:
                                    10.8
                            ),
                        .foregroundColor:
                            NSColor.secondaryLabelColor,
                        .paragraphStyle:
                            paragraph,
                    ]
            )

        line.append(
            NSAttributedString(
                string:
                    "\t"
            )
        )

        line.append(
            NSAttributedString(
                string:
                    value,
                attributes:
                    [
                        .font:
                            NSFont.systemFont(
                                ofSize:
                                    10.8
                            ),
                        .foregroundColor:
                            NSColor.labelColor,
                        .paragraphStyle:
                            paragraph,
                    ]
            )
        )

        line.append(
            NSAttributedString(
                string:
                    "\n",
                attributes:
                    [
                        .paragraphStyle:
                            paragraph,
                    ]
            )
        )

        output.append(
            line
        )
    }


    func bullet(
        _ text:
            String,
        indent:
            CGFloat = 0
    )
    {
        append(
            "• \(text)",
            font:
                NSFont.systemFont(
                    ofSize:
                        10.8
                ),
            color:
                .black,
            indent:
                indent
                    + 14,
            firstIndent:
                indent,
            after:
                3
        )
    }


    func secondary(
        _ text:
            String,
        indent:
            CGFloat = 0
    )
    {
        append(
            text,
            font:
                NSFont.systemFont(
                    ofSize:
                        10.8
                ),
            color:
                NSColor(
                    calibratedWhite:
                        0.46,
                    alpha:
                        1
                ),
            indent:
                indent,
            after:
                5
        )
    }


    func separator(
        indent:
            CGFloat
    )
    {
        append(
            "────────────────────────────────",
            font:
                NSFont.systemFont(
                    ofSize:
                        8
                ),
            color:
                NSColor(
                    calibratedWhite:
                        0.78,
                    alpha:
                        1
                ),
            indent:
                indent,
            before:
                12,
            after:
                10
        )
    }


    func markdown(
        _ text:
            String,
        indent:
            CGFloat = 0
    )
    {
        let tick =
            String(
                UnicodeScalar(
                    96
                )!
            )

        let fence =
            String(
                repeating:
                    tick,
                count:
                    3
            )

        var inCode =
            false

        for sourceLine in
            text.components(
                separatedBy:
                    .newlines
            )
        {
            let line =
                sourceLine
                    .trimmingCharacters(
                        in:
                            .whitespaces
                    )

            if
                line.hasPrefix(
                    fence
                )
            {
                inCode.toggle()
                continue
            }

            if inCode {
                append(
                    sourceLine,
                    font:
                        NSFont
                            .monospacedSystemFont(
                                ofSize:
                                    9.6,
                                weight:
                                    .regular
                            ),
                    color:
                        .black,
                    indent:
                        indent
                            + 10,
                    after:
                        1,
                    background:
                        NSColor(
                            calibratedWhite:
                                0.95,
                            alpha:
                                1
                        )
                )

                continue
            }

            if line.isEmpty {
                append(
                    " ",
                    font:
                        NSFont.systemFont(
                            ofSize:
                                4
                        ),
                    color:
                        .black,
                    indent:
                        indent,
                    after:
                        1
                )

                continue
            }

            let headingLevel =
                line
                    .unicodeScalars
                    .prefix {
                        $0.value
                            == 35
                    }
                    .count

            if
                headingLevel > 0,
                headingLevel <= 6
            {
                let headingText =
                    String(
                        line.dropFirst(
                            headingLevel
                        )
                    )
                    .trimmingCharacters(
                        in:
                            .whitespaces
                    )

                if !headingText.isEmpty {
                    let size:
                        CGFloat

                    if headingLevel == 1 {
                        size =
                            16

                    } else if
                        headingLevel == 2
                    {
                        size =
                            14

                    } else {
                        size =
                            12
                    }

                    append(
                        cleanInline(
                            headingText
                        ),
                        font:
                            NSFont.systemFont(
                                ofSize:
                                    size,
                                weight:
                                    .semibold
                            ),
                        color:
                            .black,
                        indent:
                            indent,
                        before:
                            7,
                        after:
                            4
                    )

                    continue
                }
            }

            if
                line.hasPrefix(
                    "- "
                )
                || line.hasPrefix(
                    "* "
                )
                || line.hasPrefix(
                    "+ "
                )
            {
                bullet(
                    cleanInline(
                        String(
                            line.dropFirst(
                                2
                            )
                        )
                    ),
                    indent:
                        indent
                )

                continue
            }

            if
                line.hasPrefix(
                    "> "
                )
            {
                append(
                    cleanInline(
                        String(
                            line.dropFirst(
                                2
                            )
                        )
                    ),
                    font:
                        NSFont.systemFont(
                            ofSize:
                                10.8
                        ),
                    color:
                        NSColor(
                            calibratedWhite:
                                0.36,
                            alpha:
                                1
                        ),
                    indent:
                        indent
                            + 14,
                    after:
                        4
                )

                continue
            }

            append(
                cleanInline(
                    line
                ),
                font:
                    NSFont.systemFont(
                        ofSize:
                            10.8
                    ),
                color:
                    .black,
                indent:
                    indent,
                after:
                    5
            )
        }
    }


    private func cleanInline(
        _ text:
            String
    ) -> String
    {
        let tick =
            String(
                UnicodeScalar(
                    96
                )!
            )

        return
            text
                .replacingOccurrences(
                    of:
                        "**",
                    with:
                        ""
                )
                .replacingOccurrences(
                    of:
                        "__",
                    with:
                        ""
                )
                .replacingOccurrences(
                    of:
                        tick,
                    with:
                        ""
                )
    }


    private func append(
        _ text:
            String,
        font:
            NSFont,
        color:
            NSColor,
        indent:
            CGFloat,
        firstIndent:
            CGFloat? = nil,
        before:
            CGFloat = 0,
        after:
            CGFloat = 4,
        background:
            NSColor? = nil
    )
    {
        let paragraph =
            paragraphStyle(
                indent:
                    indent,
                firstIndent:
                    firstIndent,
                before:
                    before,
                after:
                    after
            )

        var attributes:
            [NSAttributedString.Key: Any] =
            [
                .font:
                    font,
                .foregroundColor:
                    color,
                .paragraphStyle:
                    paragraph,
            ]

        if let background {
            attributes[
                .backgroundColor
            ] =
                background
        }

        output.append(
            NSAttributedString(
                string:
                    "\(text)\n",
                attributes:
                    attributes
            )
        )
    }


    private func paragraphStyle(
        indent:
            CGFloat,
        firstIndent:
            CGFloat? = nil,
        before:
            CGFloat,
        after:
            CGFloat
    ) -> NSMutableParagraphStyle
    {
        let style =
            NSMutableParagraphStyle()

        style.headIndent =
            indent

        style.firstLineHeadIndent =
            firstIndent
                ?? indent

        style.paragraphSpacingBefore =
            before

        style.paragraphSpacing =
            after

        style.lineSpacing =
            1.5

        return
            style
    }
}
