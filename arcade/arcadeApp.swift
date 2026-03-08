import SwiftUI

@main
struct ArcadeApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("View") {
                Button("Command Palette") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.showCommandPalette.toggle()
                    }
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button(state.showLogPanel ? "Hide Log" : "Show Log") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.showLogPanel.toggle()
                    }
                }
                .keyboardShortcut("l", modifiers: .command)

                Button(state.showInspector ? "Hide Inspector" : "Show Inspector") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.showInspector.toggle()
                    }
                }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(state.mode != .play)

                Divider()

                Button("Save Bookmark") {
                    if state.mode == .play {
                        state.showBookmarkPopover = true
                    }
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(state.mode != .play)
            }
        }

        Settings {
            SettingsView(state: state)
        }
    }
}
