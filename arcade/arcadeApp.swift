import SwiftUI

@main
struct ArcadeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
