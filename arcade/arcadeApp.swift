import SwiftUI

@main
struct ArcadeApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .preferredColorScheme(state.preferredColorScheme)
                .tint(state.accentColor)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(before: .sidebar) {
                Button("Command Palette") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.showCommandPalette.toggle()
                    }
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button(state.showSidebar ? "Hide Sidebar" : "Show Sidebar") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.showSidebar.toggle()
                    }
                }
                .keyboardShortcut("0", modifiers: .command)

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
                .disabled(state.currentDefinition == nil)

                Divider()

                Button("Generate") {
                    if state.currentDefinition != nil {
                        state.generate()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(state.currentDefinition == nil)

                Button("Switch Model") {
                    state.paletteContext = .modelSelect
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.showCommandPalette = true
                    }
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(state.currentDefinition == nil)

                Button("Copy cURL") {
                    if state.currentDefinition != nil {
                        state.showCurlPopover = true
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(state.currentDefinition == nil)

                Divider()

                Button("Save Bookmark") {
                    if state.currentDefinition != nil {
                        state.showBookmarkPopover = true
                    }
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(state.currentDefinition == nil)

                Divider()
            }
        }

        Settings {
            SettingsView(state: state)
        }
    }
}
