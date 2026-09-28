import SwiftUI

@main
struct DailyglowApp: App {
    var body: some Scene {
        Window("Dailyglow", id: "main") {
            ContentView()
        }
        .defaultSize(width: 800, height: 800)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }
}
