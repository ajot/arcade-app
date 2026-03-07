import SwiftUI

struct APIKeySettingsView: View {
    @Bindable var state: AppState
    @State private var editingProvider: String?
    @State private var keyInput: String = ""
    @State private var saveConfirmation: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("API Keys")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button("Validate All") {
                    state.validateAllKeys()
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .background(Color.border700)

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(state.definitionLoader.providers, id: \.slug) { provider in
                        providerRow(slug: provider.slug, displayName: provider.displayName)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 440, height: 500)
        .background(Color.bg900)
    }

    private func providerRow(slug: String, displayName: String) -> some View {
        let status = state.keyStatus[slug] ?? .noKey
        let hasKey = KeychainService.getKey(for: slug) != nil
        let isEditing = editingProvider == slug

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Status icon
                Image(systemName: status.iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(status.color)
                    .frame(width: 16)

                // Provider name
                Text(displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if saveConfirmation == slug {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.success)
                        .transition(.scale.combined(with: .opacity))
                } else if isEditing {
                    // Save/Cancel buttons shown below
                } else if hasKey {
                    HStack(spacing: 8) {
                        Text("\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textMuted)

                        Button("Edit") {
                            editingProvider = slug
                            keyInput = ""
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                        .buttonStyle(.plain)

                        Button {
                            KeychainService.deleteKey(for: slug)
                            state.keyStatus[slug] = .noKey
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button("Add Key") {
                        editingProvider = slug
                        keyInput = ""
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accent)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if isEditing {
                HStack(spacing: 8) {
                    TextField("Paste API key...", text: $keyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .inputFieldStyle()

                    Button("Save") {
                        saveKey(provider: slug)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.bg950)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .buttonStyle(.plain)

                    Button("Cancel") {
                        editingProvider = nil
                        keyInput = ""
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textMuted)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 46)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func saveKey(provider: String) {
        guard !keyInput.isEmpty else { return }
        do {
            try KeychainService.saveKey(keyInput, for: provider)
            editingProvider = nil
            keyInput = ""
            state.keyStatus[provider] = .unknown

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                saveConfirmation = provider
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    saveConfirmation = nil
                }
            }

            NSSound(named: "Purr")?.play()
        } catch {
            // Key save failed — silent for now
        }
    }
}
