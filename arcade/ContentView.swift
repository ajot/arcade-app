import SwiftUI

struct ContentView: View {
    @State private var state = AppState()
    @State private var showSettings = false
    @State private var keyMonitor: Any?

    var body: some View {
        ZStack {
            // Background
            Color.bg950
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                TopBar(state: state)

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
        .onAppear {
            state.validateAllKeys()
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.showCommandPalette.toggle()
                    }
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        .sheet(isPresented: $showSettings) {
            APIKeySettingsView(state: state)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "key")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .help("API Key Settings")
            }
        }
    }
}

#Preview {
    ContentView()
}
