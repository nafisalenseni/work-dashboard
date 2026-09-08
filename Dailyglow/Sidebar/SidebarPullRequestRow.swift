import AppKit
import SwiftUI

struct SidebarPullRequestRow: View {
    let pullRequest: PullRequest
    let onOpen: () -> Void

    @State private var isHovering = false
    @State private var isCopyHovering = false

    init(
        pullRequest: PullRequest,
        onOpen: @escaping () -> Void = {}
    ) {
        self.pullRequest = pullRequest
        self.onOpen = onOpen
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 10) {
                    Image(
                        pullRequest.isDraft
                            ? "GitPullRequestDraft"
                            : "GitPullRequest"
                    )
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(iconColor)
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(pullRequest.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.black)
                            .lineLimit(2)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )

                        SidebarPullRequestMetadata(
                            pullRequest: pullRequest
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(
                "Open \(pullRequest.repository.nameWithOwner)"
                    + "#\(pullRequest.number)"
            )

            Button(action: copyLink) {
                Image("GitCopy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.black.opacity(0.72))
                    .frame(width: 15, height: 15)
                    .frame(width: 26, height: 26)
                    .background {
                        RoundedRectangle(
                            cornerRadius: 6,
                            style: .continuous
                        )
                        .fill(
                            Color.black.opacity(
                                isCopyHovering ? 0.12 : 0.07
                            )
                        )
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .onHover { isHovering in
                isCopyHovering = isHovering
            }
            .help("Copy link to clipboard")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovering ? Color.black.opacity(0.06) : .clear)
        }
        .contentShape(Rectangle())
        .onHover { isHovering in
            self.isHovering = isHovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isCopyHovering)
    }

    private func copyLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            pullRequest.url.absoluteString,
            forType: .string
        )
    }

    private var iconColor: Color {
        pullRequest.isDraft
            ? Color(red: 0.40, green: 0.43, blue: 0.47)
            : Color(red: 0.10, green: 0.50, blue: 0.22)
    }
}

struct SidebarPullRequestLoadingRow: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image("GitPullRequest")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.black.opacity(0.14))
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 13)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.black.opacity(0.09))
                    .frame(width: 112, height: 10)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isPulsing ? 0.48 : 1)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Pull Request Row") {
    SidebarPullRequestRow(
        pullRequest: PullRequest(
            number: 929_827,
            title: "Desktop: update electron bump script",
            url: URL(string: "https://github.com/figma/figma/pull/929827")!,
            repository: PullRequest.Repository(
                name: "figma",
                nameWithOwner: "figma/figma"
            ),
            isDraft: false,
            updatedAt: Date(),
            reviewDecision: .reviewRequired,
            mergeStateStatus: .blocked,
            mergeable: .mergeable,
            statusCheckRollup: GitHubStatusCheckRollup(state: .pending)
        )
    )
    .padding()
    .frame(width: 320)
}
#endif
