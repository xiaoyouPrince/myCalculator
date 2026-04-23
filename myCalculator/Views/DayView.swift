import SwiftUI

struct DayView: View {
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
                    Text(summary.declaredWorkHoursText)
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
