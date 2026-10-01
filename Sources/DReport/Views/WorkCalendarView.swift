import SwiftUI

struct WorkCalendarView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Binding
    var selectedWorkItemID: UUID?

    @State
    private var selectedDate = Date()

    @State
    private var visibleMonth = Date()

    private var calendar: Calendar {
        Calendar.current
    }

    private let columns =
        Array(
            repeating:
                GridItem(
                    .flexible(),
                    spacing: 3
                ),
            count: 7
        )

    var body: some View {
        VStack(spacing: 0) {
            calendarHeader

            monthCalendar
                .padding(
                    .horizontal,
                    12
                )
                .padding(
                    .bottom,
                    14
                )

            selectedDayHeader

            if selectedDayOccurrences.isEmpty {
                ContentUnavailableView {
                    Label(
                        "Nothing Scheduled",
                        systemImage:
                            "calendar"
                    )
                } description: {
                    Text(
                        "No deadlines, events or reminders are assigned to this day."
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            } else {
                agenda
            }
        }
        .background(
            DReportStyle.contentBackground
        )
        .onAppear {
            selectedDate =
                calendar.startOfDay(
                    for: Date()
                )

            visibleMonth =
                startOfMonth(
                    Date()
                )
        }
    }

    private var calendarHeader:
        some View
    {
        HStack(spacing: 8) {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text("Calendar")
                    .font(.headline)

                Text(
                    monthTitle
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Button {
                moveMonth(
                    by: -1
                )
            } label: {
                Image(
                    systemName:
                        "chevron.left"
                )
            }
            .buttonStyle(.plain)
            .help(
                "Previous month"
            )

            Button("Today") {
                goToToday()
            }
            .buttonStyle(.borderless)

            Button {
                moveMonth(
                    by: 1
                )
            } label: {
                Image(
                    systemName:
                        "chevron.right"
                )
            }
            .buttonStyle(.plain)
            .help(
                "Next month"
            )
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .top,
            14
        )
        .padding(
            .bottom,
            10
        )
    }

    private var monthCalendar:
        some View
    {
        VStack(spacing: 5) {
            LazyVGrid(
                columns: columns,
                spacing: 3
            ) {
                ForEach(
                    weekdaySymbols,
                    id: \.self
                ) { symbol in
                    Text(symbol)
                        .font(
                            .system(
                                size: 10,
                                weight:
                                    .medium
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
            }

            LazyVGrid(
                columns: columns,
                spacing: 4
            ) {
                ForEach(
                    Array(
                        monthDates
                            .enumerated()
                    ),
                    id: \.offset
                ) { _, date in
                    if let date {
                        dayButton(
                            date
                        )
                    } else {
                        Color.clear
                            .frame(
                                height: 48
                            )
                    }
                }
            }
        }
    }

    private func dayButton(
        _ date: Date
    ) -> some View {
        let selected =
            calendar.isDate(
                date,
                inSameDayAs:
                    selectedDate
            )

        let today =
            calendar.isDateInToday(
                date
            )

        let summary =
            summaryForDay(
                date
            )

        return Button {
            selectedDate =
                calendar.startOfDay(
                    for: date
                )
        } label: {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 7
                )
                .fill(
                    selected
                    ? Color.accentColor
                    : Color.clear
                )

                if today && !selected {
                    RoundedRectangle(
                        cornerRadius: 7
                    )
                    .stroke(
                        Color.accentColor,
                        lineWidth: 1
                    )
                }

                VStack(
                    spacing: 4
                ) {
                    HStack {
                        Text(
                            "\(calendar.component(.day, from: date))"
                        )
                        .font(
                            .system(
                                size: 12,
                                weight:
                                    today
                                    || selected
                                    ? .semibold
                                    : .regular
                            )
                        )

                        Spacer()

                        if summary.total > 0 {
                            Text(
                                "\(summary.total)"
                            )
                            .font(
                                .system(
                                    size: 9,
                                    weight:
                                        .medium
                                )
                            )
                            .opacity(
                                0.8
                            )
                        }
                    }

                    Spacer(
                        minLength: 0
                    )

                    HStack(
                        spacing: 3
                    ) {
                        if
                            summary.deadlines
                                > 0
                        {
                            Image(
                                systemName:
                                    "circle"
                            )
                        }

                        if
                            summary.reminders
                                > 0
                        {
                            Image(
                                systemName:
                                    "bell"
                            )
                        }

                        Spacer(
                            minLength: 0
                        )
                    }
                    .font(
                        .system(
                            size: 8
                        )
                    )
                    .opacity(
                        summary.total > 0
                        ? 0.85
                        : 0
                    )
                }
                .foregroundStyle(
                    selected
                    ? Color.white
                    : Color.primary
                )
                .padding(6)
            }
            .frame(height: 48)
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedDayHeader:
        some View
    {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    selectedDate.formatted(
                        .dateTime
                            .weekday(.wide)
                            .day()
                            .month(.wide)
                    )
                )
                .font(.headline)

                Text(
                    selectedDaySubtitle
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
            16
        )
        .padding(
            .vertical,
            10
        )
    }

    private var agenda:
        some View
    {
        List(
            selection:
                $selectedWorkItemID
        ) {
            agendaSection(
                title: "Deadlines",
                occurrences:
                    deadlineOccurrences
            )

            agendaSection(
                title: "Reminders",
                occurrences:
                    reminderOccurrences
            )
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func agendaSection(
        title: String,
        occurrences:
            [CalendarOccurrence]
    ) -> some View {
        if !occurrences.isEmpty {
            Section(title) {
                ForEach(
                    occurrences
                ) { occurrence in
                    WorkGuideRow(
                        item:
                            occurrence.item,
                        context:
                            occurrence.context
                    )
                    .tag(
                        occurrence.item.id
                    )
                }
            }
        }
    }

    private var selectedDayOccurrences:
        [CalendarOccurrence]
    {
        occurrences(
            on: selectedDate
        )
    }

    private var deadlineOccurrences:
        [CalendarOccurrence]
    {
        selectedDayOccurrences
            .filter {
                $0.kind
                    == .deadline
            }
    }

    private var reminderOccurrences:
        [CalendarOccurrence]
    {
        selectedDayOccurrences
            .filter {
                $0.kind
                    == .reminder
            }
    }

    private var selectedDaySubtitle:
        String
    {
        let count =
            selectedDayOccurrences.count

        if count == 0 {
            return
                "No scheduled items"
        }

        if count == 1 {
            return
                "1 scheduled item"
        }

        return
            "\(count) scheduled items"
    }

    private var monthTitle:
        String
    {
        startOfMonth(
            visibleMonth
        )
        .formatted(
            .dateTime
                .month(.wide)
                .year()
        )
    }

    private var weekdaySymbols:
        [String]
    {
        let symbols =
            calendar
                .veryShortStandaloneWeekdaySymbols

        let offset =
            max(
                0,
                min(
                    6,
                    calendar.firstWeekday
                        - 1
                )
            )

        return (0..<7).map {
            symbols[
                ($0 + offset) % 7
            ]
        }
    }

    private var monthDates:
        [Date?]
    {
        let month =
            startOfMonth(
                visibleMonth
            )

        let weekday =
            calendar.component(
                .weekday,
                from: month
            )

        let leading =
            (
                weekday
                - calendar.firstWeekday
                + 7
            ) % 7

        guard
            let range =
                calendar.range(
                    of: .day,
                    in: .month,
                    for: month
                )
        else {
            return []
        }

        var result =
            Array<Date?>(
                repeating: nil,
                count: leading
            )

        var components =
            calendar.dateComponents(
                [
                    .year,
                    .month
                ],
                from: month
            )

        for day in range {
            components.day =
                day

            if
                let date =
                    calendar.date(
                        from:
                            components
                    )
            {
                result.append(
                    date
                )
            }
        }

        while
            result.count % 7
                != 0
        {
            result.append(nil)
        }

        return result
    }

    private func occurrences(
        on date: Date
    ) -> [CalendarOccurrence] {
        var result:
            [CalendarOccurrence] = []

        for item in
            store.data.workItems
        {
            if
                item.kind == .task,
                let deadline =
                    item.deadlineAt,
                calendar.isDate(
                    deadline,
                    inSameDayAs:
                        date
                )
            {
                result.append(
                    CalendarOccurrence(
                        item: item,
                        kind: .deadline,
                        date: deadline
                    )
                )
            }

            if
                item.kind == .note,
                let reminder =
                    item.reminderAt,
                calendar.isDate(
                    reminder,
                    inSameDayAs:
                        date
                )
            {
                result.append(
                    CalendarOccurrence(
                        item: item,
                        kind: .reminder,
                        date: reminder
                    )
                )
            }
        }

        return result.sorted {
            if $0.date == $1.date {
                return
                    $0.kind.sortOrder
                    < $1.kind.sortOrder
            }

            return
                $0.date < $1.date
        }
    }

    private func summaryForDay(
        _ date: Date
    ) -> CalendarDaySummary {
        let items =
            occurrences(
                on: date
            )

        return CalendarDaySummary(
            deadlines:
                items.filter {
                    $0.kind == .deadline
                }.count,
            reminders:
                items.filter {
                    $0.kind == .reminder
                }.count
        )
    }

    private func startOfMonth(
        _ date: Date
    ) -> Date {
        let components =
            calendar.dateComponents(
                [
                    .year,
                    .month
                ],
                from: date
            )

        return calendar.date(
            from: components
        ) ?? date
    }

    private func moveMonth(
        by offset: Int
    ) {
        let oldDay =
            calendar.component(
                .day,
                from: selectedDate
            )

        guard
            let newMonth =
                calendar.date(
                    byAdding: .month,
                    value: offset,
                    to:
                        startOfMonth(
                            visibleMonth
                        )
                )
        else {
            return
        }

        visibleMonth =
            startOfMonth(
                newMonth
            )

        guard
            let dayRange =
                calendar.range(
                    of: .day,
                    in: .month,
                    for:
                        visibleMonth
                )
        else {
            selectedDate =
                visibleMonth
            return
        }

        let targetDay =
            min(
                oldDay,
                dayRange.count
            )

        var components =
            calendar.dateComponents(
                [
                    .year,
                    .month
                ],
                from:
                    visibleMonth
            )

        components.day =
            targetDay

        selectedDate =
            calendar.date(
                from: components
            )
            ?? visibleMonth
    }

    private func goToToday() {
        let today =
            calendar.startOfDay(
                for: Date()
            )

        selectedDate =
            today

        visibleMonth =
            startOfMonth(
                today
            )
    }
}

private struct CalendarDaySummary {
    let deadlines: Int
    let reminders: Int

    var total: Int {
        deadlines
        + reminders
    }
}

private struct CalendarOccurrence:
    Identifiable
{
    enum Kind:
        String
    {
        case deadline
        case reminder

        var sortOrder: Int {
            switch self {
            case .deadline:
                return 0
            case .reminder:
                return 1
            }
        }
    }

    let item: WorkItem
    let kind: Kind
    let date: Date

    var id: String {
        [
            item.id.uuidString,
            kind.rawValue,
            String(
                date.timeIntervalSince1970
            )
        ]
        .joined(separator: "-")
    }

    var context: String {
        switch kind {
        case .deadline:
            if
                date.formatted(
                    date: .omitted,
                    time: .shortened
                )
                == "00:00"
            {
                return "Deadline"
            }

            return
                "Due \(date.formatted(date: .omitted, time: .shortened))"

        case .reminder:
            return
                "Reminder \(date.formatted(date: .omitted, time: .shortened))"
        }
    }
}
