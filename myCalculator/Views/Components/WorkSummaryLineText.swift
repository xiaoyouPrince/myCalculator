import SwiftUI

struct WorkSummaryLineText: View {
    let line: String
    let emphasizesEffectiveOvertime: Bool
    let defaultColor: Color?

    init(line: String, emphasizesEffectiveOvertime: Bool, defaultColor: Color? = nil) {
        self.line = line
        self.emphasizesEffectiveOvertime = emphasizesEffectiveOvertime
        self.defaultColor = defaultColor
    }

    var body: some View {
        Text(displayText)
    }

    private var displayText: AttributedString {
        var attributedText = AttributedString(line)
        if let defaultColor {
            attributedText.foregroundColor = defaultColor
        }

        guard
            emphasizesEffectiveOvertime,
            let range = effectiveOvertimeValueRange(in: line),
            let attributedRange = Range(range, in: attributedText)
        else {
            return attributedText
        }

        attributedText[attributedRange].foregroundColor = .red
        return attributedText
    }

    private func effectiveOvertimeValueRange(in text: String) -> Range<String.Index>? {
        let prefix = "有效加班时长"
        guard text.hasPrefix(prefix) else { return nil }

        let valueStart = text.index(text.startIndex, offsetBy: prefix.count)
        let valueEnd = text[valueStart...].firstIndex { character in
            !(character.isNumber || character == ".")
        } ?? text.endIndex
        guard valueStart < valueEnd else { return nil }

        return valueStart..<valueEnd
    }
}
