import SwiftUI
import UniformTypeIdentifiers

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
    @State private var showRequestJSON = false
    @State private var showResponseJSON = false
    @State private var requestJSONCopied = false
    @State private var responseJSONCopied = false

    var body: some View {
        guard let definition = state.currentDefinition else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Endpoint header
                            endpointHeader(definition)
                                .padding(.bottom, 12)

                            // Examples
                            if !definition.examples.isEmpty {
                                exampleChips(definition)
                                    .padding(.bottom, 12)

                                Divider()
                                    .padding(.bottom, 12)
                            }

                            // Model picker
                            if let modelParam = definition.modelParam, let options = modelParam.options {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Model")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .tracking(0.3)

                                    Picker("", selection: Binding<String>(
                                        get: { state.currentModel ?? "" },
                                        set: { state.selectModel($0) }
                                    )) {
                                        ForEach(options, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(.primary)
                                    .fixedSize()
                                }
                                .padding(.bottom, 8)
                            }

                            Divider()
                                .padding(.bottom, 12)

                            // Form fields
                            formFields(definition)
                                .padding(.bottom, 12)

                            // Results
                            resultArea(definition)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.generationState)

                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
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

                // Fixed bottom bar
                generateBar(definition)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.bar)
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
                    showBookmarkPopover = true
                    state.showBookmarkPopover = false
                }
            }
        )
    }

    // MARK: - Header

    private func endpointHeader(_ definition: Definition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(definition.description)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Label(definition.outputType.rawValue, systemImage: definition.outputType.iconName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(patternLabel(definition))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Examples

    @State private var chipsAppeared = false

    private func exampleChips(_ definition: Definition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Examples")
                .font(.system(size: 11, weight: .medium))
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                chipsAppeared = true
            }
        }
        .onChange(of: state.currentDefinition?.id) {
            chipsAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                if param.isRequired {
                    Text("*")
                        .font(.system(size: 11))
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
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: isPrimary ? 60 : 40)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .overlay(alignment: .leading) {
                if isPrimary {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2.5)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
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
                .font(.system(size: 12, design: .monospaced))
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
                        .font(.system(size: 12))
                        .frame(minHeight: 80)
                }
            }

            if definition.advancedParams.isEmpty && !definition.isChatEndpoint {
                Section {
                    VStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                        Text("No settings for this endpoint")
                            .font(.system(size: 11))
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

    // MARK: - Generate Bar

    private func generateBar(_ definition: Definition) -> some View {
        HStack(spacing: 12) {
            // Log toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    state.showLogPanel.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.bottomthird.inset.filled")
                        .font(.system(size: 12))
                    if !state.logEntries.isEmpty && !state.showLogPanel {
                        Text("\(state.logEntries.count)")
                            .font(.system(size: 9, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quinary)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(state.showLogPanel ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Log (\u{2318}L)")

            Spacer()

            // Curl preview button
            Button {
                showCurlPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                    Text("curl")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showCurlPopover, arrowEdge: .bottom) {
                curlPopoverContent(definition)
            }

            // Bookmark button
            Button {
                bookmarkLabel = suggestedBookmarkLabel(definition)
                showBookmarkPopover = true
            } label: {
                Image(systemName: bookmarkSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13))
                    .foregroundStyle(bookmarkSaved ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 32, height: 32)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .scaleEffect(bookmarkSaved ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .help("Save Bookmark (\u{2318}D)")
            .onChange(of: showBookmarkPopover) { _, show in
                if show {
                    bookmarkLabel = suggestedBookmarkLabel(definition)
                }
            }
            .popover(isPresented: $showBookmarkPopover, arrowEdge: .bottom) {
                bookmarkPopoverContent
            }

            // Generate button
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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

    private func patternLabel(_ definition: Definition) -> String {
        let pattern = definition.interaction.pattern
        switch pattern {
        case .polling:
            let method = definition.interaction.pollMethod?.uppercased() ?? "GET"
            return "async · \(method) polling"
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
                        .font(.system(size: 11))
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
                            .font(.system(size: 10))
                        Text(curlCopied ? "Copied" : "Copy")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(curlCopied ? Color.green : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
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
                    .font(.system(size: 11, design: .monospaced))
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
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentColor)
                Text("Save Bookmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
            }

            TextField("Label", text: $bookmarkLabel)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

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
        return "\(definition.name) — \(shortModel)"
    }

    // MARK: - Results

    @ViewBuilder
    private func resultArea(_ definition: Definition) -> some View {
        switch state.generationState {
        case .streaming where state.streamedText.isEmpty && state.generationResult == nil:
            EmptyView()

        case .completed, .streaming:
            VStack(alignment: .leading, spacing: 0) {
                // Result toolbar
                if state.generationState == .completed {
                    HStack {
                        Spacer()
                        if hasImageOutput {
                            saveImageButton
                        }
                        if !state.streamedText.isEmpty {
                            copyButton
                        }
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

                    // Request/Response JSON
                    if state.generationState == .completed {
                        requestResponseSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, state.generationState == .completed ? 4 : 16)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.asymmetric(
                insertion: .scale(scale: 0.97, anchor: .top).combined(with: .opacity),
                removal: .opacity
            ))

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
            // Empty state placeholder
            VStack(spacing: 8) {
                Image(systemName: definition.outputType.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text("Your \(definition.outputType.rawValue) will appear here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
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
    @State private var errorExpanded = false
    @State private var showSaved = false

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(state.streamedText, forType: .string)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopied = true
            }
            SoundService.confirm()
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
            .foregroundStyle(showCopied ? Color.green : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var hasImageOutput: Bool {
        state.generationResult?.outputs.contains(where: { $0.type == .image }) ?? false
    }

    private var saveImageButton: some View {
        Button {
            saveImage()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showSaved ? "checkmark" : "arrow.down.circle")
                    .font(.system(size: 10))
                Text(showSaved ? "Saved" : "Save")
                    .font(.system(size: 11))
            }
            .foregroundStyle(showSaved ? Color.green : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func saveImage() {
        guard let result = state.generationResult,
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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

    private func errorCard(message: String) -> some View {
        let summary = errorSummary(message)
        let hasDetails = message.count > 80 || message.contains("\n")

        return HStack(alignment: .top, spacing: 0) {
            // Error accent bar
            RoundedRectangle(cornerRadius: 1)
                .fill(.red)
                .frame(width: 2)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 10) {
                // Summary row
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .padding(.top, 1)

                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .lineLimit(errorExpanded ? nil : 2)

                    Spacer()

                    Button {
                        state.generate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                            Text("Retry")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
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
                                .font(.system(size: 9, weight: .semibold))
                                .rotationEffect(.degrees(errorExpanded ? 90 : 0))
                            Text(errorExpanded ? "Hide details" : "Show details")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if errorExpanded {
                        ScrollView {
                            Text(message)
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .padding(10)
                        .background(.quinary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.leading, 12)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Request/Response JSON

    @ViewBuilder
    private var requestResponseSection: some View {
        VStack(spacing: 0) {
            // Request
            if let requestBody = state.lastRequestBody, let definition = state.currentDefinition {
                jsonDisclosure(
                    title: "Request",
                    subtitle: "\(definition.request.method) \(definition.request.url)",
                    json: requestBody,
                    isExpanded: $showRequestJSON,
                    isCopied: $requestJSONCopied
                )
            }

            // Response
            if let responseBody = state.lastResponseBody {
                let statusLabel: String = {
                    if let result = state.generationResult {
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
            } else if state.streamingMetrics != nil {
                // Streaming endpoints don't have a single JSON response
                let metrics = state.streamingMetrics!
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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                            .foregroundStyle(.secondary)

                        Text(title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if isExpanded.wrappedValue {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(json, forType: .string)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isCopied.wrappedValue = true
                        }
                        SoundService.confirm()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { isCopied.wrappedValue = false }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isCopied.wrappedValue ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9))
                            Text(isCopied.wrappedValue ? "Copied" : "Copy")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(isCopied.wrappedValue ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 8)

            // JSON body
            if isExpanded.wrappedValue {
                ScrollView([.horizontal, .vertical]) {
                    Text(json)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .padding(12)
                }
                .frame(maxHeight: 300)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
