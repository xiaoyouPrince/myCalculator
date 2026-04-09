import SwiftUI

struct MonthView: View {
    @Binding var date: Date
    @Binding var daySchedules: [Date: WorkSchedule]
    private let weekDayTitles = ["一", "二", "三", "四", "五", "六", "日"]
    @State private var selectedPanelDate: Date?
    @State private var isEditingTime = false
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
                    Text(date.formatted(.dateTime.year().month()))
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
                        onEdit: { isEditingTime = true },
                        onClose: { selectedPanelDate = nil }
                    )
                    .frame(width: 420, height: 320)
                } else {
                    WorkTimeInputPanel(
                        targetDate: panelDate,
                        workStartTime: $workStartTime,
                        workEndTime: $workEndTime,
                        onSave: {
                            let key = normalizedDay(panelDate)
                            daySchedules[key] = WorkSchedule(
                                startHour: Calendar.current.component(.hour, from: workStartTime),
                                startMinute: Calendar.current.component(.minute, from: workStartTime),
                                endHour: Calendar.current.component(.hour, from: workEndTime),
                                endMinute: Calendar.current.component(.minute, from: workEndTime)
                            )
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
                cellHeight: cellHeight,
                scheduleSummary: scheduleSummary(for: day.id),
                onTap: { openPanel(for: day.id) }
            )
        }
    }

    private func openPanel(for targetDate: Date) {
        let key = normalizedDay(targetDate)
        if let schedule = daySchedules[key] {
            workStartTime = MonthView.makeTime(hour: schedule.startHour, minute: schedule.startMinute)
            workEndTime = MonthView.makeTime(hour: schedule.endHour, minute: schedule.endMinute)
            isEditingTime = false
        } else {
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

        var weeks: [MonthWeek] = []
        var cursor = firstMonday

        while true {
            let weekOfYear = calendar.component(.weekOfYear, from: cursor)
            var days: [MonthDay] = []

            for offset in 0..<7 {
                guard let currentDate = calendar.date(byAdding: .day, value: offset, to: cursor) else {
                    continue
                }
                let inCurrentMonth = calendar.isDate(currentDate, equalTo: date, toGranularity: .month)
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
                return calendar.isDate(d, equalTo: date, toGranularity: .month)
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

    private func changeMonth(by value: Int) {
        guard let target = Calendar.current.date(byAdding: .month, value: value, to: date) else { return }
        date = target
    }

    private func adaptiveCellHeight(containerHeight: CGFloat, weekCount: Int) -> CGFloat {
        let usableHeight = max(320, containerHeight - 48)
        let rows = max(1, CGFloat(weekCount))
        let estimated = (usableHeight - 32) / rows
        return min(148, max(88, estimated))
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
    let cellHeight: CGFloat
    let scheduleSummary: MonthScheduleSummary?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(day.day)")
                    .font(.subheadline)
                    .foregroundStyle(day.isCurrentMonth ? Color.primary : Color.secondary.opacity(0.5))
                    .padding(.top, 8)
                    .padding(.leading, 8)

                if let summary = scheduleSummary {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.timeRangeText)
                        Text(summary.workDurationText)
                        Text(summary.workHoursText)
                        Text(summary.overtimeText)
                        Text(summary.effectiveOvertimeText)
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight, alignment: .topLeading)
            .background(day.isToday ? Color.blue.opacity(0.14) : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
