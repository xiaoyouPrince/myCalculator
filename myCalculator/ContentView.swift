//
//  ContentView.swift
//  myCalculator
//
//  Created by 渠晓友 on 2026/4/9.
//

import SwiftUI
import AppKit

struct ContentView: View {
    enum CalendarMode: String, CaseIterable, Identifiable {
        case day = "日"
        case week = "周"
        case month = "月"
        case year = "年"

        var id: String { rawValue }
    }

    @State private var selectedMode: CalendarMode = .month
    @State private var selectedDate: Date = .now
    @State private var daySchedules: [Date: WorkSchedule] = [:]

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedDate: $selectedDate,
                daySchedules: $daySchedules,
                onOpenJSONFile: openPersistedJSONFile
            )
                .frame(minWidth: 260)
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                CalendarContentView(mode: $selectedMode, date: $selectedDate, daySchedules: $daySchedules)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.windowBackgroundColor))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            daySchedules = WorkScheduleStore.load()
        }
    }

    private func openPersistedJSONFile() {
        let fileURL = WorkScheduleStore.persistedFileURL()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            WorkScheduleStore.save([:])
        }
        NSWorkspace.shared.open(fileURL)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("今天") {
                selectedDate = .now
            }
            .buttonStyle(.bordered)

            HStack(spacing: 8) {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.bordered)

            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
                .frame(minWidth: 180, alignment: .leading)

            Spacer()

            Picker("视图模式", selection: $selectedMode) {
                ForEach(CalendarMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}

private struct SidebarView: View {
    @Binding var selectedDate: Date
    @Binding var daySchedules: [Date: WorkSchedule]
    let onOpenJSONFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择日期")
                    .font(.headline)
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.75))
            )

            Text("当日")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                if let summary = selectedDaySummary {
                    Text(summary.timeRangeText)
                    Text(summary.workDurationText)
                    Text(summary.workHoursText)
                    Text(summary.overtimeText)
                    Text(summary.effectiveOvertimeText)
                } else {
                    Text("当日暂无记录")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            Text(weekTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let summary = selectedWeekSummary {
                    Text("录入天数 \(summary.recordedDays) 天")
                    Text("周工作时长 \(String(format: "%.2f", summary.workHours)) 小时")
                    Text("周加班时长 \(String(format: "%.2f", summary.overtimeHours)) 小时")
                    Text("周有效加班 \(String(format: "%.2f", summary.effectiveOvertimeHours)) 小时")
                } else {
                    Text("当周暂无记录")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            Text(monthTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let summary = selectedMonthSummary {
                    Text("录入天数 \(summary.recordedDays) 天")
                    Text("月工作时长 \(String(format: "%.2f", summary.workHours)) 小时")
                    Text("月加班时长 \(String(format: "%.2f", summary.overtimeHours)) 小时")
                    Text("月有效加班 \(String(format: "%.2f", summary.effectiveOvertimeHours)) 小时")
                } else {
                    Text("当月暂无记录")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            Spacer()

            Button(action: onOpenJSONFile) {
                Label("查看 JSON", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .controlAccentColor))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.96),
                    Color(nsColor: .controlBackgroundColor).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var selectedDaySummary: MonthScheduleSummary? {
        let selectedKey = Calendar.current.startOfDay(for: selectedDate)
        guard let schedule = daySchedules[selectedKey] else { return nil }
        return MonthScheduleSummary.from(schedule: schedule)
    }

    private var weekTitle: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let weekYear = calendar.component(.yearForWeekOfYear, from: selectedDate)
        let weekOfYear = calendar.component(.weekOfYear, from: selectedDate)
        return "当周(\(weekYear)年第\(weekOfYear)周)"
    }

    private var selectedWeekSummary: WeekSummary? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        guard
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate)
        else {
            return nil
        }

        let startDay = calendar.startOfDay(for: weekInterval.start)
        let endDay = calendar.startOfDay(for: weekInterval.end)

        let schedulesInWeek = daySchedules.filter { day, _ in
            let normalized = calendar.startOfDay(for: day)
            return normalized >= startDay && normalized < endDay
        }

        guard !schedulesInWeek.isEmpty else { return nil }

        var totalWorkMinutes = 0
        var totalOvertimeHours = 0.0
        var totalEffectiveOvertimeHours = 0.0

        for (_, schedule) in schedulesInWeek {
            let metrics = WorkMetrics.from(schedule: schedule)
            totalWorkMinutes += metrics.workMinutes
            totalOvertimeHours += metrics.overtimeHours
            totalEffectiveOvertimeHours += metrics.effectiveOvertimeHours
        }

        return WeekSummary(
            recordedDays: schedulesInWeek.count,
            workHours: Double(totalWorkMinutes) / 60.0,
            overtimeHours: totalOvertimeHours,
            effectiveOvertimeHours: totalEffectiveOvertimeHours
        )
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return "当月(\(formatter.string(from: selectedDate)))"
    }

    private var selectedMonthSummary: WeekSummary? {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)

        let schedulesInMonth = daySchedules.filter { day, _ in
            let normalized = calendar.startOfDay(for: day)
            return calendar.component(.year, from: normalized) == year &&
                calendar.component(.month, from: normalized) == month
        }

        guard !schedulesInMonth.isEmpty else { return nil }

        var totalWorkMinutes = 0
        var totalOvertimeHours = 0.0
        var totalEffectiveOvertimeHours = 0.0

        for (_, schedule) in schedulesInMonth {
            let metrics = WorkMetrics.from(schedule: schedule)
            totalWorkMinutes += metrics.workMinutes
            totalOvertimeHours += metrics.overtimeHours
            totalEffectiveOvertimeHours += metrics.effectiveOvertimeHours
        }

        return WeekSummary(
            recordedDays: schedulesInMonth.count,
            workHours: Double(totalWorkMinutes) / 60.0,
            overtimeHours: totalOvertimeHours,
            effectiveOvertimeHours: totalEffectiveOvertimeHours
        )
    }

}

private struct CalendarContentView: View {
    @Binding var mode: ContentView.CalendarMode
    @Binding var date: Date
    @Binding var daySchedules: [Date: WorkSchedule]

    var body: some View {
        switch mode {
        case .day:
            DayView(date: $date, daySchedules: $daySchedules)
        case .week:
            WeekView(date: $date, daySchedules: $daySchedules)
        case .month:
            MonthView(date: date, daySchedules: $daySchedules)
        case .year:
            YearView(date: $date, mode: $mode)
        }
    }
}

private struct DayView: View {
    @Binding var date: Date
    @Binding var daySchedules: [Date: WorkSchedule]
    @State private var showEditPanel = false
    @State private var workStartTime: Date = DayView.makeTime(hour: 9, minute: 0)
    @State private var workEndTime: Date = DayView.makeTime(hour: 18, minute: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("日视图")
                    .font(.title2.bold())
                Spacer()
                Button("编辑") {
                    prepareEditor()
                    showEditPanel = true
                }
                .buttonStyle(.borderedProminent)
            }

            Text(date.formatted(date: .complete, time: .omitted))
                .foregroundStyle(.secondary)
            Divider()

            if let summary = selectedDaySummary {
                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.timeRangeText)
                    Text(summary.workDurationText)
                    Text(summary.workHoursText)
                    Text(summary.overtimeText)
                    Text(summary.effectiveOvertimeText)
                }
                .font(.body)
            } else {
                Text("当日暂无记录，点击右上角“编辑”填写上下班时间。")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .sheet(isPresented: $showEditPanel) {
            WorkTimeInputPanel(
                targetDate: normalizedDay(date),
                workStartTime: $workStartTime,
                workEndTime: $workEndTime,
                onSave: {
                    let key = normalizedDay(date)
                    daySchedules[key] = WorkSchedule(
                        startHour: Calendar.current.component(.hour, from: workStartTime),
                        startMinute: Calendar.current.component(.minute, from: workStartTime),
                        endHour: Calendar.current.component(.hour, from: workEndTime),
                        endMinute: Calendar.current.component(.minute, from: workEndTime)
                    )
                    WorkScheduleStore.save(daySchedules)
                    showEditPanel = false
                },
                onCancel: {
                    showEditPanel = false
                }
            )
            .frame(width: 360, height: 280)
        }
    }

    private var selectedDaySummary: MonthScheduleSummary? {
        let key = normalizedDay(date)
        guard let schedule = daySchedules[key] else { return nil }
        return MonthScheduleSummary.from(schedule: schedule)
    }

    private func prepareEditor() {
        let key = normalizedDay(date)
        if let schedule = daySchedules[key] {
            workStartTime = DayView.makeTime(hour: schedule.startHour, minute: schedule.startMinute)
            workEndTime = DayView.makeTime(hour: schedule.endHour, minute: schedule.endMinute)
        } else {
            workStartTime = DayView.makeTime(hour: 9, minute: 0)
            workEndTime = DayView.makeTime(hour: 18, minute: 0)
        }
    }

    private func normalizedDay(_ input: Date) -> Date {
        Calendar.current.startOfDay(for: input)
    }

    private static func makeTime(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

private struct WeekView: View {
    @Binding var date: Date
    @Binding var daySchedules: [Date: WorkSchedule]
    @State private var selectedPanelDate: Date?
    @State private var workStartTime: Date = WeekView.makeTime(hour: 9, minute: 0)
    @State private var workEndTime: Date = WeekView.makeTime(hour: 18, minute: 0)

    var body: some View {
        let weekDays = weekDaysForSelectedDate

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("周视图")
                    .font(.title2.bold())
                Spacer()
                Button {
                    changeWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                Button {
                    changeWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
            }

            Text(weekTitle)
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.fixed(120), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
                    WeekHeaderCell(title: "日期")
                    WeekHeaderCell(title: "详情")

                    ForEach(weekDays) { day in
                        WeekDateCell(title: day.dateTitle, onTap: { openPanel(for: day.id) })
                        WeekDetailCell(summary: day.summary, onTap: { openPanel(for: day.id) })
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
        }
        .padding(20)
        .sheet(
            isPresented: Binding(
                get: { selectedPanelDate != nil },
                set: { if !$0 { selectedPanelDate = nil } }
            )
        ) {
            if let panelDate = selectedPanelDate {
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
                        WorkScheduleStore.save(daySchedules)
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

    private var weekTitle: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let weekYear = calendar.component(.yearForWeekOfYear, from: date)
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        return "当前 \(weekYear) 年第 \(weekOfYear) 周"
    }

    private var weekDaysForSelectedDate: [WeekDayDetail] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        let weekdayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"

        return (0..<7).compactMap { offset in
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) else {
                return nil
            }
            let key = calendar.startOfDay(for: dayDate)
            let summary = daySchedules[key].map(MonthScheduleSummary.from)
            return WeekDayDetail(id: key, dateTitle: "\(weekdayNames[offset]) \(formatter.string(from: dayDate))", summary: summary)
        }
    }

    private func changeWeek(by value: Int) {
        guard let target = Calendar.current.date(byAdding: .weekOfYear, value: value, to: date) else { return }
        date = target
    }

    private func openPanel(for targetDate: Date) {
        let key = normalizedDay(targetDate)
        if let schedule = daySchedules[key] {
            workStartTime = WeekView.makeTime(hour: schedule.startHour, minute: schedule.startMinute)
            workEndTime = WeekView.makeTime(hour: schedule.endHour, minute: schedule.endMinute)
        } else {
            workStartTime = WeekView.makeTime(hour: 9, minute: 0)
            workEndTime = WeekView.makeTime(hour: 18, minute: 0)
        }
        selectedPanelDate = key
    }

    private func normalizedDay(_ input: Date) -> Date {
        Calendar.current.startOfDay(for: input)
    }

    private static func makeTime(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

private struct MonthView: View {
    let date: Date
    @Binding var daySchedules: [Date: WorkSchedule]
    private let weekDayTitles = ["一", "二", "三", "四", "五", "六", "日"]
    private let cellHeight: CGFloat = 148
    @State private var selectedPanelDate: Date?
    @State private var workStartTime: Date = MonthView.makeTime(hour: 9, minute: 0)
    @State private var workEndTime: Date = MonthView.makeTime(hour: 18, minute: 0)

    private var gridColumns: [GridItem] {
        [GridItem(.fixed(52), spacing: 0)] + Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }

    var body: some View {
        let monthData = buildMonthData(for: date)

        VStack(alignment: .leading, spacing: 12) {
            Text("月视图")
                .font(.title2.bold())
            Text(date.formatted(.dateTime.year().month()))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: gridColumns, spacing: 0) {
                monthHeaderRow
                ForEach(Array(monthData.enumerated()), id: \.offset) { _, week in
                    weekRow(week)
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

    @ViewBuilder
    private var monthHeaderRow: some View {
        MonthHeaderCell(title: "周")
        ForEach(weekDayTitles, id: \.self) { weekday in
            MonthHeaderCell(title: weekday)
        }
    }

    @ViewBuilder
    private func weekRow(_ week: MonthWeek) -> some View {
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
        } else {
            workStartTime = MonthView.makeTime(hour: 9, minute: 0)
            workEndTime = MonthView.makeTime(hour: 18, minute: 0)
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
}

private struct MonthHeaderCell: View {
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

private struct MonthWeekNumberCell: View {
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

private struct MonthDayCell: View {
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

private struct WorkTimeInputPanel: View {
    let targetDate: Date
    @Binding var workStartTime: Date
    @Binding var workEndTime: Date
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var showStartPicker = false
    @State private var showEndPicker = false

    private var dateTitle: String {
        targetDate.formatted(.dateTime.year().month().day().weekday(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置时间")
                .font(.title3.bold())
            Text(dateTitle)
                .foregroundStyle(.secondary)

            TimeInputRow(title: "上班时间", value: $workStartTime, isPresented: $showStartPicker)
            TimeInputRow(title: "下班时间", value: $workEndTime, isPresented: $showEndPicker)

            Spacer()

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                Button("保存", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

private struct TimeInputRow: View {
    let title: String
    @Binding var value: Date
    @Binding var isPresented: Bool
    @State private var selectedHour: Int = 0
    @State private var selectedMinute: Int = 0

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: value)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 72, alignment: .leading)

            Button {
                isPresented.toggle()
            } label: {
                HStack {
                    Text(timeText)
                        .monospacedDigit()
                    Spacer()
                    Image(systemName: "clock")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.35))
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Picker("小时", selection: $selectedHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        .pickerStyle(.menu)

                        Text(":")
                            .font(.title3.monospacedDigit())

                        Picker("分钟", selection: $selectedMinute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        .pickerStyle(.menu)
                    }
                    .frame(height: 44)

                    Button("完成") {
                        applySelectedTimeToBinding()
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(12)
                .frame(width: 200)
                .onAppear {
                    syncStateFromBinding()
                }
                .onChange(of: selectedHour) {
                    applySelectedTimeToBinding()
                }
                .onChange(of: selectedMinute) {
                    applySelectedTimeToBinding()
                }
            }
        }
    }

    private func syncStateFromBinding() {
        let calendar = Calendar.current
        selectedHour = calendar.component(.hour, from: value)
        selectedMinute = calendar.component(.minute, from: value)
    }

    private func applySelectedTimeToBinding() {
        let calendar = Calendar.current
        let dayParts = calendar.dateComponents([.year, .month, .day], from: value)
        var components = DateComponents()
        components.year = dayParts.year
        components.month = dayParts.month
        components.day = dayParts.day
        components.hour = selectedHour
        components.minute = selectedMinute
        if let newDate = calendar.date(from: components) {
            value = newDate
        }
    }
}

private struct YearView: View {
    @Binding var date: Date
    @Binding var mode: ContentView.CalendarMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("年视图")
                .font(.title2.bold())
            Text(date.formatted(.dateTime.year()))
                .foregroundStyle(.secondary)
            Divider()

            let calendar = Calendar(identifier: .gregorian)
            let months = Calendar.current.monthSymbols
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                    Button {
                        let year = calendar.component(.year, from: date)
                        var components = DateComponents()
                        components.year = year
                        components.month = index + 1
                        components.day = 1
                        if let target = calendar.date(from: components) {
                            date = target
                            mode = .month
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.08))
                            .frame(height: 90)
                            .overlay(
                                Text(month)
                                    .font(.headline)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(20)
    }
}

private struct MonthDay: Identifiable {
    let id: Date
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

private struct MonthWeek {
    let weekOfYear: Int
    let days: [MonthDay]
}

private struct WorkSchedule: Codable {
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
}

private struct MonthScheduleSummary {
    let timeRangeText: String
    let workDurationText: String
    let workHoursText: String
    let overtimeText: String
    let effectiveOvertimeText: String

    static func from(schedule: WorkSchedule) -> MonthScheduleSummary {
        let metrics = WorkMetrics.from(schedule: schedule)
        let workHoursText = String(format: "%.2f", Double(metrics.workMinutes) / 60.0)
        let overtimeHoursText = String(format: "%.2f", metrics.overtimeHours)
        let effectiveOvertimeText = String(format: "%.2f", metrics.effectiveOvertimeHours)

        return MonthScheduleSummary(
            timeRangeText: "\(String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)) - \(String(format: "%02d:%02d", schedule.endHour, schedule.endMinute))",
            workDurationText: "工作时间 \(metrics.workMinutes / 60)小时\(metrics.workMinutes % 60)分钟",
            workHoursText: "工作时间 \(workHoursText) 小时",
            overtimeText: "加班\(overtimeHoursText)小时",
            effectiveOvertimeText: "有效加班时长\(effectiveOvertimeText) 小时"
        )
    }
}

private struct WorkMetrics {
    let workMinutes: Int
    let overtimeHours: Double
    let effectiveOvertimeHours: Double

    static func from(schedule: WorkSchedule) -> WorkMetrics {
        let startMinutes = schedule.startHour * 60 + schedule.startMinute
        let endMinutes = schedule.endHour * 60 + schedule.endMinute
        let workMinutes = max(0, endMinutes - startMinutes)
        let overtimeHours = max(0, Double(workMinutes) / 60.0 - 10.0)
        let effectiveOvertimeHours = overtimeHours < 1.0 ? 0.0 : floor(overtimeHours * 2.0) / 2.0
        return WorkMetrics(
            workMinutes: workMinutes,
            overtimeHours: overtimeHours,
            effectiveOvertimeHours: effectiveOvertimeHours
        )
    }
}

private struct WeekSummary {
    let recordedDays: Int
    let workHours: Double
    let overtimeHours: Double
    let effectiveOvertimeHours: Double
}

private struct WeekDayDetail: Identifiable {
    let id: Date
    let dateTitle: String
    let summary: MonthScheduleSummary?
}

private struct WeekHeaderCell: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.08))
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
    }
}

private struct WeekDateCell: View {
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
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

private struct WeekDetailCell: View {
    let summary: MonthScheduleSummary?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                if let summary {
                    Text(summary.timeRangeText)
                    Text(summary.workDurationText)
                    Text(summary.workHoursText)
                    Text(summary.overtimeText)
                    Text(summary.effectiveOvertimeText)
                } else {
                    Text("暂无记录")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
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

private enum WorkScheduleStore {
    private static let fileName = "work-schedules.json"
    private static let calendar = Calendar.current

    static func load() -> [Date: WorkSchedule] {
        let fileURL = storeFileURL()
        guard
            let data = try? Data(contentsOf: fileURL),
            let records = try? JSONDecoder().decode([WorkScheduleRecord].self, from: data)
        else {
            return [:]
        }

        var result: [Date: WorkSchedule] = [:]
        for record in records {
            if let date = fromDayKey(record.day) {
                result[date] = WorkSchedule(
                    startHour: record.startHour,
                    startMinute: record.startMinute,
                    endHour: record.endHour,
                    endMinute: record.endMinute
                )
            }
        }
        return result
    }

    static func save(_ schedules: [Date: WorkSchedule]) {
        let records = schedules.map { date, value in
            WorkScheduleRecord(
                day: dayKey(from: date),
                startHour: value.startHour,
                startMinute: value.startMinute,
                endHour: value.endHour,
                endMinute: value.endMinute
            )
        }
        .sorted { $0.day < $1.day }

        guard let data = try? JSONEncoder().encode(records) else { return }

        let directoryURL = storeDirectoryURL()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: storeFileURL(), options: .atomic)
    }

    private static func storeDirectoryURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("myCalculator", isDirectory: true)
    }

    private static func storeFileURL() -> URL {
        storeDirectoryURL().appendingPathComponent(fileName)
    }

    static func persistedFileURL() -> URL {
        storeFileURL()
    }

    private static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    private static func fromDayKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key).map { calendar.startOfDay(for: $0) }
    }
}

private struct WorkScheduleRecord: Codable {
    let day: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
}

#Preview {
    ContentView()
}
