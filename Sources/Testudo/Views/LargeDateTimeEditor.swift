import SwiftUI
import Foundation


struct LargeDateTimeEditor:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @Binding
    var date:
        Date

    @Binding
    var timeZoneID:
        String

    var includesTime:
        Bool = true

    var showsTimeZone:
        Bool = true


    @State
    private var timeZoneSearch =
        ""


    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                16
        ) {
            HStack(
                alignment:
                    .top,
                spacing:
                    24
            ) {
                calendarSection

                if includesTime {
                    timeSection
                }
            }

            if
                includesTime,
                showsTimeZone
            {
                Divider()

                timeZoneSection
            }
        }
        .padding(16)
        .onAppear {
            if
                TestudoTime
                    .validTimeZoneIdentifier(
                        timeZoneID
                    ) == nil
            {
                timeZoneID =
                    TestudoTime
                        .deviceTimeZoneID
            }
        }
    }


    // ========================================================
    // MARK: - Large calendar
    // ========================================================

    private var calendarSection:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            Label(
                "Date",
                systemImage:
                    "calendar"
            )
            .font(
                .system(
                    size: 15,
                    weight:
                        .semibold
                )
            )

            VStack(
                spacing:
                    9
            ) {
                HStack {
                    Button {
                        moveMonth(
                            by:
                                -1
                        )

                    } label: {
                        Image(
                            systemName:
                                "chevron.left"
                        )
                        .frame(
                            width: 28,
                            height: 28
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(
                        monthTitle
                    )
                    .font(
                        .system(
                            size: 18,
                            weight:
                                .semibold
                        )
                    )

                    Spacer()

                    Button {
                        moveMonth(
                            by:
                                1
                        )

                    } label: {
                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .frame(
                            width: 28,
                            height: 28
                        )
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(
                    columns:
                        calendarColumns,
                    spacing:
                        5
                ) {
                    ForEach(
                        Array(
                            weekdaySymbols
                                .enumerated()
                        ),
                        id:
                            \.offset
                    ) { _, symbol in
                        Text(symbol)
                            .font(
                                .system(
                                    size: 12,
                                    weight:
                                        .semibold
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .frame(
                                maxWidth:
                                    .infinity
                            )
                    }

                    ForEach(
                        calendarCells
                    ) { cell in
                        dayCell(
                            cell
                        )
                    }
                }
            }
            .padding(
                12
            )
            .frame(
                width: 370
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
                            0.09
                        ),
                    lineWidth:
                        1
                )
            }
        }
    }


    private struct CalendarCell:
        Identifiable
    {
        let id:
            String

        let date:
            Date

        let day:
            Int

        let belongsToDisplayedMonth:
            Bool
    }


    private var calendarColumns:
        [GridItem]
    {
        Array(
            repeating:
                GridItem(
                    .flexible(
                        minimum:
                            38
                    ),
                    spacing:
                        5
                ),
            count:
                7
        )
    }


    private var weekdaySymbols:
        [String]
    {
        var calendar =
            selectedCalendar

        let symbols =
            calendar
                .veryShortStandaloneWeekdaySymbols

        let first =
            max(
                0,
                calendar.firstWeekday
                    - 1
            )

        return
            Array(
                symbols[first...]
            )
            +
            Array(
                symbols[..<first]
            )
    }


    private var displayedMonthStart:
        Date
    {
        let calendar =
            selectedCalendar

        let components =
            calendar
                .dateComponents(
                    [
                        .year,
                        .month
                    ],
                    from:
                        date
                )

        return
            calendar.date(
                from:
                    components
            )
            ?? date
    }


    private var monthTitle:
        String
    {
        let formatter =
            DateFormatter()

        formatter.locale =
            .autoupdatingCurrent

        formatter.timeZone =
            selectedTimeZone

        formatter.dateFormat =
            "LLLL yyyy"

        return
            formatter.string(
                from:
                    displayedMonthStart
            )
    }


    private var calendarCells:
        [CalendarCell]
    {
        let calendar =
            selectedCalendar

        let monthStart =
            displayedMonthStart

        let weekday =
            calendar.component(
                .weekday,
                from:
                    monthStart
            )

        let leading =
            (
                weekday
                - calendar.firstWeekday
                + 7
            ) % 7

        guard
            let gridStart =
                calendar.date(
                    byAdding:
                        .day,
                    value:
                        -leading,
                    to:
                        monthStart
                )
        else {
            return []
        }

        let displayedMonth =
            calendar.component(
                .month,
                from:
                    monthStart
            )

        return
            (0..<42)
                .compactMap {
                    offset in

                    guard
                        let cellDate =
                            calendar.date(
                                byAdding:
                                    .day,
                                value:
                                    offset,
                                to:
                                    gridStart
                            )
                    else {
                        return nil
                    }

                    return
                        CalendarCell(
                            id:
                                String(
                                    cellDate
                                        .timeIntervalSince1970
                                ),
                            date:
                                cellDate,
                            day:
                                calendar.component(
                                    .day,
                                    from:
                                        cellDate
                                ),
                            belongsToDisplayedMonth:
                                calendar.component(
                                    .month,
                                    from:
                                        cellDate
                                )
                                == displayedMonth
                        )
                }
    }


    @ViewBuilder
    private func dayCell(
        _ cell: CalendarCell
    ) -> some View {
        let isSelected =
            selectedCalendar
                .isDate(
                    cell.date,
                    inSameDayAs:
                        date
                )

        let isToday =
            selectedCalendar
                .isDateInToday(
                    cell.date
                )

        Button {
            selectDay(
                cell.date
            )

        } label: {
            Text(
                "\(cell.day)"
            )
            .font(
                .system(
                    size: 13,
                    weight:
                        isSelected
                        ? .semibold
                        : .regular
                )
            )
            .foregroundStyle(
                isSelected
                ? Color.white
                : (
                    cell
                        .belongsToDisplayedMonth
                    ? Color.primary
                    : Color.secondary
                        .opacity(
                            0.45
                        )
                )
            )
            .frame(
                maxWidth:
                    .infinity,
                minHeight:
                    34
            )
            .background(
                isSelected
                ? Color.accentColor
                : (
                    isToday
                    ? Color.accentColor
                        .opacity(
                            0.10
                        )
                    : Color.clear
                ),
                in:
                    RoundedRectangle(
                        cornerRadius:
                            8,
                        style:
                            .continuous
                    )
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
    }


    private func selectDay(
        _ newDay: Date
    ) {
        let calendar =
            selectedCalendar

        let day =
            calendar.dateComponents(
                [
                    .year,
                    .month,
                    .day
                ],
                from:
                    newDay
            )

        let time =
            calendar.dateComponents(
                [
                    .hour,
                    .minute,
                    .second
                ],
                from:
                    date
            )

        var components =
            DateComponents()

        components.year =
            day.year

        components.month =
            day.month

        components.day =
            day.day

        components.hour =
            time.hour
            ?? 0

        components.minute =
            time.minute
            ?? 0

        components.second =
            time.second
            ?? 0

        components.timeZone =
            selectedTimeZone

        if let newDate =
            calendar.date(
                from:
                    components
            )
        {
            date =
                newDate
        }
    }


    private func moveMonth(
        by delta: Int
    ) {
        guard
            let shifted =
                selectedCalendar
                    .date(
                        byAdding:
                            .month,
                        value:
                            delta,
                        to:
                            date
                    )
        else {
            return
        }

        date =
            shifted
    }


    private var dayBinding:
        Binding<Date>
    {
        Binding(
            get: {
                date
            },
            set: {
                newDay in

                var calendar =
                    selectedCalendar

                let day =
                    calendar
                        .dateComponents(
                            [
                                .year,
                                .month,
                                .day
                            ],
                            from:
                                newDay
                        )

                let time =
                    calendar
                        .dateComponents(
                            [
                                .hour,
                                .minute,
                                .second
                            ],
                            from:
                                date
                        )

                var components =
                    DateComponents()

                components.year =
                    day.year

                components.month =
                    day.month

                components.day =
                    day.day

                components.hour =
                    time.hour ?? 0

                components.minute =
                    time.minute ?? 0

                components.second =
                    time.second ?? 0

                components.timeZone =
                    selectedTimeZone

                if let merged =
                    calendar.date(
                        from:
                            components
                    )
                {
                    date =
                        merged
                }
            }
        )
    }


    // ========================================================
    // MARK: - Large time selector
    // ========================================================

    private var timeSection:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            Label(
                "Time",
                systemImage:
                    "clock"
            )
            .font(
                .system(
                    size: 15,
                    weight:
                        .semibold
                )
            )

            Text(
                timeText
            )
            .font(
                .system(
                    size: 38,
                    weight:
                        .semibold,
                    design:
                        .rounded
                )
            )
            .monospacedDigit()
            .foregroundStyle(
                .primary
            )

            HStack(
                alignment:
                    .top,
                spacing:
                    8
            ) {
                numberColumn(
                    title:
                        "Hour",
                    values:
                        Array(
                            0..<24
                        ),
                    selected:
                        selectedHour,
                    action:
                        setHour
                )

                Text(":")
                    .font(
                        .system(
                            size: 22,
                            weight:
                                .semibold,
                            design:
                                .rounded
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .padding(
                        .top,
                        43
                    )

                numberColumn(
                    title:
                        "Minute",
                    values:
                        Array(
                            0..<60
                        ),
                    selected:
                        selectedMinute,
                    action:
                        setMinute
                )
            }

            HStack(
                spacing:
                    6
            ) {
                quickActionButton(
                    title:
                        "Now",
                    systemImage:
                        "clock.arrow.circlepath"
                ) {
                    setToNow()
                }

                quickMinuteButton(
                    0
                )

                quickMinuteButton(
                    15
                )

                quickMinuteButton(
                    30
                )

                quickMinuteButton(
                    45
                )
            }
        }
        .frame(
            width: 250,
            alignment:
                .topLeading
        )
    }


    private func numberColumn(
        title: String,
        values: [Int],
        selected: Int,
        action:
            @escaping (Int) -> Void
    ) -> some View {
        VStack(
            alignment:
                .leading,
            spacing:
                6
        ) {
            Text(title)
                .font(
                    .system(
                        size: 11,
                        weight:
                            .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .padding(
                    .leading,
                    4
                )

            ScrollViewReader {
                proxy in

                ScrollView {
                    LazyVStack(
                        spacing: 3
                    ) {
                        ForEach(
                            values,
                            id:
                                \.self
                        ) {
                            value in

                            Button {
                                action(
                                    value
                                )

                            } label: {
                                Text(
                                    String(
                                        format:
                                            "%02d",
                                        value
                                    )
                                )
                                .font(
                                    .system(
                                        size: 16,
                                        weight:
                                            selected
                                                == value
                                            ? .semibold
                                            : .regular,
                                        design:
                                            .rounded
                                    )
                                )
                                .monospacedDigit()
                                .foregroundStyle(
                                    selected
                                        == value
                                    ? Color.accentColor
                                    : Color.primary
                                )
                                .frame(
                                    maxWidth:
                                        .infinity,
                                    minHeight:
                                        30
                                )
                                .contentShape(
                                    Rectangle()
                                )
                            }
                            .buttonStyle(
                                .plain
                            )
                            .id(
                                value
                            )
                            .background(
                                selected
                                    == value
                                ? Color
                                    .accentColor
                                    .opacity(
                                        0.12
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
                    }
                    .padding(
                        5
                    )
                }
                .scrollIndicators(
                    .hidden
                )
                .onAppear {
                    DispatchQueue
                        .main
                        .async {
                            proxy.scrollTo(
                                selected,
                                anchor:
                                    .center
                            )
                        }
                }
                .onChange(
                    of:
                        selected
                ) {
                    _,
                    newValue in

                    withAnimation(
                        .easeInOut(
                            duration:
                                0.16
                        )
                    ) {
                        proxy.scrollTo(
                            newValue,
                            anchor:
                                .center
                        )
                    }
                }
            }
            .frame(
                width: 86,
                height: 220
            )
            .background(
                Color.primary
                    .opacity(
                        0.028
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
                            0.10
                        ),
                    lineWidth:
                        1
                )
            }
        }
    }


    @ViewBuilder
    private func quickMinuteButton(
        _ minute: Int
    ) -> some View {
        let selected =
            selectedMinute
            == minute

        Button {
            setMinute(
                minute
            )

        } label: {
            Text(
                String(
                    format:
                        ":%02d",
                    minute
                )
            )
            .font(
                .system(
                    size: 11,
                    weight:
                        selected
                        ? .semibold
                        : .medium,
                    design:
                        .rounded
                )
            )
            .monospacedDigit()
            .foregroundStyle(
                selected
                ? Color.accentColor
                : Color.primary
            )
            .frame(
                minWidth: 38,
                minHeight: 28
            )
            .padding(
                .horizontal,
                2
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .background(
            selected
            ? Color.accentColor
                .opacity(
                    0.12
                )
            : Color.primary
                .opacity(
                    0.045
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
                selected
                ? Color.accentColor
                    .opacity(
                        0.25
                    )
                : Color.primary
                    .opacity(
                        0.08
                    ),
                lineWidth:
                    1
            )
        }
    }


    private func quickActionButton(
        title: String,
        systemImage: String,
        action:
            @escaping () -> Void
    ) -> some View {
        Button(
            action:
                action
        ) {
            HStack(
                spacing:
                    4
            ) {
                Image(
                    systemName:
                        systemImage
                )
                .font(
                    .system(
                        size: 10,
                        weight:
                            .semibold
                    )
                )

                Text(title)
                    .font(
                        .system(
                            size: 11,
                            weight:
                                .medium
                        )
                    )
            }
            .foregroundStyle(
                .primary
            )
            .frame(
                minHeight: 28
            )
            .padding(
                .horizontal,
                8
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .background(
            Color.primary
                .opacity(
                    0.045
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
                        0.08
                    ),
                lineWidth:
                    1
            )
        }
    }


    private var selectedHour:
        Int
    {
        selectedCalendar
            .component(
                .hour,
                from:
                    date
            )
    }


    private var selectedMinute:
        Int
    {
        selectedCalendar
            .component(
                .minute,
                from:
                    date
            )
    }


    private func setHour(
        _ hour: Int
    ) {
        setTime(
            hour:
                hour,
            minute:
                selectedMinute
        )
    }


    private func setMinute(
        _ minute: Int
    ) {
        setTime(
            hour:
                selectedHour,
            minute:
                minute
        )
    }


    private func setTime(
        hour: Int,
        minute: Int
    ) {
        var calendar =
            selectedCalendar

        let day =
            calendar
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day
                    ],
                    from:
                        date
                )

        var components =
            DateComponents()

        components.year =
            day.year

        components.month =
            day.month

        components.day =
            day.day

        components.hour =
            hour

        components.minute =
            minute

        components.second =
            0

        components.timeZone =
            selectedTimeZone

        if let updated =
            calendar.date(
                from:
                    components
            )
        {
            date =
                updated
        }
    }


    private func setToNow() {
        let now =
            Date()

        var calendar =
            selectedCalendar

        let nowComponents =
            calendar
                .dateComponents(
                    [
                        .hour,
                        .minute
                    ],
                    from:
                        now
                )

        setTime(
            hour:
                nowComponents.hour
                ?? 0,
            minute:
                nowComponents.minute
                ?? 0
        )
    }


    // ========================================================
    // MARK: - Time zone
    // ========================================================

    private var timeZoneSection:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                11
        ) {
            HStack {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {
                    Label(
                        "Time Zone",
                        systemImage:
                            "globe"
                    )
                    .font(
                        .system(
                            size: 14,
                            weight:
                                .semibold
                        )
                    )

                    Text(
                        "Changing the zone keeps the entered local clock time."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                Button {
                    selectTimeZone(
                        TestudoTime
                            .deviceTimeZoneID
                    )

                } label: {
                    Label(
                        "Use Device Time Zone",
                        systemImage:
                            "location"
                    )
                    .font(
                        .system(
                            size: 11,
                            weight:
                                .medium
                        )
                    )
                    .padding(
                        .horizontal,
                        9
                    )
                    .frame(
                        minHeight: 29
                    )
                }
                .buttonStyle(.plain)
                .background(
                    Color.primary
                        .opacity(
                            0.045
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
                                0.08
                            ),
                        lineWidth:
                            1
                    )
                }
            }

            HStack(
                spacing:
                    10
            ) {
                Image(
                    systemName:
                        "globe.europe.africa"
                )
                .foregroundStyle(
                    .secondary
                )

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {
                    Text(
                        TestudoTime
                            .shortTimeZoneLabel(
                                identifier:
                                    timeZoneID
                            )
                    )
                    .font(
                        .system(
                            size: 13,
                            weight:
                                .medium
                        )
                    )

                    Text(
                        "\(offsetText(for: timeZoneID)) · \(timeZoneID)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                if
                    timeZoneID
                        == TestudoTime
                            .deviceTimeZoneID
                {
                    Text("DEVICE")
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
                        .padding(
                            .horizontal,
                            7
                        )
                        .padding(
                            .vertical,
                            4
                        )
                        .background(
                            Color.primary
                                .opacity(
                                    0.06
                                ),
                            in:
                                Capsule()
                        )
                }
            }
            .padding(
                .horizontal,
                11
            )
            .padding(
                .vertical,
                9
            )
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
                    "Search time zones",
                    text:
                        $timeZoneSearch
                )
                .textFieldStyle(
                    .plain
                )

                if
                    !timeZoneSearch
                        .isEmpty
                {
                    Button {
                        timeZoneSearch =
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

            ScrollView {
                LazyVStack(
                    spacing:
                        2
                ) {
                    ForEach(
                        filteredTimeZones,
                        id:
                            \.self
                    ) {
                        identifier in

                        timeZoneRow(
                            identifier
                        )
                    }
                }
                .padding(
                    4
                )
            }
            .frame(
                height:
                    140
            )
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


    private func timeZoneRow(
        _ identifier:
            String
    ) -> some View {
        Button {
            selectTimeZone(
                identifier
            )

        } label: {
            HStack(
                spacing: 10
            ) {
                Image(
                    systemName:
                        identifier
                            == timeZoneID
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    identifier
                        == timeZoneID
                    ? .primary
                    : .tertiary
                )

                VStack(
                    alignment:
                        .leading,
                    spacing: 1
                ) {
                    Text(
                        TestudoTime
                            .shortTimeZoneLabel(
                                identifier:
                                    identifier
                            )
                    )
                    .foregroundStyle(
                        .primary
                    )

                    Text(
                        "\(offsetText(for: identifier)) · \(identifier)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()
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
        .buttonStyle(.plain)
        .background(
            identifier
                == timeZoneID
            ? Color.primary
                .opacity(
                    0.045
                )
            : Color.clear,
            in:
                RoundedRectangle(
                    cornerRadius:
                        6,
                    style:
                        .continuous
                )
        )
    }


    private var filteredTimeZones:
        [String]
    {
        let query =
            timeZoneSearch
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()


        if query.isEmpty {
            let frequent =
                store
                    .mostUsedTimeZoneIdentifiers(
                        limit:
                            5
                    )

            let frequentSet =
                Set(
                    frequent
                )

            let remaining =
                TestudoTime
                    .knownTimeZoneIdentifiers
                    .filter {
                        !frequentSet
                            .contains(
                                $0
                            )
                    }

            return
                frequent
                + remaining
        }


        return
            TestudoTime
                .knownTimeZoneIdentifiers
                .filter {
                    identifier in

                    identifier
                        .lowercased()
                        .contains(
                            query
                        )
                    ||
                    TestudoTime
                        .shortTimeZoneLabel(
                            identifier:
                                identifier
                        )
                        .lowercased()
                        .contains(
                            query
                        )
                }
    }


    private func selectTimeZone(
        _ identifier:
            String
    ) {
        guard
            identifier
                != timeZoneID
        else {
            return
        }

        let oldID =
            TestudoTime
                .validTimeZoneIdentifier(
                    timeZoneID
                )
            ?? TestudoTime
                .deviceTimeZoneID

        date =
            TestudoTime
                .reinterpreting(
                    date,
                    fromTimeZoneID:
                        oldID,
                    toTimeZoneID:
                        identifier
                )

        timeZoneID =
            identifier
    }


    // ========================================================
    // MARK: - Helpers
    // ========================================================

    private var selectedTimeZone:
        TimeZone
    {
        TimeZone(
            identifier:
                timeZoneID
        )
        ?? .autoupdatingCurrent
    }


    private var selectedCalendar:
        Calendar
    {
        var calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        calendar.locale =
            .autoupdatingCurrent

        calendar.timeZone =
            selectedTimeZone

        // Testudo uses a Monday-first working week.
        calendar.firstWeekday =
            2

        calendar.minimumDaysInFirstWeek =
            4

        return calendar
    }


    private var timeText:
        String
    {
        String(
            format:
                "%02d:%02d",
            selectedHour,
            selectedMinute
        )
    }


    private func offsetText(
        for identifier:
            String
    ) -> String {
        guard
            let zone =
                TimeZone(
                    identifier:
                        identifier
                )
        else {
            return "GMT"
        }

        let seconds =
            zone.secondsFromGMT(
                for:
                    date
            )

        let sign =
            seconds >= 0
            ? "+"
            : "−"

        let absolute =
            abs(seconds)

        return String(
            format:
                "GMT%@%02d:%02d",
            sign,
            absolute / 3600,
            (
                absolute
                % 3600
            ) / 60
        )
    }
}
