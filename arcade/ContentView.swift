import SwiftUI

struct ContentView: View {
    @Bindable var state: AppState

    var body: some View {
        ZStack {
            // Background
            Color.bg950
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Main content
                switch state.mode {
                case .welcome:
                    WelcomeView(state: state)
                case .play:
                    PlayView(state: state)
                case .compare:
                    // Phase 5
                    Text("Compare mode coming soon")
                        .foregroundStyle(Color.textMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Log panel
                if state.showLogPanel {
                    LogPanel(state: state)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Log toggle (hidden in play mode — PlayView has its own in the bottom bar)
                if state.mode != .play {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                state.showLogPanel.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .bold))
                                    .rotationEffect(.degrees(state.showLogPanel ? 180 : 0))
                                Text("Log")
                                    .font(.system(size: 10))
                                if !state.logEntries.isEmpty && !state.showLogPanel {
                                    Text("\(state.logEntries.count)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.bg800)
                                        .clipShape(Capsule())
                                }
                            }
                            .foregroundStyle(Color.textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.bg900.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(Color.border700.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                    }
                }
            }

            // Command Palette overlay
            if state.showCommandPalette {
                CommandPalette(state: state)
                    .transition(.opacity)
            }

            // Image zoom overlay
            if state.zoomedImageValue != nil {
                ImageZoomOverlay(state: state)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                toolbarContent
            }
        }
        .animation(.easeOut(duration: 0.25), value: state.mode)
        .onAppear {
            state.validateAllKeys()
        }
    }

    // MARK: - Toolbar

    private var toolbarContent: some View {
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 10)

                Text(definition.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)

                if let modelParam = definition.modelParam, let options = modelParam.options {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textMuted)
                        .padding(.horizontal, 10)

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
                .padding(.trailing, 12)

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
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView(state: AppState())
}
