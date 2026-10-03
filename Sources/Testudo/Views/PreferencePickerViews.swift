import SwiftUI
import Foundation


// ============================================================
// MARK: - Language catalogue
// ============================================================

private struct TestudoLanguageChoice:
    Identifiable,
    Hashable
{
    let value:
        String

    let code:
        String?

    var id:
        String
    {
        value.lowercased()
    }
}


private enum TestudoLanguageCatalog {

    static let choices:
        [TestudoLanguageChoice] =
    {
        let displayLocale =
            Locale(
                identifier:
                    "en"
            )

        var seen:
            Set<String> = []

        var result:
            [TestudoLanguageChoice] = []


        for code in
            Locale.isoLanguageCodes
        {
            guard
                let rawName =
                    displayLocale
                        .localizedString(
                            forLanguageCode:
                                code
                        )
            else {
                continue
            }

            let name =
                rawName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard !name.isEmpty else {
                continue
            }

            let key =
                name.lowercased()

            guard
                seen.insert(
                    key
                )
                .inserted
            else {
                continue
            }

            result.append(
                TestudoLanguageChoice(
                    value:
                        name,
                    code:
                        code
                )
            )
        }


        return result.sorted {
            $0.value
                .localizedCaseInsensitiveCompare(
                    $1.value
                )
            == .orderedAscending
        }
    }()
}


// ============================================================
// MARK: - Searchable preferred-language picker
// ============================================================

struct PreferredLanguagePicker:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Binding
    var selection:
        String

    @State
    private var showingPicker =
        false

    @State
    private var searchText =
        ""


    var body:
        some View
    {
        LabeledContent(
            "Preferred language"
        ) {
            Button {
                searchText =
                    ""

                showingPicker =
                    true

            } label: {
                HStack(
                    spacing:
                        8
                ) {
                    Text(
                        selection
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        ? "Not set"
                        : selection
                    )
                    .lineLimit(1)

                    Spacer(
                        minLength:
                            8
                    )

                    Image(
                        systemName:
                            "chevron.up.chevron.down"
                    )
                    .font(
                        .system(
                            size:
                                9,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .frame(
                    minWidth:
                        280,
                    alignment:
                        .leading
                )
            }
            .buttonStyle(
                .bordered
            )
            .popover(
                isPresented:
                    $showingPicker,
                arrowEdge:
                    .bottom
            ) {
                pickerContent
            }
        }
    }


    private var frequentLanguages:
        [String]
    {
        store
            .mostUsedLanguages(
                limit:
                    5
            )
    }


    private var frequentKeys:
        Set<String>
    {
        Set(
            frequentLanguages.map {
                $0.lowercased()
            }
        )
    }


    private var remainingChoices:
        [TestudoLanguageChoice]
    {
        TestudoLanguageCatalog
            .choices
            .filter {
                !frequentKeys
                    .contains(
                        $0.value
                            .lowercased()
                    )
            }
    }


    private var searchableChoices:
        [TestudoLanguageChoice]
    {
        var result:
            [TestudoLanguageChoice] = []

        var seen:
            Set<String> = []


        let supplemental =
            (
                frequentLanguages
                + [
                    selection
                ]
            )
            .map {
                $0.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }


        for value in
            supplemental
        {
            let key =
                value.lowercased()

            if
                seen.insert(
                    key
                )
                .inserted
            {
                let catalogChoice =
                    TestudoLanguageCatalog
                        .choices
                        .first {
                            $0.value
                                .caseInsensitiveCompare(
                                    value
                                )
                            == .orderedSame
                        }

                result.append(
                    TestudoLanguageChoice(
                        value:
                            catalogChoice?
                                .value
                            ?? value,
                        code:
                            catalogChoice?
                                .code
                    )
                )
            }
        }


        for choice in
            TestudoLanguageCatalog
                .choices
        {
            let key =
                choice.value
                    .lowercased()

            if
                seen.insert(
                    key
                )
                .inserted
            {
                result.append(
                    choice
                )
            }
        }


        return result
    }


    private var searchResults:
        [TestudoLanguageChoice]
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
            return []
        }


        return searchableChoices
            .filter {
                choice in

                choice.value
                    .lowercased()
                    .contains(
                        query
                    )
                ||
                (
                    choice.code?
                        .lowercased()
                        .contains(
                            query
                        )
                    ?? false
                )
            }
    }


    private var pickerContent:
        some View
    {
        VStack(
            spacing:
                0
        ) {
            searchField(
                placeholder:
                    "Search languages"
            )

            Divider()

            ScrollView {
                LazyVStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {
                    if
                        searchText
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                    {
                        if
                            !frequentLanguages
                                .isEmpty
                        {
                            sectionHeader(
                                "Frequently used"
                            )

                            ForEach(
                                frequentLanguages,
                                id:
                                    \.self
                            ) {
                                language in

                                languageRow(
                                    TestudoLanguageChoice(
                                        value:
                                            language,
                                        code:
                                            TestudoLanguageCatalog
                                                .choices
                                                .first {
                                                    $0.value
                                                        .caseInsensitiveCompare(
                                                            language
                                                        )
                                                    == .orderedSame
                                                }?
                                                .code
                                    )
                                )
                            }

                            Divider()
                                .padding(
                                    .vertical,
                                    5
                                )
                        }

                        sectionHeader(
                            "All languages"
                        )

                        ForEach(
                            remainingChoices
                        ) {
                            choice in

                            languageRow(
                                choice
                            )
                        }

                    } else if
                        searchResults
                            .isEmpty
                    {
                        Text(
                            "No languages found"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .padding(
                            .vertical,
                            30
                        )

                    } else {
                        sectionHeader(
                            "Search results"
                        )

                        ForEach(
                            searchResults
                        ) {
                            choice in

                            languageRow(
                                choice
                            )
                        }
                    }
                }
                .padding(
                    8
                )
            }

            Divider()

            Button {
                selection =
                    ""

                showingPicker =
                    false

            } label: {
                HStack {
                    Image(
                        systemName:
                            selection.isEmpty
                        ? "checkmark"
                        : "circle"
                    )
                    .frame(
                        width:
                            18
                    )

                    Text(
                        "Not set"
                    )

                    Spacer()
                }
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
            .padding(
                12
            )
        }
        .frame(
            width:
                420,
            height:
                460
        )
        .background(
            TestudoStyle
                .contentBackground
        )
    }


    private func languageRow(
        _ choice:
            TestudoLanguageChoice
    ) -> some View
    {
        Button {
            selection =
                choice.value

            showingPicker =
                false

        } label: {
            HStack(
                spacing:
                    10
            ) {
                Image(
                    systemName:
                        choice.value
                            .caseInsensitiveCompare(
                                selection
                            )
                        == .orderedSame
                    ? "checkmark.circle.fill"
                    : "circle"
                )
                .foregroundStyle(
                    choice.value
                        .caseInsensitiveCompare(
                            selection
                        )
                    == .orderedSame
                    ? Color.accentColor
                    : Color.secondary
                )

                Text(
                    choice.value
                )

                Spacer()

                if
                    let code =
                        choice.code
                {
                    Text(
                        code.uppercased()
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .padding(
                .horizontal,
                8
            )
            .padding(
                .vertical,
                6
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .plain
        )
    }


    private func sectionHeader(
        _ title:
            String
    ) -> some View
    {
        Text(
            title
        )
        .font(
            .caption
        )
        .fontWeight(
            .semibold
        )
        .foregroundStyle(
            .secondary
        )
        .padding(
            .horizontal,
            8
        )
        .padding(
            .top,
            5
        )
        .padding(
            .bottom,
            3
        )
    }


    private func searchField(
        placeholder:
            String
    ) -> some View
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
                placeholder,
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
            12
        )
        .frame(
            height:
                40
        )
    }
}
