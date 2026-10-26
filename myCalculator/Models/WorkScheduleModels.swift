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

/// 简洁出勤类型。
/// - 工作日常用：正常上班 / 不上班
/// - 休息日常用：补班 / 加班 / 换调休 / 不上班
enum WorkLogKind: String, Codable, CaseIterable, Identifiable {
    case work
    case makeupWork
    case weekendOvertime
    case weekendCompensatory
    case off

    var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .work:
            return "正常上班"
        case .makeupWork:
            return "补班"
        case .weekendOvertime:
            return "加班"
        case .weekendCompensatory:
            return "换调休"
        case .off:
            return "不上班"
        }
    }

    nonisolated var shortTitle: String {
        switch self {
        case .work:
            return "班"
        case .makeupWork:
            return "班"
        case .weekendOvertime:
            return "加"
        case .weekendCompensatory:
            return "调"
        case .off:
            return "休"
        }
    }

    nonisolated var isWorkLog: Bool {
        self != .off
    }

    /// 按日历日给出录入选项（周六日默认当休息日）。
    nonisolated static func pickerCases(for date: Date, calendar: Calendar = .current) -> [WorkLogKind] {
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        if isWeekend {
            return [.makeupWork, .weekendOvertime, .weekendCompensatory, .off]
        }
        return [.work, .off]
    }

    nonisolated static func defaultKind(for date: Date, calendar: Calendar = .current) -> WorkLogKind {
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        return isWeekend ? .off : .work
    }

    /// 兼容旧 JSON：请假类 → 不上班；未知 → 正常上班。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case Self.work.rawValue:
            self = .work
        case Self.makeupWork.rawValue:
            self = .makeupWork
        case Self.weekendOvertime.rawValue:
            self = .weekendOvertime
        case Self.weekendCompensatory.rawValue:
            self = .weekendCompensatory
        case Self.off.rawValue:
            self = .off
        case "holiday", "compensatoryLeave", "annualLeave", "sickLeave", "personalLeave", "custom":
            self = .off
        default:
            self = .work
        }
    }

    /// 从旧 `dayRole` + kind 迁移到新 kind。
    nonisolated static func migrated(fromLegacyKind kind: WorkLogKind?, legacyDayRoleRaw: String?) -> WorkLogKind {
        let base = kind ?? .work
        guard base == .work, let legacyDayRoleRaw else {
            return base
        }
        switch legacyDayRoleRaw {
        case "makeupWorkday":
            return .makeupWork
        case "weekend", "publicHoliday":
            return .weekendOvertime
        default:
            return .work
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
        kind.isWorkLog
    }

    nonisolated var displayText: String {
        kind.title
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
        case dayRole
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startHour = try container.decodeIfPresent(Int.self, forKey: .startHour) ?? 0
        startMinute = try container.decodeIfPresent(Int.self, forKey: .startMinute) ?? 0
        endHour = try container.decodeIfPresent(Int.self, forKey: .endHour) ?? 0
        endMinute = try container.decodeIfPresent(Int.self, forKey: .endMinute) ?? 0
        let decodedKind = try container.decodeIfPresent(WorkLogKind.self, forKey: .kind)
        let legacyDayRole = try container.decodeIfPresent(String.self, forKey: .dayRole)
        kind = WorkLogKind.migrated(fromLegacyKind: decodedKind, legacyDayRoleRaw: legacyDayRole)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startHour, forKey: .startHour)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(endHour, forKey: .endHour)
        try container.encode(endMinute, forKey: .endMinute)
        try container.encode(kind, forKey: .kind)
        try container.encode(note, forKey: .note)
    }
}

struct MonthScheduleSummary {
    let timeRangeText: String
    let workDurationText: String
    let workHoursText: String
    let declaredWorkHoursText: String
    let overtimeText: String
    let effectiveOvertimeText: String
    let compensatoryLeaveText: String
    let lines: [String]
    let isWorkLog: Bool

    @available(*, deprecated, message: "Use WorkCalculationEngine.daySummary(date:schedule:ruleID:) instead.")
    nonisolated static func from(schedule: WorkSchedule) -> MonthScheduleSummary {
        WorkCalculationEngine.daySummary(
            date: .distantPast,
            schedule: schedule,
            ruleID: WorkCalculationRegistry.defaultRuleID
        )
    }
}

struct WorkMetrics {
    let workMinutes: Int
    let declaredWorkHours: Double
    let overtimeHours: Double
    let effectiveOvertimeHours: Double
    /// 周末调休计入的调休额度（小时）；其它类型为 0。
    let compensatoryLeaveHours: Double

    @available(*, deprecated, message: "Use WorkCalculationEngine.metrics(date:schedule:ruleID:) instead.")
    nonisolated static func from(schedule: WorkSchedule) -> WorkMetrics {
        WorkCalculationEngine.metrics(
            date: .distantPast,
            schedule: schedule,
            ruleID: WorkCalculationRegistry.defaultRuleID
        )
    }
}

struct WeekSummary {
    let recordedDays: Int
    let workHours: Double
    let declaredWorkHours: Double
    let overtimeHours: Double
    let effectiveOvertimeHours: Double
    let compensatoryLeaveHours: Double
}

struct WeekDayDetail: Identifiable {
    let id: Date
    let dateTitle: String
    let summary: MonthScheduleSummary?
}

struct WorkScheduleRecord: Codable {
    let day: String
    let startTime: String
    let endTime: String
    let kind: WorkLogKind?
    let note: String?
    /// 仅用于读取旧数据迁移，不再写出。
    let legacyDayRoleRaw: String?

    var startHour: Int {
        WorkScheduleRecord.timeParts(from: startTime).hour
    }

    var startMinute: Int {
        WorkScheduleRecord.timeParts(from: startTime).minute
    }

    var endHour: Int {
        WorkScheduleRecord.timeParts(from: endTime).hour
    }

    var endMinute: Int {
        WorkScheduleRecord.timeParts(from: endTime).minute
    }

    init(
        day: String,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        kind: WorkLogKind?,
        note: String?
    ) {
        self.day = day
        self.startTime = WorkScheduleRecord.timeText(hour: startHour, minute: startMinute)
        self.endTime = WorkScheduleRecord.timeText(hour: endHour, minute: endMinute)
        self.kind = kind
        self.note = note
        self.legacyDayRoleRaw = nil
    }

    init(day: String, startTime: String, endTime: String, kind: WorkLogKind?, note: String?) {
        self.day = day
        self.startTime = startTime
        self.endTime = endTime
        self.kind = kind
        self.note = note
        self.legacyDayRoleRaw = nil
    }

    enum CodingKeys: String, CodingKey {
        case day
        case startTime
        case endTime
        case startHour
        case startMinute
        case endHour
        case endMinute
        case dayRole
        case kind
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(String.self, forKey: .day)
        legacyDayRoleRaw = try container.decodeIfPresent(String.self, forKey: .dayRole)
        kind = try container.decodeIfPresent(WorkLogKind.self, forKey: .kind)
        note = try container.decodeIfPresent(String.self, forKey: .note)

        let decodedStartTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        let decodedEndTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        if let decodedStartTime, let decodedEndTime {
            startTime = decodedStartTime
            endTime = decodedEndTime
        } else {
            let legacyStartHour = try container.decodeIfPresent(Int.self, forKey: .startHour) ?? 0
            let legacyStartMinute = try container.decodeIfPresent(Int.self, forKey: .startMinute) ?? 0
            let legacyEndHour = try container.decodeIfPresent(Int.self, forKey: .endHour) ?? 0
            let legacyEndMinute = try container.decodeIfPresent(Int.self, forKey: .endMinute) ?? 0
            startTime = WorkScheduleRecord.timeText(hour: legacyStartHour, minute: legacyStartMinute)
            endTime = WorkScheduleRecord.timeText(hour: legacyEndHour, minute: legacyEndMinute)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(note, forKey: .note)
    }

    private static func timeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private static func timeParts(from text: String) -> (hour: Int, minute: Int) {
        let parts = text.split(separator: ":", maxSplits: 1).compactMap { Int($0) }
        guard parts.count == 2 else { return (0, 0) }
        return (parts[0], parts[1])
    }
}
