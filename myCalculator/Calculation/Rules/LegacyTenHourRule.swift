import Foundation

struct LegacyTenHourRule: WorkCalculationRule {
    let id = WorkCalculationRuleID.legacyTenHour
    let title = "10 小时阈值（当前默认）"
    let summary = "工时申报按正常规则；周末加班计加班工资；周末调休不计加班、记入调休额度"

    func metrics(for context: WorkCalculationContext) -> WorkMetrics {
        let schedule = context.schedule
        guard schedule.isWorkLog else {
            return WorkMetrics(
                workMinutes: 0,
                declaredWorkHours: 0,
                overtimeHours: 0,
                effectiveOvertimeHours: 0,
                compensatoryLeaveHours: 0
            )
        }

        let base = standardWorkdayMetrics(for: schedule)
        switch schedule.kind {
        case .work, .weekendOvertime:
            return WorkMetrics(
                workMinutes: base.workMinutes,
                declaredWorkHours: base.declaredWorkHours,
                overtimeHours: base.overtimeHours,
                effectiveOvertimeHours: base.effectiveOvertimeHours,
                compensatoryLeaveHours: 0
            )
        case .weekendCompensatory:
            return WorkMetrics(
                workMinutes: base.workMinutes,
                declaredWorkHours: base.declaredWorkHours,
                overtimeHours: 0,
                effectiveOvertimeHours: 0,
                compensatoryLeaveHours: base.overtimeHours
            )
        case .off:
            return WorkMetrics(
                workMinutes: 0,
                declaredWorkHours: 0,
                overtimeHours: 0,
                effectiveOvertimeHours: 0,
                compensatoryLeaveHours: 0
            )
        }
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
        let compensatoryLeaveText = String(format: "%.2f", metrics.compensatoryLeaveHours)
        let timeRangeText = "\(String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)) - \(String(format: "%02d:%02d", schedule.endHour, schedule.endMinute))"
        let kindLine = schedule.kind.title
        let workDurationText = "工作时间 \(metrics.workMinutes / 60)小时\(metrics.workMinutes % 60)分钟"
        let workHoursSummaryText = "工作时间 \(workHoursText) 小时"
        let declaredWorkHoursSummaryText = "工时申报 \(declaredWorkHoursText) 小时"
        let overtimeSummaryText = "加班\(overtimeHoursText)小时"
        let effectiveOvertimeSummaryText = "有效加班时长\(effectiveOvertimeText) 小时"
        let compensatoryLeaveSummaryText = "调休额度\(compensatoryLeaveText) 小时"

        var lines = [
            kindLine,
            timeRangeText,
            workDurationText,
            workHoursSummaryText,
            declaredWorkHoursSummaryText,
            overtimeSummaryText,
            effectiveOvertimeSummaryText
        ]
        if schedule.kind == .weekendCompensatory || metrics.compensatoryLeaveHours > 0 {
            lines.append(compensatoryLeaveSummaryText)
        }

        return MonthScheduleSummary(
            timeRangeText: timeRangeText,
            workDurationText: workDurationText,
            workHoursText: workHoursSummaryText,
            declaredWorkHoursText: declaredWorkHoursSummaryText,
            overtimeText: overtimeSummaryText,
            effectiveOvertimeText: effectiveOvertimeSummaryText,
            compensatoryLeaveText: compensatoryLeaveSummaryText,
            lines: lines,
            isWorkLog: true
        )
    }

    /// 与历史「正常工作日」10 小时阈值规则一致。
    private func standardWorkdayMetrics(for schedule: WorkSchedule) -> (
        workMinutes: Int,
        declaredWorkHours: Double,
        overtimeHours: Double,
        effectiveOvertimeHours: Double
    ) {
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
        return (workMinutes, declaredWorkHours, overtimeHours, effectiveOvertimeHours)
    }
}
