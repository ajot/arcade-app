import SwiftUI

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    private enum Block {
        case paragraph(String)
        case codeBlock(language: String?, code: String)
        case heading(level: Int, text: String)
        case listItem(ordered: Bool, text: String)
        case blockquote(String)
    }

    // MARK: - Parser

    private func parseBlocks() -> [Block] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [Block] = []
        var paragraph: [String] = []
        var i = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let joined = paragraph.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                blocks.append(.paragraph(joined))
            }
            paragraph = []
        }

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                flushParagraph()
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(
                    language: lang.isEmpty ? nil : lang,
                    code: codeLines.joined(separator: "\n")
                ))
                if i < lines.count { i += 1 } // skip closing ```
                continue
            }

            // Heading
            if let headingMatch = line.range(of: #"^(#{1,6})\s+(.+)$"#, options: .regularExpression) {
                let matched = String(line[headingMatch])
                let level = matched.prefix(while: { $0 == "#" }).count
                let content = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    flushParagraph()
                    blocks.append(.heading(level: level, text: content))
                    i += 1
                    continue
                }
            }

            // Unordered list item
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flushParagraph()
                blocks.append(.listItem(ordered: false, text: String(line.dropFirst(2))))
                i += 1
                continue
            }

            // Ordered list item
            if line.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) != nil {
                flushParagraph()
                let textStart = line.firstIndex(where: { $0 == "." || $0 == ")" })
                    .map { line.index(after: $0) }
                let content = textStart.map { String(line[$0...]).trimmingCharacters(in: .whitespaces) } ?? line
                blocks.append(.listItem(ordered: true, text: content))
                i += 1
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.blockquote(String(line.dropFirst(2))))
                i += 1
                continue
            }

            // Empty line = paragraph break
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Regular text
            paragraph.append(line)
            i += 1
        }

        flushParagraph()
        return blocks
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            inlineMarkdown(text)

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                if let lang = language {
                    Text(lang)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, language != nil ? 4 : 10)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bg900)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.border700, lineWidth: 0.5)
            )

        case .heading(let level, let text):
            let size: CGFloat = switch level {
            case 1: 18
            case 2: 16
            case 3: 14
            default: 13
            }
            let weight: Font.Weight = level <= 2 ? .semibold : .medium
            Text(text)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, level <= 2 ? 4 : 2)

        case .listItem(_, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textMuted)
                inlineMarkdown(text)
            }

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.border600)
                    .frame(width: 3)
                inlineMarkdown(text)
                    .padding(.leading, 12)
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func inlineMarkdown(_ text: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .textSelection(.enabled)
                .lineSpacing(4)
                .tint(Color.accent)
        } else {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .textSelection(.enabled)
                .lineSpacing(4)
        }
    }
}
