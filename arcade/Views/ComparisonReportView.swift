import SwiftUI
import AppKit

struct ComparisonReportView: View {
    @Bindable var state: AppState

    @State private var markdownCopied = false

    /// Cached on appear / state change to avoid repeated filtering
    @State private var completedTabs: [AppState.Tab] = []

    private func refreshCompletedTabs() {
        completedTabs = state.tabs.filter { $0.generationState == .completed }
    }

    // MARK: - Winner Computation

    private func totalTime(for tab: AppState.Tab) -> Double {
        tab.streamingMetrics?.totalDuration ?? tab.result?.duration ?? .infinity
    }

    private var fastestResponseTab: AppState.Tab? {
        completedTabs.min(by: { totalTime(for: $0) < totalTime(for: $1) })
    }

    private var fastestTTFTTab: AppState.Tab? {
        completedTabs
            .filter { $0.streamingMetrics?.firstTokenTime != nil }
            .min(by: { ($0.streamingMetrics?.firstTokenTime ?? .infinity) < ($1.streamingMetrics?.firstTokenTime ?? .infinity) })
    }

    private var highestThroughputTab: AppState.Tab? {
        completedTabs
            .filter { $0.streamingMetrics != nil }
            .max(by: { ($0.streamingMetrics?.tokensPerSecond ?? 0) < ($1.streamingMetrics?.tokensPerSecond ?? 0) })
    }

    // MARK: - Body

    private var hasStreamingMetrics: Bool {
        completedTabs.contains { $0.streamingMetrics != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\u{1F4CA} Comparison Report")
                    .font(.system(size: DS.Font.display, weight: .semibold))
                Spacer()
                Button {
                    copyMarkdown()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: markdownCopied ? "checkmark" : "doc.on.doc")
                        Text(markdownCopied ? "Copied" : "Copy as Markdown")
                    }
                    .font(.system(size: DS.Font.secondary))
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    state.closeReport()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    promptSection
                    if hasStreamingMetrics {
                        winnerCards
                    }
                    performanceTable
                    if hasStreamingMetrics {
                        barCharts
                    }
                    responsesSection
                }
                .padding(DS.Spacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { refreshCompletedTabs() }
    }

    // MARK: - Header (now in sheet toolbar above)

    // MARK: - Prompt

    private var promptSection: some View {
        Group {
            if let prompt = promptText, !prompt.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Prompt")
                        .font(.system(size: DS.Font.secondary, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(prompt)
                        .font(.system(size: DS.Font.body))
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                }
            }
        }
    }

    private var promptText: String? {
        guard let def = state.currentDefinition else { return nil }
        let chatParam = def.regularParams.first { $0.bodyPath == "_chat_message" }
        guard let name = chatParam?.name else { return nil }
        return state.formValues[name]
    }

    // MARK: - Winner Cards

    private var winnerCards: some View {
        HStack(spacing: DS.Spacing.md) {
            if let tab = fastestResponseTab, let metrics = tab.streamingMetrics {
                winnerCard(
                    label: "Fastest Response",
                    icon: "\u{26A1}",
                    tab: tab,
                    value: String(format: "%.1fs", metrics.totalDuration)
                )
            }
            if let tab = fastestTTFTTab, let ttft = tab.streamingMetrics?.firstTokenTime {
                winnerCard(
                    label: "Fastest First Token",
                    icon: "\u{23F1}",
                    tab: tab,
                    value: String(format: "%.0fms", ttft * 1000)
                )
            }
            if let tab = highestThroughputTab, let metrics = tab.streamingMetrics {
                winnerCard(
                    label: "Highest Throughput",
                    icon: "\u{1F680}",
                    tab: tab,
                    value: String(format: "%.1f tok/s", metrics.tokensPerSecond)
                )
            }
        }
    }

    private func winnerCard(label: String, icon: String, tab: AppState.Tab, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(icon)
                .font(.system(size: DS.Font.display))

            Text(label)
                .font(.system(size: DS.Font.secondary, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.xs) {
                ProviderIconView(
                    provider: tab.definition.provider,
                    displayName: tab.definition.providerDisplayName,
                    iconUrl: tab.definition.providerIconUrl,
                    iconService: state.iconService,
                    size: 14
                )
                Text(tab.model)
                    .font(.system(size: DS.Font.body, weight: .semibold))
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: DS.Font.body, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.green.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Performance Table

    private var performanceTable: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Performance")
                .font(.system(size: DS.Font.body, weight: .semibold))

            let bestTTFT = completedTabs.compactMap { $0.streamingMetrics?.firstTokenTime }.min()
            let bestSpeed = completedTabs.compactMap { $0.streamingMetrics?.tokensPerSecond }.max()
            let bestTokens = completedTabs.compactMap { $0.streamingMetrics?.tokenCount }.max()
            let bestTotal = completedTabs.map { totalTime(for: $0) }.filter { $0 < .infinity }.min()

            // Header
            HStack(spacing: 0) {
                Text("Model")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if hasStreamingMetrics {
                    Text("TTFT")
                        .frame(width: 80, alignment: .trailing)
                    Text("Speed")
                        .frame(width: 90, alignment: .trailing)
                    Text("Tokens")
                        .frame(width: 70, alignment: .trailing)
                }
                Text("Total")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: DS.Font.secondary, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)

            Divider()

            ForEach(completedTabs) { tab in
                let metrics = tab.streamingMetrics
                let tabTotal = totalTime(for: tab)
                HStack(spacing: 0) {
                    // Model column
                    HStack(spacing: DS.Spacing.xs) {
                        ProviderIconView(
                            provider: tab.definition.provider,
                            displayName: tab.definition.providerDisplayName,
                            iconUrl: tab.definition.providerIconUrl,
                            iconService: state.iconService,
                            size: 14
                        )
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tab.model)
                                .font(.system(size: DS.Font.secondary, weight: .medium))
                                .lineLimit(1)
                            Text(tab.definition.providerDisplayName)
                                .font(.system(size: DS.Font.caption))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if hasStreamingMetrics {
                        tableCell(
                            value: metrics?.firstTokenTime.map { String(format: "%.0fms", $0 * 1000) } ?? "\u{2014}",
                            isBest: metrics?.firstTokenTime != nil && metrics?.firstTokenTime == bestTTFT
                        )
                        .frame(width: 80, alignment: .trailing)

                        tableCell(
                            value: metrics.map { String(format: "%.1f tok/s", $0.tokensPerSecond) } ?? "\u{2014}",
                            isBest: metrics?.tokensPerSecond != nil && metrics?.tokensPerSecond == bestSpeed
                        )
                        .frame(width: 90, alignment: .trailing)

                        tableCell(
                            value: metrics.map { "\($0.tokenCount)" } ?? "\u{2014}",
                            isBest: metrics?.tokenCount != nil && metrics?.tokenCount == bestTokens
                        )
                        .frame(width: 70, alignment: .trailing)
                    }

                    tableCell(
                        value: tabTotal < .infinity ? String(format: "%.1fs", tabTotal) : "\u{2014}",
                        isBest: tabTotal < .infinity && tabTotal == bestTotal
                    )
                    .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)

                if tab.id != completedTabs.last?.id {
                    Divider().padding(.horizontal, DS.Spacing.md)
                }
            }

            // Methodology note
            Text("Metrics are measured client-side (wall-clock time including network latency), not reported by the API.")
                .font(.system(size: DS.Font.caption))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.xs)
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func tableCell(value: String, isBest: Bool) -> some View {
        Text(value)
            .font(.system(size: DS.Font.secondary, design: .monospaced))
            .foregroundStyle(isBest ? .green : .primary)
            .fontWeight(isBest ? .semibold : .regular)
    }

    // MARK: - Bar Charts

    private var barCharts: some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            barChartSection(
                title: "Time to First Token",
                tabs: completedTabs.filter { $0.streamingMetrics?.firstTokenTime != nil },
                valueExtractor: { $0.streamingMetrics?.firstTokenTime ?? 0 },
                formatter: { String(format: "%.0fms", $0 * 1000) },
                lowerIsBetter: true
            )

            barChartSection(
                title: "Speed (tok/s)",
                tabs: completedTabs.filter { $0.streamingMetrics != nil },
                valueExtractor: { $0.streamingMetrics?.tokensPerSecond ?? 0 },
                formatter: { String(format: "%.1f", $0) },
                lowerIsBetter: false
            )
        }
    }

    private func barChartSection(
        title: String,
        tabs: [AppState.Tab],
        valueExtractor: @escaping (AppState.Tab) -> Double,
        formatter: @escaping (Double) -> String,
        lowerIsBetter: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(.system(size: DS.Font.body, weight: .semibold))

            let maxVal = tabs.map(valueExtractor).max() ?? 1
            let bestVal = lowerIsBetter
                ? tabs.map(valueExtractor).min()
                : tabs.map(valueExtractor).max()

            ForEach(tabs) { tab in
                let val = valueExtractor(tab)
                let isBest = val == bestVal
                HStack(spacing: DS.Spacing.sm) {
                    Text(tab.model)
                        .font(.system(size: DS.Font.caption))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                        .lineLimit(1)

                    GeometryReader { geo in
                        let fraction = maxVal > 0 ? val / maxVal : 0
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(isBest ? Color.green : Color.accentColor.opacity(0.5))
                            .frame(width: geo.size.width * fraction)
                    }
                    .frame(height: 16)

                    Text(formatter(val))
                        .font(.system(size: DS.Font.caption, design: .monospaced))
                        .foregroundStyle(isBest ? .green : .secondary)
                        .frame(width: 60, alignment: .leading)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Responses

    private var responsesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Responses")
                .font(.system(size: DS.Font.body, weight: .semibold))

            ForEach(completedTabs) { tab in
                responseCard(tab)
            }
        }
    }

    private func responseCard(_ tab: AppState.Tab) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                ProviderIconView(
                    provider: tab.definition.provider,
                    displayName: tab.definition.providerDisplayName,
                    iconUrl: tab.definition.providerIconUrl,
                    iconService: state.iconService,
                    size: 16
                )
                Text(tab.model)
                    .font(.system(size: DS.Font.body, weight: .medium))
                Text(tab.definition.providerDisplayName)
                    .font(.system(size: DS.Font.secondary))
                    .foregroundStyle(.tertiary)

                Spacer()

                if let metrics = tab.streamingMetrics {
                    HStack(spacing: DS.Spacing.sm) {
                        if let ttft = metrics.firstTokenTime {
                            miniStamp(label: "TTFT", value: String(format: "%.0fms", ttft * 1000))
                        }
                        miniStamp(label: "Speed", value: String(format: "%.1f tok/s", metrics.tokensPerSecond))
                        miniStamp(label: "Total", value: String(format: "%.1fs", metrics.totalDuration))
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Response body — text or media
            if let result = tab.result, result.outputs.contains(where: { $0.type == .image }) {
                // Image outputs
                ForEach(result.outputs.filter { $0.type == .image }) { output in
                    ForEach(output.values, id: \.self) { value in
                        AsyncImage(url: URL(string: value)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                        } placeholder: {
                            ProgressView()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(DS.Spacing.md)
            } else if !tab.streamedText.isEmpty {
                MarkdownTextView(text: tab.streamedText)
                    .padding(DS.Spacing.md)
                    .textSelection(.enabled)
            } else if let result = tab.result {
                // Sync results — show text outputs
                let textValues = result.outputs.filter { $0.type == .text }.flatMap(\.values)
                if !textValues.isEmpty {
                    MarkdownTextView(text: textValues.joined(separator: "\n\n"))
                        .padding(DS.Spacing.md)
                        .textSelection(.enabled)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func miniStamp(label: String, value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: DS.Font.caption, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.xs + 2)
        .padding(.vertical, 2)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }

    // MARK: - Copy as Markdown

    private func copyMarkdown() {
        var md = "# Comparison Report\n\n"

        if let prompt = promptText, !prompt.isEmpty {
            md += "**Prompt:** \(prompt)\n\n"
        }

        md += "## Winners\n"
        if let tab = fastestResponseTab, let metrics = tab.streamingMetrics {
            md += "- \u{26A1} Fastest Response: \(tab.model) (\(String(format: "%.1fs", metrics.totalDuration)))\n"
        }
        if let tab = fastestTTFTTab, let ttft = tab.streamingMetrics?.firstTokenTime {
            md += "- \u{23F1} Fastest First Token: \(tab.model) (\(String(format: "%.0fms", ttft * 1000)))\n"
        }
        if let tab = highestThroughputTab, let metrics = tab.streamingMetrics {
            md += "- \u{1F680} Highest Throughput: \(tab.model) (\(String(format: "%.1f tok/s", metrics.tokensPerSecond)))\n"
        }

        md += "\n## Performance\n\n"
        md += "| Model | TTFT | Speed | Tokens | Total |\n"
        md += "|-------|------|-------|--------|-------|\n"
        for tab in completedTabs {
            let metrics = tab.streamingMetrics
            let ttft = metrics?.firstTokenTime.map { String(format: "%.0fms", $0 * 1000) } ?? "-"
            let speed = metrics.map { String(format: "%.1f tok/s", $0.tokensPerSecond) } ?? "-"
            let tokens = metrics.map { "\($0.tokenCount)" } ?? "-"
            let total = metrics.map { String(format: "%.1fs", $0.totalDuration) } ?? "-"
            md += "| \(tab.model) (\(tab.definition.providerDisplayName)) | \(ttft) | \(speed) | \(tokens) | \(total) |\n"
        }

        md += "\n## Responses\n"
        for tab in completedTabs {
            md += "\n### \(tab.model) (\(tab.definition.providerDisplayName))\n"
            if let result = tab.result {
                let imageOutputs = result.outputs.filter { $0.type == .image }
                if !imageOutputs.isEmpty {
                    for output in imageOutputs {
                        for value in output.values {
                            if value.hasPrefix("data:") {
                                md += "*[Base64 image — not embeddable in markdown]*\n\n"
                            } else {
                                md += "![Generated image](\(value))\n\n"
                            }
                        }
                    }
                }
            }
            if !tab.streamedText.isEmpty {
                md += tab.streamedText + "\n"
            } else if let result = tab.result {
                let textValues = result.outputs.filter { $0.type == .text }.flatMap(\.values)
                if !textValues.isEmpty {
                    md += textValues.joined(separator: "\n\n") + "\n"
                }
            }
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            markdownCopied = true
        }
        SoundService.confirm()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation { markdownCopied = false }
        }
    }
}
