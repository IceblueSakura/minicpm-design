import SwiftUI

/// `Text` renders only inline markdown, so blocks are split here and each block's inline part goes through
/// `AttributedString(markdown:)`. Tables stay monospaced in a horizontal scroller, so they never break the page.
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

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String]?
        var table: [String] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            if !table.isEmpty { blocks.append(.code(table.joined(separator: "\n"))) }
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
}

#Preview {
    ScrollView {
        MarkdownView(text: "## 标题\n\n一段**粗体**和`代码`。\n\n- 第一项\n- 第二项\n\n> 引用\n\n```\nlet a = 1\n```").padding()
    }
}
