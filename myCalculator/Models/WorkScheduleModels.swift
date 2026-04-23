import Foundation

struct MonthDay: Identifiable {
    let id: Date
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

struct MonthWeek {
    let weekOfYear: Int
    let days: [MonthDay]
}

struct WorkSchedule: Codable {
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
}

struct MonthScheduleSummary {
    let timeRangeText: String
    let workDurationText: String
    let workHoursText: String
    let declaredWorkHoursText: String
    let overtimeText: String
    let effectiveOvertimeText: String

    static func from(schedule: WorkSchedule) -> MonthScheduleSummary {
        let metrics = WorkMetrics.from(schedule: schedule)
        let workHoursText = String(format: "%.2f", Double(metrics.workMinutes) / 60.0)
        let declaredWorkHoursText = String(format: "%.2f", metrics.declaredWorkHours)
        let overtimeHoursText = String(format: "%.2f", metrics.overtimeHours)
        let effectiveOvertimeText = String(format: "%.2f", metrics.effectiveOvertimeHours)

        return MonthScheduleSummary(
            timeRangeText: "\(String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)) - \(String(format: "%02d:%02d", schedule.endHour, schedule.endMinute))",
            workDurationText: "工作时间 \(metrics.workMinutes / 60)小时\(metrics.workMinutes % 60)分钟",
            workHoursText: "工作时间 \(workHoursText) 小时",
            declaredWorkHoursText: "工时申报 \(declaredWorkHoursText) 小时",
            overtimeText: "加班\(overtimeHoursText)小时",
            effectiveOvertimeText: "有效加班时长\(effectiveOvertimeText) 小时"
        )
    }
}

struct WorkMetrics {
    let workMinutes: Int
    let declaredWorkHours: Double
    let overtimeHours: Double
    let effectiveOvertimeHours: Double

    static func from(schedule: WorkSchedule) -> WorkMetrics {
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
        let overtimeHours = max(0, Double(workMinutes) / 60.0 - 10.0)
        let effectiveOvertimeHours = overtimeHours < 1.0 ? 0.0 : floor(overtimeHours * 2.0) / 2.0
        return WorkMetrics(
            workMinutes: workMinutes,
            declaredWorkHours: declaredWorkHours,
            overtimeHours: overtimeHours,
            effectiveOvertimeHours: effectiveOvertimeHours
        )
    }
}

struct WeekSummary {
    let recordedDays: Int
    let workHours: Double
    let declaredWorkHours: Double
    let overtimeHours: Double
    let effectiveOvertimeHours: Double
}

struct WeekDayDetail: Identifiable {
    let id: Date
    let dateTitle: String
    let summary: MonthScheduleSummary?
}

struct WorkScheduleRecord: Codable {
    let day: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
}
