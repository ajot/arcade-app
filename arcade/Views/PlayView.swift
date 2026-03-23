import SwiftUI

struct PlayView: View {
    @Bindable var state: AppState
    @State private var appeared = false
    // showInspector lives on AppState for Cmd+I shortcut access
    @State private var showCurlPopover = false
    @State private var curlShowKey = false
    @State private var curlCopied = false
    @State private var showBookmarkPopover = false
    @State private var bookmarkLabel = ""
    @State private var bookmarkSaved = false
    @State private var errorShakeCount: Int = 0

    @ViewBuilder
    var body: some View {
        if let definition = state.currentDefinition {
            VStack(spacing: 0) {
                // Comparison tabs (only in compare mode)
                if state.isCompareMode {
                    ComparisonTabs(state: state)
                }

                // Zone 1: Result area (scrollable, grows upward)
                ScrollView {
                    Spacer()
                        .frame(maxHeight: .infinity)

                    resultContent(definition)
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.top, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.lg)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                }
                .defaultScrollAnchor(.bottom)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.isCompareMode
                    ? (state.tabs[safe: state.activeTabIndex]?.generationState ?? .idle)
                    : state.generationState)

                // Secondary params strip (sliders, dropdowns — NOT the chat prompt)
                let secondaryParams = definition.regularParams.filter {
                    $0.bodyPath != "_chat_message" && $0.bodyPath != "_system_prompt"
                }
                if !secondaryParams.isEmpty {
                    secondaryParamsStrip(secondaryParams)
                }

                // Zone 2: Compose area (fixed at bottom, never scrolls)
                if definition.isChatEndpoint {
                    ComposeArea(
                        state: state,
                        isMultiTab: state.isCompareMode,
                        isGenerating: state.isCompareMode
                            ? state.tabs.contains(where: { isActive($0.generationState) })
                            : isActive(state.generationState),
                        placeholder: composePlaceholder(definition),
                        promptText: promptBinding(definition),
                        onSend: { sendToAll in
                            if state.isCompareMode && sendToAll {
                                state.generateAllTabs()
                            } else if state.isCompareMode {
                                state.generateTab(at: state.activeTabIndex)
                            } else {
                                state.generate()
                            }
                        },
                        onCancel: { state.cancelGeneration() },
                        onModelSelect: { def, model in
                            state.selectEndpoint(def, model: model)
                        }
                    )
                    .padding(.horizontal, DS.Spacing.xxl)
                    .padding(.bottom, DS.Spacing.lg)
                }

                // Zone 3: Examples (below compose, fade when typing)
                if !definition.examples.isEmpty {
                    exampleChips(definition)
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.bottom, DS.Spacing.lg)
                        .opacity(hasPromptText ? 0.15 : 1.0)
                        .animation(.easeOut(duration: 0.2), value: hasPromptText)
                }
            }
            .inspector(isPresented: $state.showInspector) {
                inspectorContent(definition)
            }
            .inspectorColumnWidth(min: 220, ideal: 260, max: 320)
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
            .onChange(of: state.showBookmarkPopover) { _, show in
                if show {
                    bookmarkLabel = suggestedBookmarkLabel(definition)
                    showBookmarkPopover = true
                    state.showBookmarkPopover = false
                }
            }
            .onChange(of: state.showCurlPopover) { _, show in
                if show {
                    showCurlPopover = true
                    state.showCurlPopover = false
                }
            }
            .popover(isPresented: $showCurlPopover) {
                curlPopoverContent(definition)
            }
            .popover(isPresented: $showBookmarkPopover) {
                bookmarkPopoverContent
            }
        }
    }

    // MARK: - Result Content

    @ViewBuilder
    private func resultContent(_ definition: Definition) -> some View {
        let genState = state.isCompareMode
            ? (state.tabs[safe: state.activeTabIndex]?.generationState ?? .idle)
            : state.generationState
        let streamText = state.isCompareMode
            ? (state.tabs[safe: state.activeTabIndex]?.streamedText ?? "")
            : state.streamedText
        let metrics = state.isCompareMode
            ? state.tabs[safe: state.activeTabIndex]?.streamingMetrics
            : state.streamingMetrics

        switch genState {
        case .streaming where !streamText.isEmpty:
            ResultCard(state: state)

        case .completed:
            ResultCard(state: state)

            // Performance stamps (only for streaming results with metrics)
            if let metrics {
                StampsRow(
                    ttft: metrics.firstTokenTime.map { String(format: "%.0fms", $0 * 1000) },
                    speed: String(format: "%.1f tok/s", metrics.tokensPerSecond),
                    tokens: "\(metrics.tokenCount)",
                    total: String(format: "%.1fs", metrics.totalDuration),
                    ttftFast: (metrics.firstTokenTime ?? .infinity) < 0.1,
                    speedFast: metrics.tokensPerSecond > 100
                )
                .padding(.top, DS.Spacing.sm)
            }

        case .error(let message):
            errorCard(message: message)
                .modifier(ShakeEffect(shakes: errorShakeCount))
                .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
                .onAppear {
                    withAnimation(.linear(duration: 0.4)) {
                        errorShakeCount += 3
                    }
                }

        default:
            emptyStateView(definition)
        }
    }

    // MARK: - Empty State

    private func emptyStateView(_ definition: Definition) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: definition.outputType.iconName)
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
                .opacity(0.4)

            Text("Your response will appear here")
                .font(.system(size: DS.Font.body))
                .foregroundStyle(.tertiary)

            Text("\u{2318}\u{21B5} to generate")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xxl)
    }

    // MARK: - Helpers

    private var hasPromptText: Bool {
        let chatParam = state.currentDefinition?.regularParams.first { $0.bodyPath == "_chat_message" }
        guard let paramName = chatParam?.name else { return false }
        return !(state.formValues[paramName]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private func composePlaceholder(_ definition: Definition) -> String {
        switch definition.outputType {
        case .image: return "Describe your image..."
        case .audio: return "Enter text to speak..."
        default: return "Ask anything..."
        }
    }

    private func promptBinding(_ definition: Definition) -> Binding<String> {
        let chatParam = definition.regularParams.first { $0.bodyPath == "_chat_message" }
        let paramName = chatParam?.name ?? ""
        return Binding(
            get: { state.formValues[paramName] ?? "" },
            set: { state.formValues[paramName] = $0 }
        )
    }

    // MARK: - Secondary Params Strip

    private func secondaryParamsStrip(_ params: [ParamDefinition]) -> some View {
        VStack(spacing: DS.Spacing.sm + 2) {
            ForEach(params, id: \.name) { param in
                paramField(param, isPrimary: false)
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.lg)
    }

    // MARK: - Examples

    @State private var chipsAppeared = false

    private func exampleChips(_ definition: Definition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Examples")
                .font(.system(size: DS.Font.secondary, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)

            FlowLayout(spacing: 6) {
                ForEach(Array(definition.examples.enumerated()), id: \.element.id) { index, example in
                    Button(example.label) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            state.fillExample(example)
                        }
                        SoundService.confirm()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                    .opacity(chipsAppeared ? 1 : 0)
                    .offset(y: chipsAppeared ? 0 : 6)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.65).delay(Double(index) * 0.08),
                        value: chipsAppeared
                    )
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                chipsAppeared = true
            }
        }
        .onChange(of: state.currentDefinition?.id) {
            chipsAppeared = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                chipsAppeared = true
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(param.name)
                    .font(.system(size: DS.Font.secondary, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                if param.isRequired {
                    Text("*")
                        .font(.system(size: DS.Font.secondary))
                        .foregroundStyle(Color.accentColor)
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
            .font(.system(size: DS.Font.body))
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: isPrimary ? 60 : 40)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .overlay(alignment: .leading) {
                if isPrimary {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2.5)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .padding(.vertical, 5)
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
        .tint(.primary)
        .fixedSize()
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
                .tint(.accentColor)
                .frame(width: 200)

            Text(state.formValues[param.name] ?? param.defaultDisplayString ?? "")
                .font(.system(size: DS.Font.secondary, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()

            Spacer()
        }
    }

    private func textField(_ param: ParamDefinition) -> some View {
        let binding = Binding<String>(
            get: { state.formValues[param.name] ?? "" },
            set: { state.formValues[param.name] = $0 }
        )

        return TextField(param.placeholder ?? "", text: binding)
            .textFieldStyle(.roundedBorder)
    }

    // MARK: - Inspector

    private func inspectorContent(_ definition: Definition) -> some View {
        Form {
            if !definition.advancedParams.isEmpty {
                Section("Settings") {
                    ForEach(definition.advancedParams) { param in
                        inspectorParamField(param)
                    }
                }
            }

            if definition.isChatEndpoint {
                Section("System Prompt") {
                    TextEditor(text: $state.systemPrompt)
                        .font(.system(size: DS.Font.secondary))
                        .frame(minHeight: 80)
                }
            }

            if definition.advancedParams.isEmpty && !definition.isChatEndpoint {
                Section {
                    VStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: DS.Font.display))
                            .foregroundStyle(.secondary)
                        Text("No settings for this endpoint")
                            .font(.system(size: DS.Font.secondary))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func inspectorParamField(_ param: ParamDefinition) -> some View {
        let label = param.displayName

        return Group {
            switch param.ui {
            case .dropdown:
                Picker(label, selection: Binding<String>(
                    get: { state.formValues[param.name] ?? param.defaultDisplayString ?? "" },
                    set: { state.formValues[param.name] = $0 }
                )) {
                    if let options = param.options {
                        ForEach(options, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

            case .slider:
                let minVal = param.min ?? 0
                let maxVal = param.max ?? 100
                let step = param.type == .integer ? 1.0 : 0.1
                let binding = Binding<Double>(
                    get: { Double(state.formValues[param.name] ?? "") ?? param.defaultValue?.doubleValue ?? minVal },
                    set: {
                        if param.type == .integer {
                            state.formValues[param.name] = "\(Int($0))"
                        } else {
                            state.formValues[param.name] = String(format: "%.1f", $0)
                        }
                    }
                )
                HStack {
                    Text(label)
                    Spacer()
                    Text(state.formValues[param.name] ?? param.defaultDisplayString ?? "")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: binding, in: minVal...maxVal, step: step)

            case .text:
                TextField(label, text: Binding<String>(
                    get: { state.formValues[param.name] ?? "" },
                    set: { state.formValues[param.name] = $0 }
                ))

            case .textarea:
                TextField(label, text: Binding<String>(
                    get: { state.formValues[param.name] ?? "" },
                    set: { state.formValues[param.name] = $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }
        }
    }

    private func isActive(_ genState: AppState.GenerationState) -> Bool {
        switch genState {
        case .generating, .streaming, .polling: return true
        default: return false
        }
    }

    private func patternLabel(_ definition: Definition) -> String {
        let pattern = definition.interaction.pattern
        switch pattern {
        case .polling:
            let method = definition.interaction.pollMethod?.uppercased() ?? "GET"
            return "async \u{00B7} \(method) polling"
        case .streaming:
            return "streaming"
        case .sync:
            return "sync"
        }
    }

    // MARK: - Curl Popover

    private func curlPopoverContent(_ definition: Definition) -> some View {
        let apiKey = KeychainService.getKey(for: definition.provider)
        var params = state.formValues
        if let model = state.currentModel { params["model"] = model }
        if !state.systemPrompt.isEmpty { params["_system_prompt"] = state.systemPrompt }

        let curlString = (try? RequestBuilder.buildCurlString(
            definition: definition, params: params,
            includeKey: curlShowKey, apiKey: apiKey
        )) ?? "# Could not build curl command"

        return VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Toggle(isOn: $curlShowKey) {
                    Text("Show API key")
                        .font(.system(size: DS.Font.secondary))
                        .foregroundStyle(.tertiary)
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(curlString, forType: .string)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        curlCopied = true
                    }
                    SoundService.confirm()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { curlCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: curlCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: DS.Font.caption))
                        Text(curlCopied ? "Copied" : "Copy")
                            .font(.system(size: DS.Font.secondary))
                    }
                    .foregroundStyle(curlCopied ? Color.green : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Curl command
            ScrollView([.horizontal, .vertical]) {
                Text(curlString)
                    .font(.system(size: DS.Font.secondary, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .padding(12)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 520)
    }

    // MARK: - Bookmark Popover

    private var bookmarkPopoverContent: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: DS.Font.secondary))
                    .foregroundStyle(Color.accentColor)
                Text("Save Bookmark")
                    .font(.system(size: DS.Font.body, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
            }

            TextField("Label", text: $bookmarkLabel)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: DS.Font.body))

            HStack {
                Spacer()
                Button("Cancel") {
                    showBookmarkPopover = false
                }
                .buttonStyle(.bordered)

                Button {
                    saveBookmark()
                } label: {
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(width: 280)
        .onSubmit {
            saveBookmark()
        }
    }

    private func saveBookmark() {
        let label = bookmarkLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        state.saveBookmark(label: label)
        showBookmarkPopover = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            bookmarkSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                bookmarkSaved = false
            }
        }
    }

    private func suggestedBookmarkLabel(_ definition: Definition) -> String {
        let model = state.currentModel ?? ""
        let shortModel = model.split(separator: "/").last.map(String.init) ?? model
        if shortModel.isEmpty {
            return definition.name
        }
        return "\(definition.name) \u{2014} \(shortModel)"
    }

    // MARK: - Results (error card)

    @State private var errorExpanded = false

    private func errorCard(message: String) -> some View {
        let summary = errorSummary(message)
        let hasDetails = message.count > 80 || message.contains("\n")

        return HStack(alignment: .top, spacing: 0) {
            // Error accent bar
            RoundedRectangle(cornerRadius: DS.Radius.xs)
                .fill(.red)
                .frame(width: 2)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 10) {
                // Summary row
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: DS.Font.secondary))
                        .foregroundStyle(.red)
                        .padding(.top, 1)

                    Text(summary)
                        .font(.system(size: DS.Font.body))
                        .foregroundStyle(.red)
                        .lineLimit(errorExpanded ? nil : 2)

                    Spacer()

                    Button {
                        state.generate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: DS.Font.secondary))
                            Text("Retry")
                                .font(.system(size: DS.Font.secondary, weight: .medium))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(.red.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Expandable details
                if hasDetails {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            errorExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: DS.Font.caption, weight: .semibold))
                                .rotationEffect(.degrees(errorExpanded ? 90 : 0))
                            Text(errorExpanded ? "Hide details" : "Show details")
                                .font(.system(size: DS.Font.secondary))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if errorExpanded {
                        ScrollView {
                            Text(message)
                                .font(.system(size: DS.Font.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .padding(12)
                        .background(.quinary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.leading, 12)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.red.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func errorSummary(_ message: String) -> String {
        let firstLine = message.components(separatedBy: "\n").first ?? message
        if firstLine.count > 120 {
            return String(firstLine.prefix(120)) + "..."
        }
        return firstLine
    }

}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(animatableData * .pi * 2) * 10
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
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
