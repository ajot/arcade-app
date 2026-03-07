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

                // Endpoint name
                Text(definition.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)

                // Model picker
                if let modelParam = definition.modelParam, let options = modelParam.options {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textMuted)
                        .padding(.horizontal, 10)

                    Picker("", selection: Binding(
                        get: { state.currentModel ?? "" },
                        set: { state.selectModel($0) }
                    )) {
                        ForEach(options, id: \.self) { model in
                            Text(model)
                                .font(.system(size: 12))
                                .tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 200)
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
    }
}
