import Foundation

struct WorkCalculationContext: Sendable {
    let date: Date
    let schedule: WorkSchedule

    init(date: Date, schedule: WorkSchedule) {
        self.date = date
        self.schedule = schedule
    }
}
