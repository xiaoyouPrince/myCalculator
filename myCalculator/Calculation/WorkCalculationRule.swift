import Foundation

protocol WorkCalculationRule: Sendable {
    var id: String { get }
    var title: String { get }
    var summary: String { get }

    func metrics(for context: WorkCalculationContext) -> WorkMetrics
    func daySummary(for context: WorkCalculationContext) -> MonthScheduleSummary
}

enum NonWorkLogSummaryBuilder {
    nonisolated static func summary(for schedule: WorkSchedule) -> MonthScheduleSummary {
        let text = schedule.displayText
        return MonthScheduleSummary(
            timeRangeText: text,
            workDurationText: "",
            workHoursText: "",
            declaredWorkHoursText: "",
            overtimeText: "",
            effectiveOvertimeText: "",
            lines: [text],
            isWorkLog: false
        )
    }
}

enum WorkCalculationRuleID {
    static let legacyTenHour = "legacy-ten-hour"
    static let `default` = legacyTenHour
}
