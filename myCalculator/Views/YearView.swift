import SwiftUI

struct YearView: View {
    @Binding var date: Date
    @Binding var mode: ContentView.CalendarMode
    @Binding var daySchedules: [Date: WorkSchedule]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("年视图")
                .font(.title2.bold())
            Text(date.formatted(.dateTime.year()))
                .foregroundStyle(.secondary)
            Divider()

            let calendar = Calendar(identifier: .gregorian)
            let months = Calendar.current.monthSymbols
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                    let effectiveOvertime = monthlyEffectiveOvertime(month: index + 1)
                    Button {
                        let year = calendar.component(.year, from: date)
                        var components = DateComponents()
                        components.year = year
                        components.month = index + 1
                        components.day = 1
                        if let target = calendar.date(from: components) {
                            date = target
                            mode = .month
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.08))
                            .frame(height: 90)
                            .overlay(
                                VStack(spacing: 4) {
                                    Text(month)
                                        .font(.headline)
                                    if effectiveOvertime >= 15.0 {
                                        Text("(\(String(format: "%.2f", effectiveOvertime)))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(20)
    }

    private func monthlyEffectiveOvertime(month: Int) -> Double {
        let calendar = Calendar.current
        let targetYear = calendar.component(.year, from: date)
        return daySchedules.reduce(0.0) { partial, item in
            let day = item.key
            let schedule = item.value
            let year = calendar.component(.year, from: day)
            let currentMonth = calendar.component(.month, from: day)
            guard year == targetYear && currentMonth == month else {
                return partial
            }
            return partial + WorkMetrics.from(schedule: schedule).effectiveOvertimeHours
        }
    }
}
