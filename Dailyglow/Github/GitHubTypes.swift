import Foundation

nonisolated struct GitHubUser: Decodable, Sendable {
    let login: String
    let name: String?
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case login
        case name
        case avatarURL = "avatar_url"
    }
}

nonisolated enum GitHubReviewDecision: String, Decodable, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
}

nonisolated enum GitHubMergeStateStatus: String, Decodable, Sendable {
    case behind = "BEHIND"
    case blocked = "BLOCKED"
    case clean = "CLEAN"
    case dirty = "DIRTY"
    case draft = "DRAFT"
    case hasHooks = "HAS_HOOKS"
    case unknown = "UNKNOWN"
    case unstable = "UNSTABLE"
}

nonisolated enum GitHubMergeableState: String, Decodable, Sendable {
    case conflicting = "CONFLICTING"
    case mergeable = "MERGEABLE"
    case unknown = "UNKNOWN"
}

nonisolated enum GitHubStatusCheckState: String, Decodable, Sendable {
    case error = "ERROR"
    case expected = "EXPECTED"
    case failure = "FAILURE"
    case pending = "PENDING"
    case success = "SUCCESS"
}

nonisolated struct GitHubStatusCheckRollup: Decodable, Sendable {
    let state: GitHubStatusCheckState
}

nonisolated struct PullRequest: Decodable, Identifiable, Sendable {
    struct Repository: Decodable, Sendable {
        let name: String
        let nameWithOwner: String
    }

    let number: Int
    let title: String
    let url: URL
    let repository: Repository
    let isDraft: Bool
    let updatedAt: Date
    let reviewDecision: GitHubReviewDecision?
    let mergeStateStatus: GitHubMergeStateStatus
    let mergeable: GitHubMergeableState
    let statusCheckRollup: GitHubStatusCheckRollup?

    var id: URL { url }
}

nonisolated struct PullRequestInbox: Sendable {
    struct Open: Sendable {
        let needsAction: [PullRequest]
        let waitingForReviewOrChecks: [PullRequest]
        let readyToMerge: [PullRequest]

        var count: Int {
            pullRequests.count
        }

        var pullRequests: [PullRequest] {
            (needsAction + waitingForReviewOrChecks + readyToMerge)
                .sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    let open: Open
    let drafts: [PullRequest]
    let needsYourReview: [PullRequest]

    static let empty = PullRequestInbox(
        open: Open(
            needsAction: [],
            waitingForReviewOrChecks: [],
            readyToMerge: []
        ),
        drafts: [],
        needsYourReview: []
    )

    var authoredPullRequests: [PullRequest] {
        open.pullRequests + drafts
    }

    init(
        authoredPullRequests: [PullRequest],
        needsYourReview: [PullRequest]
    ) {
        var needsAction: [PullRequest] = []
        var waitingForReviewOrChecks: [PullRequest] = []
        var readyToMerge: [PullRequest] = []

        for pullRequest in authoredPullRequests where !pullRequest.isDraft {
            switch Self.category(for: pullRequest) {
            case .needsAction:
                needsAction.append(pullRequest)
            case .waitingForReviewOrChecks:
                waitingForReviewOrChecks.append(pullRequest)
            case .readyToMerge:
                readyToMerge.append(pullRequest)
            }
        }

        open = Open(
            needsAction: Self.newestFirst(needsAction),
            waitingForReviewOrChecks: Self.newestFirst(
                waitingForReviewOrChecks
            ),
            readyToMerge: Self.newestFirst(readyToMerge)
        )
        drafts = Self.newestFirst(
            authoredPullRequests.filter(\.isDraft)
        )
        self.needsYourReview = Self.newestFirst(needsYourReview)
    }

    private init(
        open: Open,
        drafts: [PullRequest],
        needsYourReview: [PullRequest]
    ) {
        self.open = open
        self.drafts = drafts
        self.needsYourReview = needsYourReview
    }

    private enum OpenCategory {
        case needsAction
        case waitingForReviewOrChecks
        case readyToMerge
    }

    private static func category(
        for pullRequest: PullRequest
    ) -> OpenCategory {
        if pullRequest.reviewDecision == .changesRequested
            || pullRequest.statusCheckRollup?.state == .error
            || pullRequest.statusCheckRollup?.state == .failure
            || pullRequest.mergeable == .conflicting
            || pullRequest.mergeStateStatus == .behind
            || pullRequest.mergeStateStatus == .dirty
            || pullRequest.mergeStateStatus == .unstable
        {
            return .needsAction
        }

        if pullRequest.mergeStateStatus == .clean
            || pullRequest.mergeStateStatus == .hasHooks
        {
            return .readyToMerge
        }

        if pullRequest.reviewDecision == .reviewRequired
            || pullRequest.statusCheckRollup?.state == .expected
            || pullRequest.statusCheckRollup?.state == .pending
            || pullRequest.mergeStateStatus == .unknown
        {
            return .waitingForReviewOrChecks
        }

        return pullRequest.mergeStateStatus == .blocked
            ? .needsAction
            : .waitingForReviewOrChecks
    }

    private static func newestFirst(
        _ pullRequests: [PullRequest]
    ) -> [PullRequest] {
        pullRequests.sorted { $0.updatedAt > $1.updatedAt }
    }
}

nonisolated struct PullRequestSearchResponse: Decodable, Sendable {
    struct ResponseData: Decodable, Sendable {
        let search: SearchResult
    }

    struct SearchResult: Decodable, Sendable {
        let nodes: [PullRequest]
        let pageInfo: PageInfo
    }

    struct PageInfo: Decodable, Sendable {
        let hasNextPage: Bool
        let endCursor: String?
    }

    let data: ResponseData
}

nonisolated enum GitHubClientError: LocalizedError, Sendable {
    case cliNotFound
    case couldNotLaunch(String)
    case commandFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "GitHub CLI was not found. Install it with Homebrew first."
        case .couldNotLaunch(let message):
            return "Dailyglow could not launch GitHub CLI: \(message)"
        case .commandFailed(let message):
            return message
        case .invalidResponse:
            return "GitHub returned a response Dailyglow could not understand."
        }
    }
}
