import SwiftUI

@main
struct DailyglowApp: App {
    @State private var incomingLink: WorkspaceLink?
    var body: some Scene {
        Window("Dailyglow", id: "main") {
            ContentView(incomingLink: incomingLink)
                .onOpenURL { url in
                    guard let link = WorkspaceLink(url: url) else { return }
                    incomingLink = link
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 800, height: 800)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }
}
