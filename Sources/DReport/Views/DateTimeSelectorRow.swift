import SwiftUI
import Foundation


struct DateTimeSelectorRow:
    View
{
    let label:
        String

    let value:
        Date?

    let valueText:
        String

    let timeZoneID:
        String?

    let allowsEmpty:
        Bool

    let selectorTitle:
        String

    let selectorMessage:
        String

    var includesTime:
        Bool = true

    var showsTimeZone:
        Bool = true

    let onSave:
        (Date?, String?) -> String?


    @State
    private var showingSelector =
        false

    @State
    private var draftEnabled =
        true

    @State
    private var draftDate =
        Date()

    @State
    private var draftTimeZoneID =
        DReportTime
            .deviceTimeZoneID

    @State
    private var errorMessage:
        String?


    var body: some View {
        DetailSelectionRow(
            label:
                label,
            valueText:
                valueText,
            valueIsEmpty:
                value == nil,
            buttonSystemImage:
                "pencil",
            helpText:
                "Edit \(label.lowercased())",
            isPresented:
                $showingSelector,
            onEdit: {
                beginEditing()
            }
        ) {
            selector
        }
    }


    private var selector:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                0
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(
                    selectorTitle
                )
                .font(.headline)

                Text(
                    selectorMessage
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
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

            Divider()

            ScrollView {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        16
                ) {
                    if allowsEmpty {
                        HStack {
                            VStack(
                                alignment:
                                    .leading,
                                spacing: 2
                            ) {
                                Text(
                                    "Use \(label.lowercased())"
                                )
                                .fontWeight(
                                    .medium
                                )

                                Text(
                                    draftEnabled
                                    ? "A date and time will be stored."
                                    : "No date will be set."
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                            }

                            Spacer()

                            Toggle(
                                "",
                                isOn:
                                    $draftEnabled
                            )
                            .labelsHidden()
                            .toggleStyle(
                                .switch
                            )
                        }
                        .padding(12)
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
                    }

                    if draftEnabled {
                        LargeDateTimeEditor(
                            date:
                                $draftDate,
                            timeZoneID:
                                $draftTimeZoneID,
                            includesTime:
                                includesTime,
                            showsTimeZone:
                                showsTimeZone
                                && includesTime
                        )
                    }
                }
                .padding(
                    .horizontal,
                    14
                )
                .padding(
                    .vertical,
                    12
                )
            }
            .frame(
                height:
                    draftEnabled
                    ? (
                        includesTime
                        ? 665
                        : 470
                    )
                    : 100
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

            HStack {
                if
                    allowsEmpty,
                    draftEnabled
                {
                    Button(
                        "Clear"
                    ) {
                        draftEnabled =
                            false
                    }
                    .buttonStyle(
                        .plain
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                Button(
                    "Cancel"
                ) {
                    showingSelector =
                        false
                }
                .keyboardShortcut(
                    .cancelAction
                )

                Button(
                    "Save"
                ) {
                    save()
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
        .frame(
            width: 780
        )
        .background(
            DReportStyle
                .contentBackground
        )
    }


    private func beginEditing() {
        errorMessage =
            nil

        draftEnabled =
            value != nil
            || !allowsEmpty

        draftDate =
            value
            ?? Calendar
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

        draftTimeZoneID =
            DReportTime
                .validTimeZoneIdentifier(
                    timeZoneID
                )
            ?? DReportTime
                .deviceTimeZoneID

        showingSelector =
            true
    }


    private func save() {
        let error:
            String?

        if
            allowsEmpty,
            !draftEnabled
        {
            error =
                onSave(
                    nil,
                    nil
                )
        } else {
            error =
                onSave(
                    draftDate,
                    includesTime
                    ? draftTimeZoneID
                    : nil
                )
        }

        if let error {
            errorMessage =
                error
        } else {
            showingSelector =
                false
        }
    }
}
