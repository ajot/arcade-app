import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        TabView(selection: $state.settingsTab) {
            GeneralSettingsTab(state: state)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(AppState.SettingsTab.general)

            APIKeysSettingsTab(state: state)
                .tabItem {
                    Label("API Keys", systemImage: "key")
                }
                .tag(AppState.SettingsTab.apiKeys)
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - General Settings

private struct GeneralSettingsTab: View {
    @Bindable var state: AppState
    @State private var isMuted = SoundService.isMuted

    private let accentOptions: [(name: String, color: Color)] = [
        ("amber", Color(red: 0.961, green: 0.620, blue: 0.043)),
        ("blue", .blue),
        ("purple", .purple),
        ("green", .green),
        ("red", .red),
        ("orange", .orange),
        ("pink", .pink),
    ]

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $state.appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }

                HStack {
                    Text("Accent Color")
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(accentOptions, id: \.name) { option in
                            Circle()
                                .fill(option.color)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.primary.opacity(state.accentColorName == option.name ? 0.4 : 0), lineWidth: 2)
                                        .padding(-2)
                                )
                                .onTapGesture {
                                    state.accentColorName = option.name
                                }
                        }
                    }
                }
            }

            Section("Sound") {
                Toggle(isOn: $isMuted) {
                    HStack(spacing: 10) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(isMuted ? Color.secondary : Color.accentColor)
                            .frame(width: 20)
                            .contentTransition(.symbolEffect(.replace))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mute all sounds")

                            Text("Disable UI feedback sounds throughout the app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: isMuted) { _, newValue in
                    SoundService.isMuted = newValue
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - API Keys Settings

private struct APIKeysSettingsTab: View {
    @Bindable var state: AppState
    @State private var editingProvider: String?
    @State private var keyInput: String = ""
    @State private var saveConfirmation: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Manage your API keys for each provider")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Validate All") {
                    state.validateAllKeys()
                }
                .font(.subheadline)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(state.definitionLoader.providers, id: \.slug) { provider in
                        providerRow(slug: provider.slug, displayName: provider.displayName)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func providerRow(slug: String, displayName: String) -> some View {
        let status = state.keyStatus[slug] ?? .noKey
        let hasKey = KeychainService.getKey(for: slug) != nil
        let isEditing = editingProvider == slug
        let iconUrl = state.definitionLoader.sortedDefinitions.first { $0.provider == slug }?.providerIconUrl

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                ProviderIconView(
                    provider: slug,
                    displayName: displayName,
                    iconUrl: iconUrl,
                    iconService: state.iconService
                )

                Image(systemName: status.iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(status.color)
                    .frame(width: 16)

                Text(displayName)
                    .font(.system(size: 13))

                Spacer()

                if saveConfirmation == slug {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if isEditing {
                    // Save/Cancel shown below
                } else if hasKey {
                    HStack(spacing: 8) {
                        Text("\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        Button("Edit") {
                            editingProvider = slug
                            keyInput = ""
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Button {
                            KeychainService.deleteKey(for: slug)
                            state.keyStatus[slug] = .noKey
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button("Add Key") {
                        editingProvider = slug
                        keyInput = ""
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if isEditing {
                HStack(spacing: 8) {
                    TextField("Paste API key...", text: $keyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                    Button("Save") {
                        saveKey(provider: slug)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Cancel") {
                        editingProvider = nil
                        keyInput = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
            state.validateKey(for: provider)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                saveConfirmation = provider
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    saveConfirmation = nil
                }
            }

            SoundService.keySaved()
        } catch {
            // Key save failed
        }
    }
}
