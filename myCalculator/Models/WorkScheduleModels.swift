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

enum ScheduleExportScope {
    case allHistory
    case currentMonth

    var title: String {
        switch self {
        case .allHistory:
            return "全部历史"
        case .currentMonth:
            return "仅当月"
        }
    }
}

enum WorkLogKind: String, Codable, CaseIterable, Identifiable {
    case work
    case holiday
    case compensatoryLeave
    case annualLeave
    case sickLeave
    case personalLeave
    case custom

    var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .work:
            return "工作时间"
        case .holiday:
            return "放假"
        case .compensatoryLeave:
            return "调休"
        case .annualLeave:
            return "年假"
        case .sickLeave:
            return "病假"
        case .personalLeave:
            return "事假"
        case .custom:
            return "自定义"
        }
    }
}

struct WorkSchedule: Codable {
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let kind: WorkLogKind
    let note: String

    nonisolated var isWorkLog: Bool {
        kind == .work
    }

    nonisolated var displayText: String {
        if kind == .custom {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? kind.title : trimmed
        }
        return kind.title
    }

    init(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        kind: WorkLogKind = .work,
        note: String = ""
    ) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.kind = kind
        self.note = note
    }

    init(kind: WorkLogKind, note: String = "") {
        self.init(startHour: 0, startMinute: 0, endHour: 0, endMinute: 0, kind: kind, note: note)
    }

    enum CodingKeys: String, CodingKey {
        case startHour
        case startMinute
        case endHour
        case endMinute
        case kind
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startHour = try container.decodeIfPresent(Int.self, forKey: .startHour) ?? 0
        startMinute = try container.decodeIfPresent(Int.self, forKey: .startMinute) ?? 0
        endHour = try container.decodeIfPresent(Int.self, forKey: .endHour) ?? 0
        endMinute = try container.decodeIfPresent(Int.self, forKey: .endMinute) ?? 0
        kind = try container.decodeIfPresent(WorkLogKind.self, forKey: .kind) ?? .work
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct MonthScheduleSummary {
    let timeRangeText: String
    let workDurationText: String
    let workHoursText: String
    let declaredWorkHoursText: String
    let overtimeText: String
    let effectiveOvertimeText: String
    let lines: [String]
    let isWorkLog: Bool

    nonisolated static func from(schedule: WorkSchedule) -> MonthScheduleSummary {
        guard schedule.isWorkLog else {
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

        let metrics = WorkMetrics.from(schedule: schedule)
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

struct WorkMetrics {
    let workMinutes: Int
    let declaredWorkHours: Double
    let overtimeHours: Double
    let effectiveOvertimeHours: Double

    nonisolated static func from(schedule: WorkSchedule) -> WorkMetrics {
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
    let kind: WorkLogKind?
    let note: String?
}
