import SwiftUI


struct DetailSelectionRow<PopoverContent: View>:
    View
{
    let label:
        String

    let valueText:
        String

    let valueIsEmpty:
        Bool

    let navigationTitles:
        [String]

    let navigationDestinations:
        [TestudoDetailDestination]

    let buttonSystemImage:
        String

    let helpText:
        String

    @Binding
    private var isPresented:
        Bool

    let onEdit:
        () -> Void

    private let popoverContent:
        () -> PopoverContent


    init(
        label: String,
        valueText: String,
        valueIsEmpty: Bool = false,
        navigationTitles: [String] = [],
        navigationDestinations: [TestudoDetailDestination] = [],
        buttonSystemImage: String = "pencil",
        helpText: String? = nil,
        isPresented: Binding<Bool>,
        onEdit: @escaping () -> Void,
        @ViewBuilder popoverContent:
            @escaping () -> PopoverContent
    ) {
        self.label =
            label

        self.valueText =
            valueText

        self.valueIsEmpty =
            valueIsEmpty

        self.navigationTitles =
            navigationTitles

        self.navigationDestinations =
            navigationDestinations

        self.buttonSystemImage =
            buttonSystemImage

        self.helpText =
            helpText
            ?? "Edit \(label)"

        self._isPresented =
            isPresented

        self.onEdit =
            onEdit

        self.popoverContent =
            popoverContent
    }


    var body: some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing:
                14
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

            if
                !valueIsEmpty,
                !navigationTitles.isEmpty,
                navigationTitles.count
                    == navigationDestinations.count
            {
                TestudoDestinationLinks(
                    titles:
                        navigationTitles,
                    destinations:
                        navigationDestinations,
                    color:
                        .primary
                )
                .lineLimit(
                    2
                )

            } else {
                Text(
                    valueText
                )
                .foregroundStyle(
                    valueIsEmpty
                    ? Color.secondary
                        .opacity(
                            0.65
                        )
                    : Color.primary
                )
                .lineLimit(
                    2
                )
                .textSelection(
                    .enabled
                )
            }

            Spacer(
                minLength: 8
            )

            Button {
                onEdit()

            } label: {
                Image(
                    systemName:
                        buttonSystemImage
                )
                .font(
                    .system(
                        size: 13,
                        weight:
                            .medium
                    )
                )
            }
            .buttonStyle(.plain)
            .help(helpText)
            .popover(
                isPresented:
                    $isPresented,
                arrowEdge:
                    .trailing
            ) {
                popoverContent()
            }
        }
        .font(.callout)
    }
}
