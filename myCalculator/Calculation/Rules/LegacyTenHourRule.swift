import Foundation

struct LegacyTenHourRule: WorkCalculationRule {
    let id = WorkCalculationRuleID.legacyTenHour
    let title = "10 小时阈值（当前默认）"
    let summary = "超过 10 小时计加班；有效加班 ≥1 小时按 0.5 小时取整"

    func metrics(for context: WorkCalculationContext) -> WorkMetrics {
        let schedule = context.schedule
        guard schedule.isWorkLog else {
            return WorkMetrics(workMinutes: 0, declaredWorkHours: 0, overtimeHours: 0, effectiveOvertimeHours: 0)
        }

        let startMinutes = schedule.startHour * 60 + schedule.startMinute
        let endMinutes = schedule.endHour * 60 + schedule.endMinute
        let workMinutes = max(0, endMinutes - startMinutes)
        let workHours = Double(workMinutes) / 60.0
        let declaredWorkHours: Double
        if workHours < 10.0 {
            declaredWorkHours = max(0.0, workHours - 1.0)
        } else if workHours > 10.0 {
            declaredWorkHours = max(0.0, workHours - 2.0)
        } else {
            declaredWorkHours = workHours
        }
        let overtimeHours = max(0, workHours - 10.0)
        let effectiveOvertimeHours = overtimeHours < 1.0 ? 0.0 : floor(overtimeHours * 2.0) / 2.0
        return WorkMetrics(
            workMinutes: workMinutes,
            declaredWorkHours: declaredWorkHours,
            overtimeHours: overtimeHours,
            effectiveOvertimeHours: effectiveOvertimeHours
        )
    }

    func daySummary(for context: WorkCalculationContext) -> MonthScheduleSummary {
        let schedule = context.schedule
        guard schedule.isWorkLog else {
            return NonWorkLogSummaryBuilder.summary(for: schedule)
        }

        let metrics = metrics(for: context)
        let workHoursText = String(format: "%.2f", Double(metrics.workMinutes) / 60.0)
        let declaredWorkHoursText = String(format: "%.2f", metrics.declaredWorkHours)
        let overtimeHoursText = String(format: "%.2f", metrics.overtimeHours)
        let effectiveOvertimeText = String(format: "%.2f", metrics.effectiveOvertimeHours)
        let timeRangeText = "\(String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)) - \(String(format: "%02d:%02d", schedule.endHour, schedule.endMinute))"
        let workDurationText = "工作时间 \(metrics.workMinutes / 60)小时\(metrics.workMinutes % 60)分钟"
        let workHoursSummaryText = "工作时间 \(workHoursText) 小时"
        let declaredWorkHoursSummaryText = "工时申报 \(declaredWorkHoursText) 小时"
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
