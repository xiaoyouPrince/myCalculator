import Foundation

struct LegacyTenHourRule: WorkCalculationRule {
    let id = WorkCalculationRuleID.legacyTenHour
    let title = "10 小时阈值（当前默认）"
    let summary = "正常上班/补班按工作日规则；休息日加班工资=出勤扣饭后全计加班；换调休覆盖午休扣 1h"

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
        case .work, .makeupWork:
            // 正常上班、补班：申报按午饭/晚饭扣减；加班为超 10 小时部分
            return WorkMetrics(
                workMinutes: base.workMinutes,
                declaredWorkHours: base.declaredWorkHours,
                overtimeHours: base.overtimeHours,
                effectiveOvertimeHours: base.effectiveOvertimeHours,
                compensatoryLeaveHours: 0
            )
        case .weekendOvertime:
            // 休息日主动加班（加班工资）：全部出勤都是加班时间，再扣午饭/晚饭
            // <10h 扣午饭 1h；>10h 扣午饭+晚饭 2h；=10h 不扣（与申报扣减档位一致）
            let restDayOvertime = restDayOvertimePayHours(workHours: Double(base.workMinutes) / 60.0)
            let effective = restDayOvertime < 1.0 ? 0.0 : floor(restDayOvertime * 2.0) / 2.0
            return WorkMetrics(
                workMinutes: base.workMinutes,
                declaredWorkHours: base.declaredWorkHours,
                overtimeHours: restDayOvertime,
                effectiveOvertimeHours: effective,
                compensatoryLeaveHours: 0
            )
        case .weekendCompensatory:
            // 换调休：申报仍按正常规则；不计加班工资
            // 调休额度：出勤小时；若时间段覆盖 12:00–13:00 则再减 1 小时
            return WorkMetrics(
                workMinutes: base.workMinutes,
                declaredWorkHours: base.declaredWorkHours,
                overtimeHours: 0,
                effectiveOvertimeHours: 0,
                compensatoryLeaveHours: compensatoryLeaveHours(for: schedule, workMinutes: base.workMinutes)
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

    /// 正常工作日规则：工时申报按午饭/晚饭扣减；加班为超出 10 小时部分。
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

    /// 休息日加班工资：出勤全计加班，再按时长档位扣午饭/晚饭。
    private func restDayOvertimePayHours(workHours: Double) -> Double {
        if workHours < 10.0 {
            return max(0.0, workHours - 1.0)
        }
        if workHours > 10.0 {
            return max(0.0, workHours - 2.0)
        }
        return workHours
    }

    /// 换调休额度：覆盖 12:00–13:00 整段午休则扣 1 小时。
    private func compensatoryLeaveHours(for schedule: WorkSchedule, workMinutes: Int) -> Double {
        let workHours = Double(workMinutes) / 60.0
        let startMinutes = schedule.startHour * 60 + schedule.startMinute
        let endMinutes = schedule.endHour * 60 + schedule.endMinute
        let noonStart = 12 * 60
        let noonEnd = 13 * 60
        let coversNoonBreak = startMinutes <= noonStart && endMinutes >= noonEnd
        return max(0.0, coversNoonBreak ? workHours - 1.0 : workHours)
    }
}
