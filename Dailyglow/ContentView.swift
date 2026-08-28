import SwiftUI

struct ContentView: View {
    @StateObject private var githubConnection: GitHubConnection
    @State private var selectedPullRequestID: GitHubPullRequest.ID?
    @State private var githubNavigationRequest: GitHubNavigationRequest?

    private let connectsOnAppear: Bool
    private let startsBrowserAtHome: Bool

    init(
        githubConnection: GitHubConnection = GitHubConnection(),
        connectsOnAppear: Bool = true,
        startsBrowserAtHome: Bool = true
    ) {
        _githubConnection = StateObject(wrappedValue: githubConnection)
        self.connectsOnAppear = connectsOnAppear
        self.startsBrowserAtHome = startsBrowserAtHome
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                connection: githubConnection,
                selectedPullRequestID: $selectedPullRequestID,
                onOpenPullRequest: openPullRequest
            )
            .task {
                guard connectsOnAppear else { return }
                await githubConnection.connect()
            }
        } detail: {
            GitHubWebView(
                navigationRequest: githubNavigationRequest,
                startsAtHome: startsBrowserAtHome
            )
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .ignoresSafeArea(.container, edges: .top)
    }

    private func openPullRequest(_ pullRequest: GitHubPullRequest) {
        githubNavigationRequest = GitHubNavigationRequest(url: pullRequest.url)
    }
}

#if DEBUG
#Preview("Dailyglow") {
    ContentView(
        githubConnection: GitHubConnection.preview(),
        connectsOnAppear: false,
        startsBrowserAtHome: false
    )
    .frame(width: 1_000, height: 720)
}
#endif
