import SwiftUI

struct PlayView: View {
    @Bindable var state: AppState
    @State private var appeared = false
    @State private var settingsExpanded = false

    var body: some View {
        guard let definition = state.currentDefinition else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Endpoint header
                        endpointHeader(definition)
                            .padding(.bottom, 20)

                        // Examples
                        if !definition.examples.isEmpty {
                            exampleChips(definition)
                                .padding(.bottom, 20)
                        }

                        // Form fields
                        formFields(definition)
                            .padding(.bottom, 16)

                        // Settings section
                        if !definition.advancedParams.isEmpty || definition.isChatEndpoint {
                            settingsSection(definition)
                                .padding(.bottom, 20)
                        }

                        // Generate bar
                        generateBar(definition)
                            .padding(.bottom, 24)

                        // Results
                        resultArea(definition)

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 80)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .onChange(of: state.streamedText) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35)) {
                    appeared = true
                }
            }
            .onChange(of: state.currentDefinition?.id) {
                appeared = false
                withAnimation(.easeOut(duration: 0.35)) {
                    appeared = true
                }
            }
        )
    }

    // MARK: - Header

    private func endpointHeader(_ definition: Definition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(definition.description)
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)

            Text(definition.request.url)
                .font(.brandSmall)
                .foregroundStyle(Color.textMuted)
                .textSelection(.enabled)
        }
    }

    // MARK: - Examples

    private func exampleChips(_ definition: Definition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Examples")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            FlowLayout(spacing: 6) {
                ForEach(definition.examples) { example in
                    Button(example.label) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            state.fillExample(example)
                        }
                        NSSound(named: "Tink")?.play()
                    }
                    .buttonStyle(ChipStyle())
                }
            }
        }
    }

    // MARK: - Form Fields

    private func formFields(_ definition: Definition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(definition.regularParams.enumerated()), id: \.element.id) { index, param in
                paramField(param, isPrimary: param.bodyPath == "_chat_message")
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func paramField(_ param: ParamDefinition, isPrimary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(param.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                if param.isRequired {
                    Text("*")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accent)
                }
            }

            switch param.ui {
            case .textarea:
                textAreaField(param, isPrimary: isPrimary)
            case .dropdown:
                dropdownField(param)
            case .slider:
                sliderField(param)
            case .text:
                textField(param)
            }
        }
    }

    private func textAreaField(_ param: ParamDefinition, isPrimary: Bool) -> some View {
        let binding = Binding<String>(
            get: { state.formValues[param.name] ?? "" },
            set: { state.formValues[param.name] = $0 }
        )

        return TextEditor(text: binding)
            .font(.system(size: 13))
            .foregroundStyle(Color.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: isPrimary ? 80 : 60)
            .padding(10)
            .background(isPrimary ? Color.bg900.opacity(0.8) : Color.bg900)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.border700, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                if isPrimary {
                    Rectangle()
                        .fill(Color.accent)
                        .frame(width: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                        .padding(.vertical, 4)
                }
            }
    }

    private func dropdownField(_ param: ParamDefinition) -> some View {
        let binding = Binding<String>(
            get: { state.formValues[param.name] ?? param.defaultDisplayString ?? "" },
            set: { state.formValues[param.name] = $0 }
        )

        return Picker("", selection: binding) {
            if let options = param.options {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(Color.textPrimary)
    }

    private func sliderField(_ param: ParamDefinition) -> some View {
        let minVal = param.min ?? 0
        let maxVal = param.max ?? 100
        let step = param.type == .integer ? 1.0 : 0.1

        let binding = Binding<Double>(
            get: {
                Double(state.formValues[param.name] ?? "") ?? param.defaultValue?.doubleValue ?? minVal
            },
            set: {
                if param.type == .integer {
                    state.formValues[param.name] = "\(Int($0))"
                } else {
                    state.formValues[param.name] = String(format: "%.1f", $0)
                }
            }
        )

        return HStack(spacing: 12) {
            Slider(value: binding, in: minVal...maxVal, step: step)
                .tint(Color.accent)

            Text(state.formValues[param.name] ?? param.defaultDisplayString ?? "")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
        }
    }

    private func textField(_ param: ParamDefinition) -> some View {
        let binding = Binding<String>(
            get: { state.formValues[param.name] ?? "" },
            set: { state.formValues[param.name] = $0 }
        )

        return TextField(param.placeholder ?? "", text: binding)
            .textFieldStyle(.plain)
            .inputFieldStyle()
    }

    // MARK: - Settings

    private func settingsSection(_ definition: Definition) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toggle header
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    settingsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textMuted)
                        .rotationEffect(.degrees(settingsExpanded ? 90 : 0))

                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textTertiary)

                    if !settingsExpanded {
                        // Summary
                        Text(settingsSummary(definition))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if settingsExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(definition.advancedParams) { param in
                        paramField(param)
                    }

                    if definition.isChatEndpoint {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("System Prompt")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.textTertiary)

                            TextEditor(text: $state.systemPrompt)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 60)
                                .padding(10)
                                .background(Color.bg900)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(Color.border700, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.bg900.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.border700.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func settingsSummary(_ definition: Definition) -> String {
        definition.advancedParams.compactMap { param in
            let value = state.formValues[param.name] ?? param.defaultDisplayString
            guard let v = value else { return nil }
            return "\(param.name): \(v)"
        }.joined(separator: " \u{00B7} ")
    }

    // MARK: - Generate Bar

    private func generateBar(_ definition: Definition) -> some View {
        HStack(spacing: 12) {
            Spacer()

            // Curl preview button
            Button {
                // TODO: Phase 6 — curl preview
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                    Text("curl")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.bg800.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.border700.opacity(0.5), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            // Generate button
            let isGenerating = state.generationState != .idle && state.generationState != .completed && state.generationState != .error("")

            Button {
                if isActive(state.generationState) {
                    state.cancelGeneration()
                    state.generationState = .idle
                } else {
                    state.generate()
                }
            } label: {
                HStack(spacing: 6) {
                    if isActive(state.generationState) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                        Text(generateButtonText)
                            .font(.system(size: 13, weight: .semibold))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("Generate")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle(isGenerating: isActive(state.generationState)))
            .disabled(!state.hasValidKey && !isActive(state.generationState))
        }
    }

    private var generateButtonText: String {
        switch state.generationState {
        case .generating: return "Generating..."
        case .streaming: return "Streaming..."
        case .polling(let msg): return msg
        default: return "Generate"
        }
    }

    private func isActive(_ genState: AppState.GenerationState) -> Bool {
        switch genState {
        case .generating, .streaming, .polling: return true
        default: return false
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultArea(_ definition: Definition) -> some View {
        switch state.generationState {
        case .completed, .streaming:
            VStack(alignment: .leading, spacing: 0) {
                // Result toolbar
                if state.generationState == .completed {
                    HStack {
                        Spacer()
                        copyButton
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Text output
                    if !state.streamedText.isEmpty {
                        textResult
                    }

                    // Media outputs
                    if let result = state.generationResult {
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, state.generationState == .completed ? 4 : 16)
            }
            .background(Color.bg900.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .bottom)))

        case .error(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.error)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.error)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        default:
            EmptyView()
        }
    }

    private var textResult: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkdownTextView(text: state.streamedText)

            if state.generationState == .streaming {
                StreamingCursor()
            }
        }
    }
    @State private var showCopied = false

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(state.streamedText, forType: .string)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopied = true
            }
            NSSound(named: "Tink")?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                Text(showCopied ? "Copied" : "Copy")
                    .font(.system(size: 11))
            }
            .foregroundStyle(showCopied ? Color.success : Color.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.bg800.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

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
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            } else if let url = URL(string: value) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    case .failure:
                        Label("Failed to load image", systemImage: "photo")
                            .foregroundStyle(Color.textMuted)
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
        ForEach(output.values, id: \.self) { value in
            if let url = URL(string: value) {
                VideoPlayerView(url: url)
            }
        }
    }

    @ViewBuilder
    private var metricsBar: some View {
        HStack(spacing: 16) {
            if let metrics = state.streamingMetrics {
                metricPill(label: "TTFT", value: String(format: "%.0fms", (metrics.firstTokenTime ?? 0) * 1000))
                metricPill(label: "Speed", value: String(format: "%.1f tok/s", metrics.tokensPerSecond))
                metricPill(label: "Tokens", value: "\(metrics.tokenCount)")
                metricPill(label: "Total", value: String(format: "%.2fs", metrics.totalDuration))
            } else if let result = state.generationResult {
                metricPill(label: "Time", value: String(format: "%.2fs", result.duration))
                if result.pollCount > 0 {
                    metricPill(label: "Polls", value: "\(result.pollCount)")
                }
            }
        }
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.4), value: state.generationState == .completed)
    }

    private func metricPill(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.textMuted)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.textTertiary)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Helpers

    private func dataFromDataURL(_ dataURL: String) -> Data? {
        guard let commaIndex = dataURL.firstIndex(of: ",") else { return nil }
        let base64 = String(dataURL[dataURL.index(after: commaIndex)...])
        return Data(base64Encoded: base64)
    }
}

// MARK: - Streaming Cursor

private struct StreamingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Color.accent)
            .frame(width: 8, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
