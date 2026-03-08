import SwiftUI

struct TopBar: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Brand / Home
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    state.goHome()
                }
            } label: {
                Text("arcade")
                    .font(.brand)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
            }
            .buttonStyle(.plain)

            if state.mode == .play, let definition = state.currentDefinition {
                // Separator
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 10)
                    .transition(.opacity)

                // Endpoint name
                Text(definition.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                // Model picker
                if let modelParam = definition.modelParam, let options = modelParam.options {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textMuted)
                        .padding(.horizontal, 10)
                        .transition(.opacity)

                    Menu {
                        ForEach(options, id: \.self) { model in
                            Button {
                                state.selectModel(model)
                            } label: {
                                if model == state.currentModel {
                                    Label(model, systemImage: "checkmark")
                                } else {
                                    Text(model)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(state.currentModel ?? "")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color.textMuted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.bg800.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.border700.opacity(0.4), lineWidth: 0.5)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .transition(.opacity)
                }

                Spacer()

                // Key status indicator
                let keyStatus = state.keyStatus[definition.provider] ?? .noKey
                HStack(spacing: 4) {
                    Image(systemName: keyStatus.iconName)
                        .font(.system(size: 10))
                        .foregroundStyle(keyStatus.color)
                    Text(definition.providerDisplayName)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))

                // Inspector toggle
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.showInspector.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.trailing")
                        .font(.system(size: 12))
                        .foregroundStyle(state.showInspector ? Color.accent : Color.textMuted)
                }
                .buttonStyle(.plain)
                .help("Toggle Inspector (\u{2318}I)")
                .padding(.leading, 12)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.bg950.opacity(0.8))
        .background(.ultraThinMaterial.opacity(0.3))
        .overlay(alignment: .bottom) {
            Divider().background(Color.border700.opacity(0.5))
        }
        .animation(.easeOut(duration: 0.25), value: state.mode)
    }
}
