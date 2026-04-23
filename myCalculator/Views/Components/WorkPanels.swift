import SwiftUI

struct WorkTimeInputPanel: View {
    let targetDate: Date
    @Binding var workStartTime: Date
    @Binding var workEndTime: Date
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var showStartPicker = false
    @State private var showEndPicker = false

    private var dateTitle: String {
        targetDate.formatted(.dateTime.year().month().day().weekday(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置时间")
                .font(.title3.bold())
            Text(dateTitle)
                .foregroundStyle(.secondary)

            TimeInputRow(title: "上班时间", value: $workStartTime, isPresented: $showStartPicker)
            TimeInputRow(title: "下班时间", value: $workEndTime, isPresented: $showEndPicker)

            Spacer()

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                Button("保存", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

struct WorkDetailPanel: View {
    let targetDate: Date
    let summary: MonthScheduleSummary
    let onEdit: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("当日详情")
                .font(.title3.bold())
            Text(targetDate.formatted(.dateTime.year().month().day().weekday(.abbreviated)))
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.timeRangeText)
                Text(summary.workDurationText)
                Text(summary.workHoursText)
                Text(summary.declaredWorkHoursText)
                Text(summary.overtimeText)
                Text(summary.effectiveOvertimeText)
            }
            .font(.body)

            Spacer()

            HStack {
                Button("关闭", action: onClose)
                Spacer()
                Button("编辑", action: onEdit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }
}

struct TimeInputRow: View {
    let title: String
    @Binding var value: Date
    @Binding var isPresented: Bool
    @State private var selectedHour: Int = 0
    @State private var selectedMinute: Int = 0

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: value)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 72, alignment: .leading)

            Button {
                isPresented.toggle()
            } label: {
                HStack {
                    Text(timeText)
                        .monospacedDigit()
                    Spacer()
                    Image(systemName: "clock")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.35))
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Picker("小时", selection: $selectedHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        .pickerStyle(.menu)

                        Text(":")
                            .font(.title3.monospacedDigit())

                        Picker("分钟", selection: $selectedMinute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        .pickerStyle(.menu)
                    }
                    .frame(height: 44)

                    Button("完成") {
                        applySelectedTimeToBinding()
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(12)
                .frame(width: 200)
                .onAppear {
                    syncStateFromBinding()
                }
                .onChange(of: selectedHour) {
                    applySelectedTimeToBinding()
                }
                .onChange(of: selectedMinute) {
                    applySelectedTimeToBinding()
                }
            }
        }
    }

    private func syncStateFromBinding() {
        let calendar = Calendar.current
        selectedHour = calendar.component(.hour, from: value)
        selectedMinute = calendar.component(.minute, from: value)
    }

    private func applySelectedTimeToBinding() {
        let calendar = Calendar.current
        let dayParts = calendar.dateComponents([.year, .month, .day], from: value)
        var components = DateComponents()
        components.year = dayParts.year
        components.month = dayParts.month
        components.day = dayParts.day
        components.hour = selectedHour
        components.minute = selectedMinute
        if let newDate = calendar.date(from: components) {
            value = newDate
        }
    }
}
