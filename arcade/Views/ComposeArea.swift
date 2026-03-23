import SwiftUI

struct ComposeArea: View {
    @Bindable var state: AppState
    let isMultiTab: Bool
    let isGenerating: Bool
    let placeholder: String
    @Binding var promptText: String
    let onSend: (_ sendToAll: Bool) -> Void
    let onCancel: () -> Void
    let onModelSelect: (Definition, String) -> Void

    @State private var showModelPicker = false
    @State private var sendToAllTabs = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Model pill row
            modelPillRow

            // Text input
            TextField(placeholder, text: $promptText, axis: .vertical)
                .lineLimit(3...10)
                .textFieldStyle(.plain)
                .font(.system(size: DS.Font.body))
                .focused($isInputFocused)

            // Bottom row
            bottomRow
        }
        .padding(DS.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(lineWidth: 1)
                .foregroundStyle(isInputFocused ? AnyShapeStyle(Color.accentColor.opacity(0.5)) : AnyShapeStyle(.quaternary))
        )
        .shadow(
            color: isInputFocused ? Color.accentColor.opacity(0.15) : .clear,
            radius: 8,
            y: 0
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onChange(of: state.showModelPicker) { _, newValue in
            if newValue {
                showModelPicker = true
                state.showModelPicker = false
            }
        }
    }

    // MARK: - Model Pill Row

    @ViewBuilder
    private var modelPillRow: some View {
        modelPill
    }

    @ViewBuilder
    private var modelPill: some View {
        let providerName = state.currentDefinition?.providerDisplayName ?? "Provider"
        let modelName = state.currentModel ?? "Model"

        Button {
            showModelPicker.toggle()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(providerName)
                    .foregroundStyle(.primary.opacity(0.5))
                Text("\u{00B7}")
                    .foregroundStyle(.primary.opacity(0.5))
                Text(modelName)
                    .foregroundStyle(.primary)
                Text("\u{25BE}")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: DS.Font.secondary, weight: .medium))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                showModelPicker
                    ? Color.accentColor.opacity(0.1)
                    : Color.clear
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(lineWidth: 0.5)
                    .foregroundStyle(showModelPicker ? AnyShapeStyle(Color.accentColor.opacity(0.3)) : AnyShapeStyle(.quaternary))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showModelPicker, arrowEdge: .bottom) {
            ModelPicker(
                state: state,
                onSelect: { definition, model in
                    onModelSelect(definition, model)
                    showModelPicker = false
                },
                onDismiss: {
                    showModelPicker = false
                }
            )
        }
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack {
            if isMultiTab {
                Toggle("Send to all tabs", isOn: $sendToAllTabs)
                    .toggleStyle(.checkbox)
                    .font(.system(size: DS.Font.secondary))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Keyboard shortcut hint
            Text(isGenerating ? "esc" : "\u{2318}\u{21B5}")
                .font(.system(size: DS.Font.caption, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.trailing, DS.Spacing.sm)

            // Send / Stop button
            Button {
                if isGenerating {
                    onCancel()
                } else {
                    onSend(isMultiTab && sendToAllTabs)
                }
            } label: {
                Image(systemName: isGenerating ? "stop.fill" : "play.fill")
                    .font(.system(size: DS.Font.secondary))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        isGenerating
                            ? Color.red
                            : (promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray
                                : Color.accentColor),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isGenerating && promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
