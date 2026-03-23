import SwiftUI

struct ComparisonTabs: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 1) {
            // Tabs
            ForEach(Array(state.tabs.enumerated()), id: \.element.id) { index, tab in
                tabButton(tab, index: index)

                // Separator between tabs (not after last)
                if index < state.tabs.count - 1 {
                    Divider()
                        .frame(height: 16)
                        .opacity(0.3)
                }
            }

            // If no tabs yet (single model, not in compare mode), show current endpoint
            if state.tabs.isEmpty, let def = state.currentDefinition {
                singleTabLabel(def)
            }

            // + button — always visible
            Button {
                if !state.isCompareMode {
                    state.enterCompareMode()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.addTab()
                    }
                    state.paletteContext = .tabModelSelect(state.tabs.count - 1)
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.showCommandPalette = true
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Add model for comparison")

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.xs)
        .background(.bar)
    }

    // MARK: - Single Tab Label (not in compare mode)

    private func singleTabLabel(_ definition: Definition) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(definition.providerDisplayName)
                .foregroundStyle(.secondary)
            Text("\u{00B7}")
                .foregroundStyle(.tertiary)
            Text(state.currentModel ?? "")
                .foregroundStyle(.primary)
        }
        .font(.system(size: DS.Font.secondary, weight: .medium))
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.08))
        )
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: AppState.Tab, index: Int) -> some View {
        let isActive = index == state.activeTabIndex

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                state.selectTab(index)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(tab.definition.providerDisplayName)
                    .foregroundStyle(.secondary)
                    .opacity(isActive ? 0.8 : 0.5)

                Text("\u{00B7}")
                    .foregroundStyle(.tertiary)

                Text(tab.model)
                    .foregroundStyle(isActive ? Color.primary : .secondary)

                // Status dot
                tabStatusDot(tab.generationState)

                if state.tabs.count > 1 {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.removeTab(at: index)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                    .opacity(isActive ? 0.6 : 0)
                }
            }
            .font(.system(size: DS.Font.secondary, weight: .medium))
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isActive ? Color.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabStatusDot(_ genState: AppState.GenerationState) -> some View {
        switch genState {
        case .streaming, .generating, .polling:
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .modifier(PulseModifier())

        case .completed:
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)

        case .error:
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)

        case .idle:
            EmptyView()
        }
    }
}

private struct PulseModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing ? 0.3 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}
