import AppKit
import SwiftUI

struct SidebarView: View {
    @ObservedObject var connection: GitHubConnection
    @Binding var selectedPullRequestID: GitHubPullRequest.ID?

    let onOpenPullRequest: (GitHubPullRequest) -> Void

    var body: some View {
        List {
            Section {
                HStack {
                    SidebarMenuLabel(item: .pullRequests)

                    Spacer()

                    if !connection.openPullRequests.isEmpty {
                        Text("\(connection.openPullRequests.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                pullRequestRows

                ForEach(SidebarItem.workspaceItems) { item in
                    SidebarMenuLabel(item: item)
                }
            }

            Section {
                SidebarMenuLabel(item: .settings)
            }

            Section("GitHub API") {
                GitHubConnectionRow(connection: connection)
            }
        }
        .navigationTitle("Dailyglow")
        .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 380)
    }

    @ViewBuilder
    private var pullRequestRows: some View {
        if !connection.openPullRequests.isEmpty {
            ForEach(pullRequestSections) { section in
                HStack {
                    Text(section.title)
                        .font(.caption.weight(.semibold))

                    Spacer()

                    Text("\(section.pullRequests.count)")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 26)
                .padding(.trailing, 8)
                .padding(.top, 4)

                ForEach(section.pullRequests) { pullRequest in
                    Button {
                        selectedPullRequestID = pullRequest.id
                        onOpenPullRequest(pullRequest)
                    } label: {
                        SidebarPullRequestRow(
                            pullRequest: pullRequest,
                            isSelected: selectedPullRequestID == pullRequest.id
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 18)
                    .contextMenu {
                        Button("Copy Link", systemImage: "doc.on.doc") {
                            copyLink(for: pullRequest)
                        }
                    }
                }

                if section.id != pullRequestSections.last?.id {
                    Divider()
                        .padding(.leading, 26)
                        .padding(.vertical, 2)
                }
            }
        } else if let errorMessage = connection.pullRequestError {
            VStack(alignment: .leading, spacing: 6) {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Button("Try Again") {
                    Task {
                        await connection.connect()
                    }
                }
                .buttonStyle(.link)
            }
        } else {
            switch connection.state {
            case .idle, .connecting:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                }

            case .connected:
                Text("No open pull requests")
                    .foregroundStyle(.secondary)

            case .failed(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private var pullRequestSections: [PullRequestSection] {
        let newestFirst: (GitHubPullRequest, GitHubPullRequest) -> Bool = {
            $0.updatedAt > $1.updatedAt
        }

        return [
            PullRequestSection(
                id: "open",
                title: "Open",
                pullRequests: connection.openPullRequests
                    .filter {
                        !$0.isDraft && $0.reviewDecision != .approved
                    }
                    .sorted(by: newestFirst)
            ),
            PullRequestSection(
                id: "approved",
                title: "Approved",
                pullRequests: connection.openPullRequests
                    .filter {
                        !$0.isDraft && $0.reviewDecision == .approved
                    }
                    .sorted(by: newestFirst)
            ),
            PullRequestSection(
                id: "drafts",
                title: "Drafts",
                pullRequests: connection.openPullRequests
                    .filter(\.isDraft)
                    .sorted(by: newestFirst)
            )
        ]
        .filter { !$0.pullRequests.isEmpty }
    }

    private func copyLink(for pullRequest: GitHubPullRequest) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            pullRequest.url.absoluteString,
            forType: .string
        )
    }
}

private struct PullRequestSection: Identifiable {
    let id: String
    let title: String
    let pullRequests: [GitHubPullRequest]
}

private struct SidebarPullRequestRow: View {
    let pullRequest: GitHubPullRequest
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            PullRequestStateIcon(isDraft: pullRequest.isDraft)
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(pullRequest.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("#" + String(pullRequest.number))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            PullRequestReviewIcon(
                reviewDecision: pullRequest.reviewDecision
            )
            .frame(width: 16)
            .padding(.top, 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(backgroundColor)
        }
        .contentShape(Rectangle())
        .onHover { isHovering in
            self.isHovering = isHovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.16)
        }

        if isHovering {
            return Color.primary.opacity(0.07)
        }

        return .clear
    }
}

private struct SidebarMenuLabel: View {
    let item: SidebarItem

    var body: some View {
        Label {
            Text(item.title)
                .foregroundStyle(.primary)
        } icon: {
            if item == .pullRequests {
                Image("GitPullRequest")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.accentColor)
            } else {
                Image(systemName: item.systemImage)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

private struct PullRequestStateIcon: View {
    let isDraft: Bool

    var body: some View {
        Image(isDraft ? "GitPullRequestDraft" : "GitPullRequest")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundStyle(isDraft ? Color.secondary : Color.green)
            .help(isDraft ? "Draft pull request" : "Open pull request")
            .accessibilityLabel(
                isDraft ? "Draft pull request" : "Open pull request"
            )
    }
}

private struct PullRequestReviewIcon: View {
    let reviewDecision: GitHubReviewDecision?

    var body: some View {
        switch reviewDecision {
        case .approved:
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .help("Approved")
                .accessibilityLabel("Approved")

        case .changesRequested:
            Image(systemName: "xmark")
                .foregroundStyle(.red)
                .help("Changes requested")
                .accessibilityLabel("Changes requested")

        case .reviewRequired:
            Image(systemName: "clock")
                .foregroundStyle(.orange)
                .help("Review required")
                .accessibilityLabel("Review required")

        case nil:
            Image(systemName: "minus")
                .foregroundStyle(.tertiary)
                .help("No review decision")
                .accessibilityLabel("No review decision")
        }
    }
}

private struct GitHubConnectionRow: View {
    @ObservedObject var connection: GitHubConnection

    var body: some View {
        switch connection.state {
        case .idle, .connecting:
            Label {
                Text("Connecting…")
            } icon: {
                ProgressView()
                    .controlSize(.small)
            }

        case .connected(let user):
            Label(
                "Connected as @\(user.login)",
                systemImage: "person.crop.circle.badge.checkmark"
            )

        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "GitHub not connected",
                    systemImage: "exclamationmark.triangle"
                )

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Button("Retry") {
                    Task {
                        await connection.connect()
                    }
                }
                .buttonStyle(.link)
            }
        }
    }
}

private struct SidebarItem: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String

    static let pullRequests = SidebarItem(
        id: "pullRequests",
        title: "Pull Requests",
        systemImage: "arrow.triangle.pull"
    )

    static let needsReview = SidebarItem(
        id: "needsReview",
        title: "Needs Review",
        systemImage: "checkmark.bubble"
    )

    static let commits = SidebarItem(
        id: "commits",
        title: "Commits",
        systemImage: "clock.arrow.circlepath"
    )

    static let settings = SidebarItem(
        id: "settings",
        title: "Settings",
        systemImage: "gearshape"
    )

    static let workspaceItems: [SidebarItem] = [
        .needsReview,
        .commits
    ]
}

#if DEBUG
#Preview("Sidebar") {
    SidebarView(
        connection: GitHubConnection.preview(),
        selectedPullRequestID: .constant(nil),
        onOpenPullRequest: { _ in }
    )
    .frame(width: 300, height: 720)
}
#endif
