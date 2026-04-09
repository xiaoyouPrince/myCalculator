import SwiftUI

struct CalendarContentView: View {
    @Binding var mode: ContentView.CalendarMode
    @Binding var date: Date
    @Binding var daySchedules: [Date: WorkSchedule]

    var body: some View {
        switch mode {
        case .day:
            DayView(date: $date, daySchedules: $daySchedules)
        case .week:
            WeekView(date: $date, daySchedules: $daySchedules)
        case .month:
            MonthView(date: $date, daySchedules: $daySchedules)
        case .year:
            YearView(date: $date, mode: $mode)
        }
    }
}
