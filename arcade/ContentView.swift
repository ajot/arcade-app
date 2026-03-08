import SwiftUI

struct ContentView: View {
    @Bindable var state: AppState
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

                // Log panel
                if state.showLogPanel {
                    LogPanel(state: state)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Log toggle
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
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "l" {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.showLogPanel.toggle()
                    }
                    return nil
                }
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d" {
                    if state.mode == .play {
                        state.showBookmarkPopover = true
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
    }
}

#Preview {
    ContentView(state: AppState())
}
