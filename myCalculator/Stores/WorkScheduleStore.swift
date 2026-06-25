import Foundation

enum WorkScheduleStore {
    private static let fileName = "work-schedules.json"

    static func load() -> [Date: WorkSchedule] {
        let fileURL = storeFileURL()
        guard
            let data = try? Data(contentsOf: fileURL),
            let records = try? JSONDecoder().decode([WorkScheduleRecord].self, from: data)
        else {
            return [:]
        }

        var result: [Date: WorkSchedule] = [:]
        for record in records {
            if let date = fromDayKey(record.day) {
                result[date] = WorkSchedule(
                    startHour: record.startHour,
                    startMinute: record.startMinute,
                    endHour: record.endHour,
                    endMinute: record.endMinute,
                    kind: record.kind ?? .work,
                    note: record.note ?? ""
                )
            }
        }
        return result
    }

    static func save(_ schedules: [Date: WorkSchedule]) {
        let records = schedules.map { date, value in
            WorkScheduleRecord(
                day: dayKey(from: date),
                startHour: value.startHour,
                startMinute: value.startMinute,
                endHour: value.endHour,
                endMinute: value.endMinute,
                kind: value.kind,
                note: value.note
            )
        }
        .sorted { $0.day < $1.day }

        guard let data = try? JSONEncoder().encode(records) else { return }

        let directoryURL = storeDirectoryURL()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: storeFileURL(), options: .atomic)
    }

    static func persistedFileURL() -> URL {
        storeFileURL()
    }

    nonisolated static func exportCSV(from schedules: [Date: WorkSchedule]) -> String {
        let header = [
            "日期",
            "类型",
            "内容",
            "上班时间",
            "下班时间",
            "工作时长",
            "工作小时",
            "工时申报",
            "加班时长",
            "有效加班"
        ]

        let rows = schedules
            .sorted { $0.key < $1.key }
            .map { date, schedule in
                csvRow(for: date, schedule: schedule)
            }

        return ([header.map(csvField).joined(separator: ",")] + rows).joined(separator: "\n") + "\n"
    }

    nonisolated static func exportMinimalJSON(from schedules: [Date: WorkSchedule]) -> String {
        let records = schedules
            .filter { _, schedule in schedule.isWorkLog }
            .sorted { $0.key < $1.key }
            .map { date, schedule in
                MinimalWorkScheduleRecord(
                    day: dayKey(from: date),
                    startTime: timeText(hour: schedule.startHour, minute: schedule.startMinute),
                    endTime: timeText(hour: schedule.endHour, minute: schedule.endMinute)
                )
            }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records),
              let text = String(data: data, encoding: .utf8)
        else {
            return "[]\n"
        }
        return text + "\n"
    }

    private static func storeDirectoryURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("myCalculator", isDirectory: true)
    }

    private static func storeFileURL() -> URL {
        storeDirectoryURL().appendingPathComponent(fileName)
    }

    nonisolated private static func dayKey(from date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    private static func fromDayKey(_ key: String) -> Date? {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key).map { calendar.startOfDay(for: $0) }
    }

    nonisolated private static func csvRow(for date: Date, schedule: WorkSchedule) -> String {
        let day = dayKey(from: date)

        if schedule.isWorkLog {
            let metrics = WorkMetrics.from(schedule: schedule)
            let values = [
                day,
                schedule.kind.title,
                schedule.displayText,
                timeText(hour: schedule.startHour, minute: schedule.startMinute),
                timeText(hour: schedule.endHour, minute: schedule.endMinute),
                "\(metrics.workMinutes / 60)小时\(metrics.workMinutes % 60)分钟",
                String(format: "%.2f", Double(metrics.workMinutes) / 60.0),
                String(format: "%.2f", metrics.declaredWorkHours),
                String(format: "%.2f", metrics.overtimeHours),
                String(format: "%.2f", metrics.effectiveOvertimeHours)
            ]
            return values.map(csvField).joined(separator: ",")
        }

        let values = [
            day,
            schedule.kind.title,
            schedule.displayText,
            "",
            "",
            "",
            "",
            "",
            "",
            ""
        ]
        return values.map(csvField).joined(separator: ",")
    }

    nonisolated private static func timeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    nonisolated private static func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

private struct MinimalWorkScheduleRecord: Encodable {
    let day: String
    let startTime: String
    let endTime: String
}
