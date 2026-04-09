import Foundation

enum WorkScheduleStore {
    private static let fileName = "work-schedules.json"
    private static let calendar = Calendar.current

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
                    endMinute: record.endMinute
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
                endMinute: value.endMinute
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

    private static func storeDirectoryURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("myCalculator", isDirectory: true)
    }

    private static func storeFileURL() -> URL {
        storeDirectoryURL().appendingPathComponent(fileName)
    }

    private static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    private static func fromDayKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key).map { calendar.startOfDay(for: $0) }
    }
}
