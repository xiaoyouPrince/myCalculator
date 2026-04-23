import SwiftUI

struct SidebarView: View {
    @Binding var selectedDate: Date
    @Binding var daySchedules: [Date: WorkSchedule]
    let onOpenJSONFile: () -> Void
    private let bottomOverlayHeight: CGFloat = 72

    var body: some View {
        GeometryReader { proxy in
            let useCompactDatePicker = proxy.size.height < 760

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        datePickerSection(useCompact: useCompactDatePicker)

                        Text("当日")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 10) {
                            if let summary = selectedDaySummary {
                                Text(summary.timeRangeText)
                                Text(summary.workDurationText)
                                Text(summary.workHoursText)
                                Text(summary.declaredWorkHoursText)
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
                                Text("周工时申报 \(String(format: "%.2f", summary.declaredWorkHours)) 小时")
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
                                Text("月工时申报 \(String(format: "%.2f", summary.declaredWorkHours)) 小时")
                                Text("月加班时长 \(String(format: "%.2f", summary.overtimeHours)) 小时")
                                Text("月有效加班 \(String(format: "%.2f", summary.effectiveOvertimeHours)) 小时")
                            } else {
                                Text("当月暂无记录")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)

                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .padding(.bottom, bottomOverlayHeight + 8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                VStack(spacing: 0) {
                    Divider()
                    Rectangle()
                        .fill(.clear)
                        .frame(height: bottomOverlayHeight - 1)
                        .overlay {
                            Button(action: onOpenJSONFile) {
                                Label("查看 JSON", systemImage: "doc.text.magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(nsColor: .controlAccentColor))
                            .padding(.horizontal, 16)
                        }
                }
                .frame(maxWidth: .infinity)
                .zIndex(10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
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

    @ViewBuilder
    private func datePickerSection(useCompact: Bool) -> some View {
        if useCompact {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择日期")
                    .font(.headline)
                DatePicker("",
                           selection: $selectedDate,
                           displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.75))
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择日期")
                    .font(.headline)
                DatePicker("",
                           selection: $selectedDate,
                           displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .frame(maxHeight: 320)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.75))
            )
        }
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

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
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
        var totalDeclaredWorkHours = 0.0
        var totalOvertimeHours = 0.0
        var totalEffectiveOvertimeHours = 0.0

        for (_, schedule) in schedulesInWeek {
            let metrics = WorkMetrics.from(schedule: schedule)
            totalWorkMinutes += metrics.workMinutes
            totalDeclaredWorkHours += metrics.declaredWorkHours
            totalOvertimeHours += metrics.overtimeHours
            totalEffectiveOvertimeHours += metrics.effectiveOvertimeHours
        }

        return WeekSummary(
            recordedDays: schedulesInWeek.count,
            workHours: Double(totalWorkMinutes) / 60.0,
            declaredWorkHours: totalDeclaredWorkHours,
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
        var totalDeclaredWorkHours = 0.0
        var totalOvertimeHours = 0.0
        var totalEffectiveOvertimeHours = 0.0

        for (_, schedule) in schedulesInMonth {
            let metrics = WorkMetrics.from(schedule: schedule)
            totalWorkMinutes += metrics.workMinutes
            totalDeclaredWorkHours += metrics.declaredWorkHours
            totalOvertimeHours += metrics.overtimeHours
            totalEffectiveOvertimeHours += metrics.effectiveOvertimeHours
        }

        return WeekSummary(
            recordedDays: schedulesInMonth.count,
            workHours: Double(totalWorkMinutes) / 60.0,
            declaredWorkHours: totalDeclaredWorkHours,
            overtimeHours: totalOvertimeHours,
            effectiveOvertimeHours: totalEffectiveOvertimeHours
        )
    }
}
