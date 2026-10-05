import AppKit
import Foundation
import SwiftUI


// ============================================================
// MARK: - Testudo Markdown
//
// Work descriptions remain stored as raw Markdown String data.
// This renderer is presentation-only, so no data migration is
// required and existing .testudoenv files remain compatible.
//
// The view is intentionally reusable: Person / Theme /
// Organization / Group notes can adopt the same renderer later.
// ============================================================

struct TestudoMarkdownView:
    View
{
    let markdown:
        String


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            ForEach(
                TestudoMarkdownParser
                    .parse(
                        markdown
                    )
            ) {
                block in

                blockView(
                    block
                )
            }
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
    }


    @ViewBuilder
    private func blockView(
        _ block:
            TestudoMarkdownBlock
    ) -> some View {
        switch block.kind {

        case
            .paragraph(
                let text
            ):

            inlineText(
                text
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )


        case
            .heading(
                let level,
                let text
            ):

            inlineText(
                text
            )
            .font(
                headingFont(
                    level
                )
            )
            .fontWeight(
                .semibold
            )
            .padding(
                .top,
                level <= 2
                ? 5
                : 2
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )


        case
            .code(
                let language,
                let code
            ):

            codeBlock(
                language:
                    language,
                code:
                    code
            )


        case
            .quote(
                let text
            ):

            HStack(
                alignment:
                    .top,
                spacing:
                    10
            ) {
                Rectangle()
                    .fill(
                        Color.primary
                            .opacity(
                                0.18
                            )
                    )
                    .frame(
                        width:
                            3
                    )

                inlineText(
                    text
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )
            }


        case
            .list(
                let items
            ):

            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                ForEach(
                    items
                ) {
                    item in

                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing:
                            7
                    ) {
                        Text(
                            item.marker
                        )
                        .frame(
                            width:
                                25,
                            alignment:
                                .trailing
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        inlineText(
                            item.text
                        )
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                    }
                    .padding(
                        .leading,
                        CGFloat(
                            item.level
                        )
                        * 18
                    )
                }
            }


        case
            .table(
                let headers,
                let rows
            ):

            markdownTable(
                headers:
                    headers,
                rows:
                    rows
            )


        case .rule:

            Divider()
                .opacity(
                    0.65
                )
                .padding(
                    .vertical,
                    3
                )
        }
    }


    private func inlineText(
        _ source:
            String
    ) -> Text {
        do {
            let attributed =
                try AttributedString(
                    markdown:
                        source,
                    options:
                        AttributedString
                            .MarkdownParsingOptions(
                                interpretedSyntax:
                                    .inlineOnlyPreservingWhitespace
                            )
                )

            return Text(
                attributed
            )

        } catch {
            return Text(
                source
            )
        }
    }


    private func headingFont(
        _ level:
            Int
    ) -> Font {
        switch level {
        case 1:
            return .title2

        case 2:
            return .title3

        case 3:
            return .headline

        case 4:
            return .subheadline

        default:
            return .body
        }
    }


    private func markdownTable(
        headers:
            [String],
        rows:
            [[String]]
    ) -> some View {
        ScrollView(
            .horizontal,
            showsIndicators:
                true
        ) {
            Grid(
                horizontalSpacing:
                    0,
                verticalSpacing:
                    0
            ) {
                GridRow {
                    ForEach(
                        Array(
                            headers.enumerated()
                        ),
                        id:
                            \.offset
                    ) {
                        _,
                        value in

                        inlineText(
                            value
                        )
                        .fontWeight(
                            .semibold
                        )
                        .frame(
                            minWidth:
                                110,
                            maxWidth:
                                240,
                            alignment:
                                .leading
                        )
                        .padding(
                            .horizontal,
                            11
                        )
                        .padding(
                            .vertical,
                            8
                        )
                        .background(
                            Color.primary
                                .opacity(
                                    0.045
                                )
                        )
                    }
                }

                ForEach(
                    Array(
                        rows.enumerated()
                    ),
                    id:
                        \.offset
                ) {
                    rowIndex,
                    row in

                    GridRow {
                        ForEach(
                            Array(
                                row.enumerated()
                            ),
                            id:
                                \.offset
                        ) {
                            _,
                            value in

                            inlineText(
                                value
                            )
                            .frame(
                                minWidth:
                                    110,
                                maxWidth:
                                    240,
                                alignment:
                                    .leading
                            )
                            .padding(
                                .horizontal,
                                11
                            )
                            .padding(
                                .vertical,
                                8
                            )
                            .background(
                                rowIndex
                                    .isMultiple(
                                        of:
                                            2
                                    )
                                ? Color.clear
                                : Color.primary
                                    .opacity(
                                        0.018
                                    )
                            )
                        }
                    }
                }
            }
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
                            0.11
                        ),
                    lineWidth:
                        1
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        8,
                    style:
                        .continuous
                )
            )
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
    }


    private func codeBlock(
        language:
            String,
        code:
            String
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                0
        ) {
            HStack(
                spacing:
                    10
            ) {
                Text(
                    language.isEmpty
                    ? "Code"
                    : language
                )
                .font(
                    .caption
                )
                .fontWeight(
                    .medium
                )
                .foregroundStyle(
                    .secondary
                )

                Spacer()

                Button {
                    copyCode(
                        code
                    )
                } label: {
                    Label(
                        "Copy",
                        systemImage:
                            "doc.on.doc"
                    )
                    .font(
                        .caption
                    )
                }
                .buttonStyle(
                    .plain
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .padding(
                .horizontal,
                12
            )
            .padding(
                .vertical,
                9
            )

            Divider()
                .opacity(
                    0.6
                )

            ScrollView(
                .horizontal,
                showsIndicators:
                    true
            ) {
                Text(
                    code
                )
                .font(
                    .system(
                        size:
                            13,
                        design:
                            .monospaced
                    )
                )
                .textSelection(
                    .enabled
                )
                .fixedSize(
                    horizontal:
                        true,
                    vertical:
                        false
                )
                .padding(
                    12
                )
            }
        }
        .background(
            Color.primary
                .opacity(
                    0.035
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
                        0.09
                    ),
                lineWidth:
                    1
            )
        }
    }


    private func copyCode(
        _ code:
            String
    ) {
        NSPasteboard
            .general
            .clearContents()

        NSPasteboard
            .general
            .setString(
                code,
                forType:
                    .string
            )
    }
}


// ============================================================
// MARK: - Parsed block
// ============================================================

private struct TestudoMarkdownBlock:
    Identifiable
{
    enum Kind
    {
        case paragraph(
            String
        )

        case heading(
            level:
                Int,
            text:
                String
        )

        case code(
            language:
                String,
            code:
                String
        )

        case quote(
            String
        )

        case list(
            [
                TestudoMarkdownListItem
            ]
        )

        case table(
            headers:
                [String],
            rows:
                [[String]]
        )

        case rule
    }


    let id:
        Int

    let kind:
        Kind
}


private struct TestudoMarkdownListItem:
    Identifiable
{
    let id:
        Int

    let level:
        Int

    let marker:
        String

    let text:
        String
}


// ============================================================
// MARK: - Parser
// ============================================================

private enum TestudoMarkdownParser
{
    static func parse(
        _ source:
            String
    ) -> [
        TestudoMarkdownBlock
    ] {
        let lines =
            source.components(
                separatedBy:
                    .newlines
            )

        var result:
            [
                TestudoMarkdownBlock
            ] = []

        var index =
            0

        var blockID =
            0


        func append(
            _ kind:
                TestudoMarkdownBlock.Kind
        ) {
            result.append(
                TestudoMarkdownBlock(
                    id:
                        blockID,
                    kind:
                        kind
                )
            )

            blockID +=
                1
        }


        while
            index < lines.count
        {
            let line =
                lines[
                    index
                ]

            let trimmed =
                line.trimmingCharacters(
                    in:
                        .whitespaces
                )


            if trimmed.isEmpty {
                index +=
                    1

                continue
            }


            // ------------------------------------------------
            // Fenced code
            // ------------------------------------------------

            if
                let fence =
                    fenceInfo(
                        trimmed
                    )
            {
                var codeLines:
                    [
                        String
                    ] = []

                index +=
                    1

                while
                    index < lines.count
                {
                    let candidate =
                        lines[
                            index
                        ]

                    let candidateTrimmed =
                        candidate
                            .trimmingCharacters(
                                in:
                                    .whitespaces
                            )

                    if
                        candidateTrimmed
                            .hasPrefix(
                                fence.marker
                            )
                    {
                        index +=
                            1

                        break
                    }

                    codeLines.append(
                        candidate
                    )

                    index +=
                        1
                }

                append(
                    .code(
                        language:
                            fence.language,
                        code:
                            codeLines.joined(
                                separator:
                                    "\n"
                            )
                    )
                )

                continue
            }


            // ------------------------------------------------
            // Heading
            // ------------------------------------------------

            if
                let heading =
                    headingInfo(
                        trimmed
                    )
            {
                append(
                    .heading(
                        level:
                            heading.level,
                        text:
                            heading.text
                    )
                )

                index +=
                    1

                continue
            }


            // ------------------------------------------------
            // Horizontal rule
            // ------------------------------------------------

            if isRule(
                trimmed
            ) {
                append(
                    .rule
                )

                index +=
                    1

                continue
            }


            // ------------------------------------------------
            // GFM-style table
            // ------------------------------------------------

            if
                index + 1 < lines.count,
                let headers =
                    tableRow(
                        line
                    ),
                isTableSeparator(
                    lines[
                        index + 1
                    ],
                    expectedColumns:
                        headers.count
                )
            {
                var rows:
                    [[String]] = []

                index +=
                    2

                while
                    index < lines.count
                {
                    let candidate =
                        lines[
                            index
                        ]

                    if
                        candidate
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                    {
                        break
                    }

                    guard
                        let parsed =
                            tableRow(
                                candidate
                            )
                    else {
                        break
                    }

                    var normalized =
                        Array(
                            parsed.prefix(
                                headers.count
                            )
                        )

                    while
                        normalized.count
                            < headers.count
                    {
                        normalized.append(
                            ""
                        )
                    }

                    rows.append(
                        normalized
                    )

                    index +=
                        1
                }

                append(
                    .table(
                        headers:
                            headers,
                        rows:
                            rows
                    )
                )

                continue
            }


            // ------------------------------------------------
            // Blockquote
            // ------------------------------------------------

            if
                trimmed
                    .hasPrefix(
                        ">"
                    )
            {
                var quoteLines:
                    [
                        String
                    ] = []

                while
                    index < lines.count
                {
                    let candidate =
                        lines[
                            index
                        ]
                        .trimmingCharacters(
                            in:
                                .whitespaces
                        )

                    guard
                        candidate
                            .hasPrefix(
                                ">"
                            )
                    else {
                        break
                    }

                    var text =
                        String(
                            candidate
                                .dropFirst()
                        )

                    if
                        text
                            .hasPrefix(
                                " "
                            )
                    {
                        text.removeFirst()
                    }

                    quoteLines.append(
                        text
                    )

                    index +=
                        1
                }

                append(
                    .quote(
                        quoteLines.joined(
                            separator:
                                "\n"
                        )
                    )
                )

                continue
            }


            // ------------------------------------------------
            // Lists
            // ------------------------------------------------

            if
                listInfo(
                    line
                ) != nil
            {
                var items:
                    [
                        TestudoMarkdownListItem
                    ] = []

                var listID =
                    0

                while
                    index < lines.count,
                    let info =
                        listInfo(
                            lines[
                                index
                            ]
                        )
                {
                    items.append(
                        TestudoMarkdownListItem(
                            id:
                                listID,
                            level:
                                info.level,
                            marker:
                                info.marker,
                            text:
                                info.text
                        )
                    )

                    listID +=
                        1

                    index +=
                        1
                }

                append(
                    .list(
                        items
                    )
                )

                continue
            }


            // ------------------------------------------------
            // Paragraph
            // ------------------------------------------------

            var paragraphLines:
                [
                    String
                ] = [
                    trimmed
                ]

            index +=
                1

            while
                index < lines.count
            {
                let candidate =
                    lines[
                        index
                    ]

                let candidateTrimmed =
                    candidate
                        .trimmingCharacters(
                            in:
                                .whitespaces
                        )

                if candidateTrimmed.isEmpty {
                    break
                }

                if startsBlock(
                    candidate
                ) {
                    break
                }

                paragraphLines.append(
                    candidateTrimmed
                )

                index +=
                    1
            }

            append(
                .paragraph(
                    paragraphLines.joined(
                        separator:
                            " "
                    )
                )
            )
        }


        return result
    }


    private static func startsBlock(
        _ line:
            String
    ) -> Bool {
        let trimmed =
            line.trimmingCharacters(
                in:
                    .whitespaces
            )

        if
            tableRow(
                line
            ) != nil
        {
            return true
        }

        return
            fenceInfo(
                trimmed
            ) != nil
            || headingInfo(
                trimmed
            ) != nil
            || isRule(
                trimmed
            )
            || trimmed
                .hasPrefix(
                    ">"
                )
            || listInfo(
                line
            ) != nil
    }


    private static func fenceInfo(
        _ line:
            String
    ) -> (
        marker:
            String,
        language:
            String
    )? {
        let marker:
            String

        if line.hasPrefix(
            "```"
        ) {
            marker =
                "```"

        } else if line.hasPrefix(
            "~~~"
        ) {
            marker =
                "~~~"

        } else {
            return nil
        }

        let language =
            String(
                line.dropFirst(
                    marker.count
                )
            )
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return (
            marker,
            language
        )
    }


    private static func headingInfo(
        _ line:
            String
    ) -> (
        level:
            Int,
        text:
            String
    )? {
        var level =
            0

        for character in line {
            if character == "#" {
                level +=
                    1
            } else {
                break
            }
        }

        guard
            level >= 1,
            level <= 6
        else {
            return nil
        }

        let start =
            line.index(
                line.startIndex,
                offsetBy:
                    level
            )

        let remainder =
            String(
                line[
                    start...
                ]
            )

        guard
            remainder
                .hasPrefix(
                    " "
                )
        else {
            return nil
        }

        return (
            level,
            remainder
                .trimmingCharacters(
                    in:
                        .whitespaces
                )
        )
    }


    private static func tableRow(
        _ line:
            String
    ) -> [String]? {
        let trimmed =
            line.trimmingCharacters(
                in:
                    .whitespaces
            )

        guard
            trimmed.contains(
                "|"
            )
        else {
            return nil
        }

        var source =
            trimmed

        if source.hasPrefix(
            "|"
        ) {
            source.removeFirst()
        }

        if source.hasSuffix(
            "|"
        ) {
            source.removeLast()
        }

        var cells:
            [String] = []

        var current =
            ""

        var escaped =
            false

        for character in source {
            if escaped {
                current.append(
                    character
                )

                escaped =
                    false

                continue
            }

            if character == "\\" {
                escaped =
                    true

                continue
            }

            if character == "|" {
                cells.append(
                    current
                        .trimmingCharacters(
                            in:
                                .whitespaces
                        )
                )

                current =
                    ""

                continue
            }

            current.append(
                character
            )
        }

        if escaped {
            current.append(
                "\\"
            )
        }

        cells.append(
            current
                .trimmingCharacters(
                    in:
                        .whitespaces
                )
        )

        guard
            cells.count >= 2
        else {
            return nil
        }

        return cells
    }


    private static func isTableSeparator(
        _ line:
            String,
        expectedColumns:
            Int
    ) -> Bool {
        guard
            let cells =
                tableRow(
                    line
                ),
            cells.count
                == expectedColumns
        else {
            return false
        }

        for cell in cells {
            var candidate =
                cell.trimmingCharacters(
                    in:
                        .whitespaces
                )

            if candidate.hasPrefix(
                ":"
            ) {
                candidate.removeFirst()
            }

            if candidate.hasSuffix(
                ":"
            ) {
                candidate.removeLast()
            }

            guard
                candidate.count >= 3,
                candidate.allSatisfy({
                    $0 == "-"
                })
            else {
                return false
            }
        }

        return true
    }


    private static func isRule(
        _ line:
            String
    ) -> Bool {
        line == "---"
        || line == "***"
        || line == "___"
    }


    private static func listInfo(
        _ line:
            String
    ) -> (
        level:
            Int,
        marker:
            String,
        text:
            String
    )? {
        let leading =
            line.prefix {
                $0 == " "
                || $0 == "\t"
            }

        var spaces =
            0

        for character in leading {
            spaces +=
                character == "\t"
                ? 4
                : 1
        }

        let level =
            max(
                0,
                spaces / 2
            )

        let trimmed =
            line.trimmingCharacters(
                in:
                    .whitespaces
            )


        // Checkbox list
        for candidate in [
            ("- [ ] ", "☐"),
            ("* [ ] ", "☐"),
            ("+ [ ] ", "☐"),
            ("- [x] ", "☑"),
            ("- [X] ", "☑"),
            ("* [x] ", "☑"),
            ("* [X] ", "☑"),
            ("+ [x] ", "☑"),
            ("+ [X] ", "☑")
        ] {
            if
                trimmed.hasPrefix(
                    candidate.0
                )
            {
                return (
                    level,
                    candidate.1,
                    String(
                        trimmed.dropFirst(
                            candidate.0.count
                        )
                    )
                )
            }
        }


        // Unordered list
        for prefix in [
            "- ",
            "* ",
            "+ "
        ] {
            if
                trimmed.hasPrefix(
                    prefix
                )
            {
                return (
                    level,
                    "•",
                    String(
                        trimmed.dropFirst(
                            prefix.count
                        )
                    )
                )
            }
        }


        // Ordered list
        var digits =
            ""

        for character in trimmed {
            if character.isNumber {
                digits.append(
                    character
                )
            } else {
                break
            }
        }

        if
            !digits.isEmpty
        {
            let prefix =
                digits
                + ". "

            if
                trimmed.hasPrefix(
                    prefix
                )
            {
                return (
                    level,
                    digits + ".",
                    String(
                        trimmed.dropFirst(
                            prefix.count
                        )
                    )
                )
            }
        }


        return nil
    }
}
