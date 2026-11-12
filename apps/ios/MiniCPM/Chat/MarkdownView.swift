import SwiftUI

/// `Text` renders only inline markdown, so blocks are split here and each block's inline part goes through
/// `AttributedString(markdown:)`. Tables are a grid in a horizontal scroller: cells wrap up to a width, and a table
/// wider than the page scrolls instead of breaking it (docs/05-states.md#回答内容).
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MarkdownBlock.parse(text).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let content):
            Text(inline(content)).font(level == 1 ? .title3.weight(.semibold) : .headline)
        case .paragraph(let content):
            Text(inline(content))
        case .item(let marker, let content):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(marker).foregroundStyle(.secondary)
                Text(inline(content))
            }
        case .quote(let content):
            Text(inline(content))
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) { Rectangle().fill(.separator).frame(width: 2) }
        case .table(let rows):
            TableBlock(rows: rows, inline: inline)
        case .code(let content):
            ScrollView(.horizontal) {
                Text(content).font(.callout.monospaced()).padding(10)
            }
            .background(.fill.tertiary, in: .rect(cornerRadius: 10))
        }
    }

    private func inline(_ content: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: content, options: options)) ?? AttributedString(content)
    }
}

enum MarkdownBlock {
    case heading(level: Int, String)
    case paragraph(String)
    case item(marker: String, String)
    case quote(String)
    case code(String)
    /// The first row is the header. Rows are padded to the same number of cells.
    case table([[String]])

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String]?
        var table: [String] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            if !table.isEmpty { blocks.append(.table(tableRows(table))) }
            paragraph = []
            table = []
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                flush()
                if let lines = code {
                    blocks.append(.code(lines.joined(separator: "\n")))
                    code = nil
                } else {
                    code = []
                }
            } else if code != nil {
                code?.append(raw)
            } else if line.isEmpty {
                flush()
            } else if line.hasPrefix("|") {
                table.append(line)
            } else if let heading = line.prefixMatch(of: /^(#{1,3})\s+(.+)$/) {
                flush()
                blocks.append(.heading(level: heading.1.count, String(heading.2)))
            } else if let item = line.prefixMatch(of: /^(\d+\.|[-*])\s+(.+)$/) {
                flush()
                blocks.append(.item(marker: item.1 == "-" || item.1 == "*" ? "•" : String(item.1), String(item.2)))
            } else if line.hasPrefix("> ") {
                flush()
                blocks.append(.quote(String(line.dropFirst(2))))
            } else {
                paragraph.append(line)
            }
        }
        // An open fence is normal while a reply streams.
        if let code { blocks.append(.code(code.joined(separator: "\n"))) }
        flush()
        return blocks
    }

    /// Drops the `|---|` rule, and pipes at both ends. A row still streaming in may have fewer cells.
    static func tableRows(_ lines: [String]) -> [[String]] {
        let rows = lines
            .filter { $0.wholeMatch(of: /\|?(\s*:?-+:?\s*\|)*\s*:?-+:?\s*\|?/) == nil }
            .map { line in
                var cells = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
                if cells.first == "" { cells.removeFirst() }
                if cells.last == "" { cells.removeLast() }
                return cells
            }
        let width = rows.map(\.count).max() ?? 0
        return rows.map { $0 + Array(repeating: "", count: width - $0.count) }
    }
}

private struct TableBlock: View {
    let rows: [[String]]
    let inline: (String) -> AttributedString
    @ScaledMetric(relativeTo: .subheadline) private var cellWidth = 220

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(rows[row].indices, id: \.self) { column in
                            cell(row, column)
                        }
                    }
                    if row == 0 && rows.count > 1 { Divider() }
                }
            }
            .padding(12)
        }
        .background(.fill.tertiary, in: .rect(cornerRadius: 10))
    }

    /// Wraps past `cellWidth`. Body cells read with their column name, since a screen reader meets them one by one.
    private func cell(_ row: Int, _ column: Int) -> some View {
        let value = inline(rows[row][column])
        let header = String(inline(rows[0][column]).characters)
        return Text(value)
            .font(row == 0 ? .subheadline.weight(.semibold) : .subheadline)
            .frame(maxWidth: cellWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(row == 0 || header.isEmpty ? Text(value) : Text("\(header)：\(String(value.characters))", comment: "Table cell spoken by VoiceOver; placeholders are the column heading and cell content. Do not translate their values."))
            .accessibilityAddTraits(row == 0 ? .isHeader : [])
    }
}

#Preview {
    ScrollView {
        MarkdownView(text: "## 标题\n\n一段**粗体**和`代码`。\n\n- 第一项\n- 第二项\n\n> 引用\n\n| 项目 | 结果 | 参考范围 |\n|---|---|---|\n| 空腹血糖 | **6.4** | 3.9–6.1 |\n| 总胆固醇 | 5.3 | < 5.2 |\n\n```\nlet a = 1\n```").padding()
    }
}
