//
//  myCalculatorApp.swift
//  myCalculator
//
//  Created by 渠晓友 on 2026/4/9.
//

import SwiftUI

@main
struct myCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 620)
        }
        .defaultSize(width: 1080, height: 700)
        .commands {
            AppHelpCommands()
        }

        Window("帮助文档目录", id: "helpIndex") {
            MarkdownHelpView(markdown: MarkdownDocumentContent.load(resource: "help-index", missingMessage: "未找到帮助文档目录。"))
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 820, height: 680)

        Window("项目说明", id: "projectReadme") {
            MarkdownHelpView(markdown: MarkdownDocumentContent.load(resource: "README", missingMessage: "未找到项目说明 README.md。"))
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 820, height: 680)

        Window("工时计算规则", id: "workRulesHelp") {
            MarkdownHelpView(markdown: WorkRulesHelpContent.load())
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 820, height: 680)

        Window("浏览器扩展自动填报", id: "browserExtensionAutofill") {
            MarkdownHelpView(markdown: MarkdownDocumentContent.load(resource: "browser-extension-autofill", missingMessage: "未找到浏览器扩展自动填报说明。"))
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 820, height: 680)

        Window("问题复盘：月视图跨月渲染", id: "monthViewRenderingPostmortem") {
            MarkdownHelpView(markdown: MarkdownDocumentContent.load(resource: "month-view-rendering-postmortem", missingMessage: "未找到月视图渲染问题复盘。"))
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 820, height: 680)

        Window("SwiftUI 与 UIKit 心智模型", id: "swiftUIUIKitMentalModels") {
            MarkdownHelpView(markdown: MarkdownDocumentContent.load(resource: "swiftui-uikit-mental-models", missingMessage: "未找到 SwiftUI 与 UIKit 心智模型文档。"))
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 820, height: 680)
    }
}

private struct AppHelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("帮助文档目录") {
                openWindow(id: "helpIndex")
            }

            Divider()

            Button("项目说明") {
                openWindow(id: "projectReadme")
            }

            Button("工时计算规则") {
                openWindow(id: "workRulesHelp")
            }
            .keyboardShortcut("?", modifiers: [.command])

            Button("浏览器扩展自动填报") {
                openWindow(id: "browserExtensionAutofill")
            }

            Divider()

            Button("问题复盘：月视图跨月渲染") {
                openWindow(id: "monthViewRenderingPostmortem")
            }

            Button("SwiftUI 与 UIKit 心智模型") {
                openWindow(id: "swiftUIUIKitMentalModels")
            }
        }
    }
}

private struct MarkdownHelpView: View {
    private let blocks: [MarkdownHelpBlock]

    init(markdown: String) {
        blocks = MarkdownHelpParser.parse(markdown)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    MarkdownHelpBlockView(block: block)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum MarkdownDocumentContent {
    static func load(resource: String, missingMessage: String) -> String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return missingMessage
        }

        return content
    }
}

private enum WorkRulesHelpContent {
    static func load() -> String {
        guard let url = Bundle.main.url(forResource: "README", withExtension: "md"),
              let readme = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "未找到 README.md。"
        }

        return extractRulesSection(from: readme) ?? readme
    }

    private static func extractRulesSection(from readme: String) -> String? {
        let startMarker = "### 2.2 工时与加班计算规则"
        let endMarker = "### 2.3 左侧栏信息"

        guard let startRange = readme.range(of: startMarker) else {
            return nil
        }

        let sectionStart = startRange.lowerBound
        let sectionEnd = readme[sectionStart...].range(of: endMarker)?.lowerBound ?? readme.endIndex
        return String(readme[sectionStart..<sectionEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum MarkdownHelpBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list([String])
    case table(headers: [String], rows: [[String]])
}

private enum MarkdownHelpParser {
    static func parse(_ markdown: String) -> [MarkdownHelpBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownHelpBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                index += 1
                continue
            }

            if let heading = parseHeading(line) {
                blocks.append(heading)
                index += 1
                continue
            }

            if line.hasPrefix("|"), index + 1 < lines.count, isTableSeparator(lines[index + 1]) {
                let parsed = parseTable(from: lines, startIndex: index)
                blocks.append(parsed.block)
                index = parsed.nextIndex
                continue
            }

            if let listItem = parseListItem(line) {
                var items = [listItem]
                index += 1
                while index < lines.count, let nextItem = parseListItem(lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(nextItem)
                    index += 1
                }
                blocks.append(.list(items))
                continue
            }

            let parsed = parseParagraph(from: lines, startIndex: index)
            blocks.append(.paragraph(parsed.text))
            index = parsed.nextIndex
        }

        return blocks
    }

    private static func parseHeading(_ line: String) -> MarkdownHelpBlock? {
        let markerCount = line.prefix { $0 == "#" }.count
        guard markerCount > 0,
              markerCount <= 6,
              line.dropFirst(markerCount).first == " "
        else {
            return nil
        }

        let text = String(line.dropFirst(markerCount + 1)).trimmingCharacters(in: .whitespaces)
        return .heading(level: markerCount, text: text)
    }

    private static func parseListItem(_ line: String) -> String? {
        guard line.hasPrefix("- ") else { return nil }
        return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    private static func parseParagraph(from lines: [String], startIndex: Int) -> (text: String, nextIndex: Int) {
        var paragraphLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || parseHeading(line) != nil || parseListItem(line) != nil || line.hasPrefix("|") {
                break
            }

            paragraphLines.append(line)
            index += 1
        }

        return (paragraphLines.joined(separator: " "), index)
    }

    private static func parseTable(from lines: [String], startIndex: Int) -> (block: MarkdownHelpBlock, nextIndex: Int) {
        let headers = parseTableCells(lines[startIndex])
        var rows: [[String]] = []
        var index = startIndex + 2

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("|") else { break }
            rows.append(parseTableCells(line))
            index += 1
        }

        return (.table(headers: headers, rows: rows), index)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") else { return false }
        return trimmed.allSatisfy { character in
            character == "|" || character == "-" || character == ":" || character == " "
        }
    }

    private static func parseTableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        return trimmed
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

private struct MarkdownHelpBlockView: View {
    let block: MarkdownHelpBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            markdownText(text)
                .font(font(forHeadingLevel: level))
                .padding(.top, level <= 3 ? 8 : 2)
                .textSelection(.enabled)
        case let .paragraph(text):
            markdownText(text)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
        case let .list(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        markdownText(item)
                            .font(.body)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                    }
                }
            }
        case let .table(headers, rows):
            MarkdownHelpTable(headers: headers, rows: rows)
        }
    }

    private func font(forHeadingLevel level: Int) -> Font {
        switch level {
        case 1, 2:
            return .title2.bold()
        case 3:
            return .title3.bold()
        case 4:
            return .headline
        default:
            return .subheadline.bold()
        }
    }
}

private struct MarkdownHelpTable: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        tableCell(header, isHeader: true)
                    }
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(0..<headers.count, id: \.self) { index in
                            tableCell(index < row.count ? row[index] : "", isHeader: false)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.quaternary)
            }
        }
    }

    private func tableCell(_ text: String, isHeader: Bool) -> some View {
        markdownText(text)
            .font(isHeader ? .caption.bold() : .caption)
            .lineLimit(nil)
            .textSelection(.enabled)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 96, maxWidth: 190, alignment: .leading)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .textBackgroundColor))
            .border(.quaternary, width: 0.5)
    }
}

private func markdownText(_ markdown: String) -> Text {
    if let attributed = try? AttributedString(
        markdown: markdown,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    ) {
        return Text(attributed)
    }

    return Text(markdown)
}
