import SwiftUI

struct WeekHeaderCell: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.08))
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
    }
}

struct WeekDateCell: View {
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct WeekDetailCell: View {
    let summary: MonthScheduleSummary?
    let emphasizesEffectiveOvertime: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                if let summary {
                    ForEach(summary.lines, id: \.self) { line in
                        WorkSummaryLineText(
                            line: line,
                            emphasizesEffectiveOvertime: emphasizesEffectiveOvertime
                        )
                    }
                } else {
                    Text("暂无记录")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
