import Foundation

/// 按 `dayRole` 区分工作日与休息日加班。
/// - 工作日 / 调休补班：沿用 `LegacyTenHourRule`
/// - 周末 / 法定放假：出勤全部计加班，工时申报为 0；有效加班仍用 ≥1 小时门槛与 0.5 取整
struct RestDayOvertimeRule: WorkCalculationRule {
    let id = WorkCalculationRuleID.restDayOvertime
    let title = "休息日加班（按日历角色）"
    let summary = "周末/法定假出勤全计加班；工作日与调休补班沿用 10 小时阈值"

    private let workdayRule = LegacyTenHourRule()

    func metrics(for context: WorkCalculationContext) -> WorkMetrics {
        let schedule = context.schedule
        guard schedule.isWorkLog else {
            return WorkMetrics(workMinutes: 0, declaredWorkHours: 0, overtimeHours: 0, effectiveOvertimeHours: 0)
        }

        if schedule.dayRole.treatsAttendanceAsRestDayOvertime {
            return restDayMetrics(for: schedule)
        }
        return workdayRule.metrics(for: context)
    }

    func daySummary(for context: WorkCalculationContext) -> MonthScheduleSummary {
        let schedule = context.schedule
        guard schedule.isWorkLog else {
            return NonWorkLogSummaryBuilder.summary(for: schedule)
        }

        if schedule.dayRole.treatsAttendanceAsRestDayOvertime {
            return restDaySummary(for: context)
        }
        return workdayRule.daySummary(for: context)
    }

    private func restDayMetrics(for schedule: WorkSchedule) -> WorkMetrics {
        let startMinutes = schedule.startHour * 60 + schedule.startMinute
        let endMinutes = schedule.endHour * 60 + schedule.endMinute
        let workMinutes = max(0, endMinutes - startMinutes)
        let workHours = Double(workMinutes) / 60.0
        let overtimeHours = workHours
        let effectiveOvertimeHours = overtimeHours < 1.0 ? 0.0 : floor(overtimeHours * 2.0) / 2.0
        return WorkMetrics(
            workMinutes: workMinutes,
            declaredWorkHours: 0,
            overtimeHours: overtimeHours,
            effectiveOvertimeHours: effectiveOvertimeHours
        )
    }

    private func restDaySummary(for context: WorkCalculationContext) -> MonthScheduleSummary {
        let schedule = context.schedule
        let metrics = restDayMetrics(for: schedule)
        let workHoursText = String(format: "%.2f", Double(metrics.workMinutes) / 60.0)
        let overtimeHoursText = String(format: "%.2f", metrics.overtimeHours)
        let effectiveOvertimeText = String(format: "%.2f", metrics.effectiveOvertimeHours)
        let timeRangeText = "\(String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)) - \(String(format: "%02d:%02d", schedule.endHour, schedule.endMinute))"
        let roleHint = "休息日加班（\(schedule.dayRole.title)）"
        let workDurationText = "出勤 \(metrics.workMinutes / 60)小时\(metrics.workMinutes % 60)分钟"
        let workHoursSummaryText = "出勤 \(workHoursText) 小时"
        let declaredWorkHoursSummaryText = "工时申报 0.00 小时"
        let overtimeSummaryText = "加班\(overtimeHoursText)小时"
        let effectiveOvertimeSummaryText = "有效加班时长\(effectiveOvertimeText) 小时"

        return MonthScheduleSummary(
            timeRangeText: timeRangeText,
            workDurationText: workDurationText,
            workHoursText: workHoursSummaryText,
            declaredWorkHoursText: declaredWorkHoursSummaryText,
            overtimeText: overtimeSummaryText,
            effectiveOvertimeText: effectiveOvertimeSummaryText,
            lines: [
                roleHint,
                timeRangeText,
                workDurationText,
                workHoursSummaryText,
                declaredWorkHoursSummaryText,
                overtimeSummaryText,
                effectiveOvertimeSummaryText
            ],
            isWorkLog: true
        )
    }
}
