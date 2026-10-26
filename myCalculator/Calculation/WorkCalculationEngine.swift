import Foundation

enum WorkCalculationEngine {
    nonisolated static func context(date: Date, schedule: WorkSchedule) -> WorkCalculationContext {
        WorkCalculationContext(date: date, schedule: schedule)
    }

    nonisolated static func metrics(context: WorkCalculationContext, ruleID: String) -> WorkMetrics {
        WorkCalculationRegistry.rule(id: ruleID).metrics(for: context)
    }

    nonisolated static func metrics(date: Date, schedule: WorkSchedule, ruleID: String) -> WorkMetrics {
        metrics(context: context(date: date, schedule: schedule), ruleID: ruleID)
    }

    nonisolated static func daySummary(date: Date, schedule: WorkSchedule, ruleID: String) -> MonthScheduleSummary {
        WorkCalculationRegistry.rule(id: ruleID).daySummary(for: context(date: date, schedule: schedule))
    }

    nonisolated static func aggregateSummary(
        entries: [(date: Date, schedule: WorkSchedule)],
        ruleID: String
    ) -> WeekSummary {
        var totalWorkMinutes = 0
        var totalDeclaredWorkHours = 0.0
        var totalOvertimeHours = 0.0
        var totalEffectiveOvertimeHours = 0.0
        var totalCompensatoryLeaveHours = 0.0

        for entry in entries {
            let metrics = metrics(date: entry.date, schedule: entry.schedule, ruleID: ruleID)
            totalWorkMinutes += metrics.workMinutes
            totalDeclaredWorkHours += metrics.declaredWorkHours
            totalOvertimeHours += metrics.overtimeHours
            totalEffectiveOvertimeHours += metrics.effectiveOvertimeHours
            totalCompensatoryLeaveHours += metrics.compensatoryLeaveHours
        }

        return WeekSummary(
            recordedDays: entries.count,
            workHours: Double(totalWorkMinutes) / 60.0,
            declaredWorkHours: totalDeclaredWorkHours,
            overtimeHours: totalOvertimeHours,
            effectiveOvertimeHours: totalEffectiveOvertimeHours,
            compensatoryLeaveHours: totalCompensatoryLeaveHours
        )
    }

    nonisolated static func monthEffectiveOvertime(
        schedules: [Date: WorkSchedule],
        year: Int,
        month: Int,
        ruleID: String
    ) -> Double {
        let calendar = Calendar.current
        return schedules.reduce(0.0) { partial, item in
            let day = item.key
            let schedule = item.value
            let dayYear = calendar.component(.year, from: day)
            let dayMonth = calendar.component(.month, from: day)
            guard dayYear == year && dayMonth == month else {
                return partial
            }
            return partial + metrics(date: day, schedule: schedule, ruleID: ruleID).effectiveOvertimeHours
        }
    }
}
