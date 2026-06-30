import SwiftUI

struct WeekView: View {
    @Binding var date: Date
    @Binding var daySchedules: [Date: WorkSchedule]
    @Binding var emphasizesEffectiveOvertime: Bool
    @State private var selectedPanelDate: Date?
    @State private var isEditingTime = false
    @State private var selectedKind: WorkLogKind = .work
    @State private var customNote = ""
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
                        WeekDetailCell(
                            summary: day.summary,
                            emphasizesEffectiveOvertime: emphasizesEffectiveOvertime,
                            onTap: { openPanel(for: day.id) }
                        )
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
            selectedKind = schedule.kind
            customNote = schedule.kind == .custom ? schedule.note : ""
            if schedule.isWorkLog {
                workStartTime = WeekView.makeTime(hour: schedule.startHour, minute: schedule.startMinute)
                workEndTime = WeekView.makeTime(hour: schedule.endHour, minute: schedule.endMinute)
            } else {
                workStartTime = WeekView.makeTime(hour: 9, minute: 0)
                workEndTime = WeekView.makeTime(hour: 18, minute: 0)
            }
            isEditingTime = false
        } else {
            selectedKind = .work
            customNote = ""
            workStartTime = WeekView.makeTime(hour: 9, minute: 0)
            workEndTime = WeekView.makeTime(hour: 18, minute: 0)
            isEditingTime = true
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
