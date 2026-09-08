import SwiftUI

struct ContentView: View {
    @StateObject private var githubConnection = GitHubConnection()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var browserSession = BrowserSession()

    init(
    ) {
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                connection: githubConnection,
                onOpenPullRequest: openPullRequest
            )
                .toolbar(
                    removing: columnVisibility == .detailOnly
                        ? .sidebarToggle
                        : nil
                )
        } detail: {
            MainView(browserSession: browserSession)
                .ignoresSafeArea(.container, edges: .top)
        }
        .containerBackground(.ultraThinMaterial, for: .window)
        .toolbar {
            if columnVisibility == .detailOnly {
                sidebarToggleItem
            }
        }
        .task {
            await githubConnection.refreshPeriodically()
        }
    }

    @ToolbarContentBuilder
    private var sidebarToggleItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ControlButton(
                title: sidebarButtonTitle,
                systemImage: "sidebar.left",
                action: toggleSidebar
            )
        }
        .sharedBackgroundVisibility(.hidden)
    }

    private var sidebarButtonTitle: String {
        columnVisibility == .detailOnly ? "Show Sidebar" : "Hide Sidebar"
    }

    private func toggleSidebar() {
        withAnimation {
            columnVisibility = columnVisibility == .detailOnly
                ? .all
                : .detailOnly
        }
    }

    private func openPullRequest(_ pullRequest: PullRequest) {
        browserSession.open(pullRequest.url)
    }
}

#if DEBUG
#Preview("Dailyglow") {
    ContentView()
}
#endif
