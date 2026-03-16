import SwiftUI

struct ContentView: View {
    @Bindable var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: Binding(
                get: { state.showSidebar ? .automatic : .detailOnly },
                set: { state.showSidebar = $0 != .detailOnly }
            )) {
                SidebarView(state: state)
            } detail: {
                detailContent
            }
            .navigationTitle(state.currentDefinition?.name ?? "arcade")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if let definition = state.currentDefinition {
                        // Key status — click opens Settings
                        let keyStatus = state.keyStatus[definition.provider] ?? .noKey
                        Button {
                            state.settingsTab = .apiKeys
                            openSettings()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: keyStatus.iconName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(keyStatus.color)
                                Text(definition.providerDisplayName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .help("Open API Key Settings")

                        // Inspector toggle
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                state.showInspector.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.trailing")
                        }
                        .help("Toggle Inspector (\u{2318}I)")
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
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            state.validateAllKeys()
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if state.currentDefinition != nil {
            VStack(spacing: 0) {
                PlayView(state: state)

                if state.showLogPanel {
                    LogPanel(state: state)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        } else {
            WelcomeView(state: state)
        }
    }
}

#Preview {
    ContentView(state: AppState())
}
