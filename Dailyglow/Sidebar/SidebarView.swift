import SwiftUI

struct SidebarView: View {
    @ObservedObject var connection: GitHubConnection
    let onOpenPullRequest: (PullRequest) -> Void

    init(
        connection: GitHubConnection,
        onOpenPullRequest: @escaping (PullRequest) -> Void = { _ in }
    ) {
        self.connection = connection
        self.onOpenPullRequest = onOpenPullRequest
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                pullRequestsSection

                SidebarSectionHeader(
                    title: "Quick Links",
                    leadingImage: "GitBookmark"
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
        }
        .navigationTitle("Dailyglow")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
    }

    private var pullRequestsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SidebarSectionHeader(
                title: "Inbox",
                leadingImage: "GitInbox",
                actionTitle: "Refresh Pull Requests",
                systemImage: "arrow.clockwise",
                isWorking: isRefreshing,
                action: refreshPullRequests
            )

            SidebarSubsectionHeader(title: "Open")

            if connection.isLoadingPullRequests && pullRequestIDs.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    SidebarPullRequestLoadingRow()
                        .transition(.opacity)
                }
            } else {
                pullRequestRows(openPullRequests)
            }

            SidebarSubsectionHeader(title: "Drafts")
                .padding(.top, 6)

            if !connection.isLoadingPullRequests || !pullRequestIDs.isEmpty {
                pullRequestRows(draftPullRequests)
            }
        }
        .animation(.easeOut(duration: 0.24), value: pullRequestIDs)
    }

    @ViewBuilder
    private func pullRequestRows(
        _ pullRequests: [PullRequest]
    ) -> some View {
        ForEach(pullRequests) { pullRequest in
            SidebarPullRequestRow(
                pullRequest: pullRequest,
                onOpen: { onOpenPullRequest(pullRequest) }
            )
            .transition(
                .opacity.combined(with: .offset(y: -4))
            )
        }
    }

    private var allPullRequests: [PullRequest] {
        let inbox = connection.pullRequestInbox
        var seenURLs = Set<URL>()

        return (
            inbox.open.pullRequests
                + inbox.drafts
                + inbox.needsYourReview
        )
        .filter { seenURLs.insert($0.url).inserted }
    }

    private var openPullRequests: [PullRequest] {
        allPullRequests
            .filter { !$0.isDraft }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var draftPullRequests: [PullRequest] {
        allPullRequests
            .filter(\.isDraft)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var isRefreshing: Bool {
        connection.isLoadingPullRequests
    }

    private var pullRequestIDs: [PullRequest.ID] {
        (openPullRequests + draftPullRequests).map(\.id)
    }

    private func refreshPullRequests() {
        Task {
            await connection.connect()
        }
    }
}

#if DEBUG
#Preview("Sidebar") {
    SidebarView(connection: GitHubConnection())
        .frame(width: 260, height: 500)
}
#endif
