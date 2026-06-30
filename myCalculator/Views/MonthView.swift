import SwiftUI

struct MonthView: View {
    @Binding var date: Date
    @Binding var daySchedules: [Date: WorkSchedule]
    @Binding var emphasizesEffectiveOvertime: Bool
    private let weekDayTitles = ["一", "二", "三", "四", "五", "六", "日"]
    @State private var selectedPanelDate: Date?
    @State private var isEditingTime = false
    @State private var selectedKind: WorkLogKind = .work
    @State private var customNote = ""
    @State private var workStartTime: Date = MonthView.makeTime(hour: 9, minute: 0)
    @State private var workEndTime: Date = MonthView.makeTime(hour: 18, minute: 0)

    private var gridColumns: [GridItem] {
        [GridItem(.fixed(52), spacing: 0)] + Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }

    var body: some View {
        let monthData = buildMonthData(for: date)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("月视图")
                        .font(.title2.bold())
                    Text(monthTitle)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
            }

            GeometryReader { proxy in
                let adaptiveHeight = adaptiveCellHeight(containerHeight: proxy.size.height, weekCount: monthData.count)

                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 0) {
                        monthHeaderRow
                        ForEach(Array(monthData.enumerated()), id: \.offset) { _, week in
                            weekRow(week, cellHeight: adaptiveHeight)
                        }
                    }
                    .id(monthIdentity)
                }
            }
        }
        .padding(20)
        .sheet(
            isPresented: Binding(
                get: { selectedPanelDate != nil },
                set: { if !$0 { selectedPanelDate = nil } }
            )
        ) {
            if let panelDate = selectedPanelDate {
                if let summary = daySchedules[normalizedDay(panelDate)].map(MonthScheduleSummary.from), !isEditingTime {
                    WorkDetailPanel(
                        targetDate: panelDate,
                        summary: summary,
                        emphasizesEffectiveOvertime: emphasizesEffectiveOvertime,
                        onEdit: { isEditingTime = true },
                        onClose: { selectedPanelDate = nil }
                    )
                    .frame(width: 420, height: 320)
                } else {
                    WorkTimeInputPanel(
                        targetDate: panelDate,
                        selectedKind: $selectedKind,
                        customNote: $customNote,
                        workStartTime: $workStartTime,
                        workEndTime: $workEndTime,
                        onSave: {
                            let key = normalizedDay(panelDate)
                            daySchedules[key] = makeScheduleFromEditor()
                            persistSchedules()
                            selectedPanelDate = nil
                        },
                        onCancel: {
                            selectedPanelDate = nil
                        }
                    )
                    .frame(width: 360, height: 280)
                }
            }
        }
    }

    @ViewBuilder
    private var monthHeaderRow: some View {
        MonthHeaderCell(title: "周")
        ForEach(weekDayTitles, id: \.self) { weekday in
            MonthHeaderCell(title: weekday)
        }
    }

    @ViewBuilder
    private func weekRow(_ week: MonthWeek, cellHeight: CGFloat) -> some View {
        MonthWeekNumberCell(weekNumber: week.weekOfYear, cellHeight: cellHeight)
        ForEach(week.days) { day in
            MonthDayCell(
                day: day,
                displayedMonthDate: date,
                cellHeight: cellHeight,
                scheduleSummary: scheduleSummary(for: day.id),
                emphasizesEffectiveOvertime: emphasizesEffectiveOvertime,
                onTap: { openPanel(for: day.id) }
            )
        }
    }

    private func openPanel(for targetDate: Date) {
        let key = normalizedDay(targetDate)
        if let schedule = daySchedules[key] {
            selectedKind = schedule.kind
            customNote = schedule.kind == .custom ? schedule.note : ""
            if schedule.isWorkLog {
                workStartTime = MonthView.makeTime(hour: schedule.startHour, minute: schedule.startMinute)
                workEndTime = MonthView.makeTime(hour: schedule.endHour, minute: schedule.endMinute)
            } else {
                workStartTime = MonthView.makeTime(hour: 9, minute: 0)
                workEndTime = MonthView.makeTime(hour: 18, minute: 0)
            }
            isEditingTime = false
        } else {
            selectedKind = .work
            customNote = ""
            workStartTime = MonthView.makeTime(hour: 9, minute: 0)
            workEndTime = MonthView.makeTime(hour: 18, minute: 0)
            isEditingTime = true
        }
        selectedPanelDate = key
    }

    private func scheduleSummary(for targetDate: Date) -> MonthScheduleSummary? {
        let key = normalizedDay(targetDate)
        guard let schedule = daySchedules[key] else { return nil }
        return MonthScheduleSummary.from(schedule: schedule)
    }

    private func normalizedDay(_ input: Date) -> Date {
        Calendar.current.startOfDay(for: input)
    }

    private func buildMonthData(for date: Date) -> [MonthWeek] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        guard
            let interval = calendar.dateInterval(of: .month, for: date),
            let firstMonday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: interval.start))
        else {
            return []
        }

        let targetYear = calendar.component(.year, from: interval.start)
        let targetMonth = calendar.component(.month, from: interval.start)
        var weeks: [MonthWeek] = []
        var cursor = firstMonday

        while true {
            let weekOfYear = calendar.component(.weekOfYear, from: cursor)
            var days: [MonthDay] = []

            for offset in 0..<7 {
                guard let currentDate = calendar.date(byAdding: .day, value: offset, to: cursor) else {
                    continue
                }
                let inCurrentMonth = calendar.component(.year, from: currentDate) == targetYear &&
                    calendar.component(.month, from: currentDate) == targetMonth
                days.append(
                    MonthDay(
                        id: currentDate,
                        day: calendar.component(.day, from: currentDate),
                        isCurrentMonth: inCurrentMonth,
                        isToday: calendar.isDateInToday(currentDate)
                    )
                )
            }

            weeks.append(MonthWeek(weekOfYear: weekOfYear, days: days))

            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            let hasCurrentMonth = days.contains { $0.isCurrentMonth }
            let nextStillHasCurrentMonth = (0..<7).contains { offset in
                guard let d = calendar.date(byAdding: .day, value: offset, to: nextWeek) else { return false }
                return calendar.component(.year, from: d) == targetYear &&
                    calendar.component(.month, from: d) == targetMonth
            }

            if hasCurrentMonth && !nextStillHasCurrentMonth {
                break
            }
            cursor = nextWeek
        }

        return weeks
    }

    private static func makeTime(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func persistSchedules() {
        WorkScheduleStore.save(daySchedules)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private var monthIdentity: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return "\(year)-\(month)"
    }

    private func changeMonth(by value: Int) {
        let calendar = Calendar.current
        let anchorDate = calendar.dateInterval(of: .month, for: date)?.start ?? date
        guard let target = calendar.date(byAdding: .month, value: value, to: anchorDate) else { return }
        date = target
    }

    private func adaptiveCellHeight(containerHeight: CGFloat, weekCount: Int) -> CGFloat {
        let usableHeight = max(320, containerHeight - 48)
        let rows = max(1, CGFloat(weekCount))
        let estimated = (usableHeight - 32) / rows
        return min(148, max(88, estimated))
    }

    private func makeScheduleFromEditor() -> WorkSchedule {
        if selectedKind == .work {
            return WorkSchedule(
                startHour: Calendar.current.component(.hour, from: workStartTime),
                startMinute: Calendar.current.component(.minute, from: workStartTime),
                endHour: Calendar.current.component(.hour, from: workEndTime),
                endMinute: Calendar.current.component(.minute, from: workEndTime)
            )
        }

        return WorkSchedule(
            kind: selectedKind,
            note: selectedKind == .custom ? customNote.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        )
    }
}

struct MonthHeaderCell: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.08))
    }
}

struct MonthWeekNumberCell: View {
    let weekNumber: Int
    let cellHeight: CGFloat

    var body: some View {
        Text("\(weekNumber)")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .frame(minHeight: cellHeight)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
    }
}

struct MonthDayCell: View {
    let day: MonthDay
    let displayedMonthDate: Date
    let cellHeight: CGFloat
    let scheduleSummary: MonthScheduleSummary?
    let emphasizesEffectiveOvertime: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(day.day)")
                    .font(.subheadline)
                    .foregroundStyle(isInDisplayedMonth ? Color.black.opacity(0.82) : Color.secondary.opacity(0.45))
                    .padding(.top, 8)
                    .padding(.leading, 8)

                if let summary = scheduleSummary {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(summary.lines, id: \.self) { line in
                            WorkSummaryLineText(
                                line: line,
                                emphasizesEffectiveOvertime: emphasizesEffectiveOvertime,
                                defaultColor: summaryForegroundStyle
                            )
                        }
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight, alignment: .topLeading)
            .background(day.isToday && isInDisplayedMonth ? Color.blue.opacity(0.14) : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var isInDisplayedMonth: Bool {
        let calendar = Calendar.current
        return calendar.component(.year, from: day.id) == calendar.component(.year, from: displayedMonthDate) &&
            calendar.component(.month, from: day.id) == calendar.component(.month, from: displayedMonthDate)
    }

    private var summaryForegroundStyle: Color {
        guard isInDisplayedMonth else {
            return Color.secondary.opacity(0.45)
        }
        return scheduleSummary?.isWorkLog == true ? .blue : .secondary
    }
}
