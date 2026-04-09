import SwiftUI

struct YearView: View {
    @Binding var date: Date
    @Binding var mode: ContentView.CalendarMode

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
                                Text(month)
                                    .font(.headline)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(20)
    }
}
