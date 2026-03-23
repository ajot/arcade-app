import SwiftUI
import UniformTypeIdentifiers

struct ResultCard: View {
    @Bindable var state: AppState

    @State private var showCopied = false
    @State private var showSaved = false
    @State private var showRequestJSON = false
    @State private var showResponseJSON = false
    @State private var requestJSONCopied = false
    @State private var responseJSONCopied = false

    // MARK: - Compare-aware accessors

    private var effectiveGenerationState: AppState.GenerationState {
        state.isCompareMode
            ? (state.tabs[safe: state.activeTabIndex]?.generationState ?? .idle)
            : state.generationState
    }

    private var effectiveStreamedText: String {
        state.isCompareMode
            ? (state.tabs[safe: state.activeTabIndex]?.streamedText ?? "")
            : state.streamedText
    }

    private var effectiveStreamingMetrics: StreamingResult? {
        state.isCompareMode
            ? state.tabs[safe: state.activeTabIndex]?.streamingMetrics
            : state.streamingMetrics
    }

    private var effectiveGenerationResult: GenerationResult? {
        state.isCompareMode
            ? state.tabs[safe: state.activeTabIndex]?.result
            : state.generationResult
    }

    private var effectiveLastRequestBody: String? {
        state.isCompareMode
            ? state.tabs[safe: state.activeTabIndex]?.lastRequestBody
            : state.lastRequestBody
    }

    private var effectiveLastResponseBody: String? {
        state.isCompareMode
            ? state.tabs[safe: state.activeTabIndex]?.lastResponseBody
            : state.lastResponseBody
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Result toolbar — only shows when completed (low-frequency state change)
            if effectiveGenerationState == .completed {
                ResultToolbar(state: state)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Text output (isolated view — only it re-renders per token)
                textResult

                // Media outputs
                if let result = effectiveGenerationResult {
                    ForEach(result.outputs) { output in
                        switch output.type {
                        case .image:
                            imageResult(output)
                        case .audio:
                            audioResult(output)
                        case .video:
                            videoResult(output)
                        case .text:
                            EmptyView() // handled by streamedText
                        }
                    }
                }

                // Metrics
                metricsBar

                // Request/Response JSON
                if effectiveGenerationState == .completed {
                    requestResponseSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, effectiveGenerationState == .completed ? 4 : 16)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.97, anchor: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Text Result (isolated to avoid invalidation storms during streaming)

    private var textResult: some View {
        StreamingTextContent(state: state)
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(effectiveStreamedText, forType: .string)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopied = true
            }
            SoundService.confirm()
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(1500))
                withAnimation { showCopied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: DS.Font.caption))
                Text(showCopied ? "Copied" : "Copy")
                    .font(.system(size: DS.Font.secondary))
            }
            .foregroundStyle(showCopied ? Color.green : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save Image

    private var hasImageOutput: Bool {
        effectiveGenerationResult?.outputs.contains(where: { $0.type == .image }) ?? false
    }

    private var saveImageButton: some View {
        Button {
            saveImage()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showSaved ? "checkmark" : "arrow.down.circle")
                    .font(.system(size: DS.Font.caption))
                Text(showSaved ? "Saved" : "Save")
                    .font(.system(size: DS.Font.secondary))
            }
            .foregroundStyle(showSaved ? Color.green : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func saveImage() {
        guard let result = effectiveGenerationResult,
              let imageOutput = result.outputs.first(where: { $0.type == .image }),
              let value = imageOutput.values.first else { return }

        Task {
            let imageData = await loadImageData(from: value)
            guard let data = imageData,
                  let nsImage = NSImage(data: data),
                  let tiff = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                SoundService.error()
                return
            }

            await MainActor.run {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.png]
                panel.nameFieldStringValue = "arcade-image-\(Int(Date().timeIntervalSince1970)).png"

                if panel.runModal() == .OK, let url = panel.url {
                    do {
                        try pngData.write(to: url)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showSaved = true
                        }
                        SoundService.confirm()
                        Task { @MainActor in try? await Task.sleep(for: .milliseconds(1500))
                            withAnimation { showSaved = false }
                        }
                    } catch {
                        SoundService.error()
                    }
                }
            }
        }
    }

    private func loadImageData(from value: String) async -> Data? {
        if value.hasPrefix("data:") {
            return dataFromDataURL(value)
        } else if let url = URL(string: value) {
            return try? await URLSession.shared.data(from: url).0
        }
        return nil
    }

    // MARK: - Media Results

    @ViewBuilder
    private func imageResult(_ output: ExtractedOutput) -> some View {
        ForEach(output.values, id: \.self) { value in
            if value.hasPrefix("data:") {
                // Base64 data URL
                if let data = dataFromDataURL(value),
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .onTapGesture { state.zoomedImageValue = value }
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                }
            } else if let url = URL(string: value) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                            .onTapGesture { state.zoomedImageValue = value }
                            .onHover { hovering in
                                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                    case .failure:
                        Label("Failed to load image", systemImage: "photo")
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func audioResult(_ output: ExtractedOutput) -> some View {
        ForEach(output.values, id: \.self) { value in
            AudioPlayerView(urlString: value)
        }
    }

    @ViewBuilder
    private func videoResult(_ output: ExtractedOutput) -> some View {
        ForEach(Array(output.values.enumerated()), id: \.offset) { _, value in
            if let url = URL(string: value) {
                VideoPlayerView(url: url)
            }
        }
    }

    // MARK: - Metrics

    @ViewBuilder
    private var metricsBar: some View {
        HStack(spacing: 16) {
            if let metrics = effectiveStreamingMetrics {
                metricPill(label: "TTFT", value: String(format: "%.0fms", (metrics.firstTokenTime ?? 0) * 1000))
                metricPill(label: "Speed", value: String(format: "%.1f tok/s", metrics.tokensPerSecond))
                metricPill(label: "Tokens", value: "\(metrics.tokenCount)")
                metricPill(label: "Total", value: String(format: "%.2fs", metrics.totalDuration))
            } else if let result = effectiveGenerationResult {
                metricPill(label: "Time", value: String(format: "%.2fs", result.duration))
                if result.pollCount > 0 {
                    metricPill(label: "Polls", value: "\(result.pollCount)")
                }
            }
        }
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.4), value: effectiveGenerationState == .completed)
    }

    private func metricPill(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: DS.Font.caption))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: DS.Font.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Request/Response JSON

    @ViewBuilder
    private var requestResponseSection: some View {
        VStack(spacing: 0) {
            // Request
            if let requestBody = effectiveLastRequestBody, let definition = state.currentDefinition {
                jsonDisclosure(
                    title: "Request",
                    subtitle: "\(definition.request.method) \(definition.request.url)",
                    json: requestBody,
                    isExpanded: $showRequestJSON,
                    isCopied: $requestJSONCopied
                )
            }

            // Response
            if let responseBody = effectiveLastResponseBody {
                let statusLabel: String = {
                    if let result = effectiveGenerationResult {
                        return "\(result.statusCode) \u{00B7} \(String(format: "%.2fs", result.duration))"
                    }
                    return ""
                }()

                jsonDisclosure(
                    title: "Response",
                    subtitle: statusLabel,
                    json: responseBody,
                    isExpanded: $showResponseJSON,
                    isCopied: $responseJSONCopied
                )
            } else if effectiveStreamingMetrics != nil {
                // Streaming endpoints don't have a single JSON response
                let metrics = effectiveStreamingMetrics!
                let streamNote = """
                // Streamed response (SSE)
                // \(metrics.tokenCount) tokens in \(String(format: "%.2fs", metrics.totalDuration))
                // \(String(format: "%.1f", metrics.tokensPerSecond)) tokens/sec
                // See rendered output above
                """
                jsonDisclosure(
                    title: "Response",
                    subtitle: "streamed",
                    json: streamNote,
                    isExpanded: $showResponseJSON,
                    isCopied: $responseJSONCopied
                )
            }
        }
        .padding(.top, 8)
    }

    private func jsonDisclosure(
        title: String,
        subtitle: String,
        json: String,
        isExpanded: Binding<Bool>,
        isCopied: Binding<Bool>
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(json, forType: .string)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isCopied.wrappedValue = true
                        }
                        SoundService.confirm()
                        Task { @MainActor in try? await Task.sleep(for: .milliseconds(1500))
                            withAnimation { isCopied.wrappedValue = false }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isCopied.wrappedValue ? "checkmark" : "doc.on.doc")
                            Text(isCopied.wrappedValue ? "Copied" : "Copy")
                        }
                        .font(.system(size: DS.Font.caption))
                        .foregroundStyle(isCopied.wrappedValue ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView([.horizontal, .vertical]) {
                    Text(json)
                        .font(.system(size: DS.Font.secondary, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .padding(DS.Spacing.md)
                }
                .frame(maxHeight: 300)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.system(size: DS.Font.secondary, weight: .medium))
                    .foregroundStyle(.tertiary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: DS.Font.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .disclosureGroupStyle(.automatic)
    }

    // MARK: - Helpers

    private func dataFromDataURL(_ dataURL: String) -> Data? {
        guard let commaIndex = dataURL.firstIndex(of: ",") else { return nil }
        let base64 = String(dataURL[dataURL.index(after: commaIndex)...])
        return Data(base64Encoded: base64)
    }
}

// MARK: - Streaming Text (isolated to avoid invalidation storms)

/// Only this view re-renders per token during streaming.
/// Prevents the entire ResultCard from re-evaluating on every incoming token.
private struct StreamingTextContent: View {
    @Bindable var state: AppState

    private var text: String {
        state.isCompareMode
            ? (state.tabs[safe: state.activeTabIndex]?.streamedText ?? "")
            : state.streamedText
    }

    private var isStreaming: Bool {
        let genState = state.isCompareMode
            ? (state.tabs[safe: state.activeTabIndex]?.generationState ?? .idle)
            : state.generationState
        if case .streaming = genState { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !text.isEmpty {
                MarkdownTextView(text: text)
            }

            if isStreaming {
                StreamingCursor()
            }
        }
    }
}

// MARK: - Result Toolbar (isolated — reads streamedText only when completed)

private struct ResultToolbar: View {
    @Bindable var state: AppState
    @State private var showCopied = false

    private var text: String {
        state.isCompareMode
            ? (state.tabs[safe: state.activeTabIndex]?.streamedText ?? "")
            : state.streamedText
    }

    private var result: GenerationResult? {
        state.isCompareMode
            ? state.tabs[safe: state.activeTabIndex]?.result
            : state.generationResult
    }

    private var hasImageOutput: Bool {
        result?.outputs.contains { $0.type == .image } ?? false
    }

    var body: some View {
        HStack {
            Spacer()
            if !text.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCopied = true
                    }
                    SoundService.confirm()
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(1500))
                        withAnimation { showCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied" : "Copy")
                    }
                    .font(.system(size: DS.Font.secondary))
                    .foregroundStyle(showCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Streaming Cursor

struct StreamingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
