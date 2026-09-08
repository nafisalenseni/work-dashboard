import Foundation
import Combine

nonisolated struct GitHubClient: Sendable {
    private static let pullRequestSearchQuery = """
    query($searchQuery: String!, $cursor: String) {
      search(
        query: $searchQuery
        type: ISSUE
        first: 100
        after: $cursor
      ) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          ... on PullRequest {
            number
            title
            url
            isDraft
            updatedAt
            reviewDecision
            mergeStateStatus
            mergeable
            statusCheckRollup {
              state
            }
            repository {
              name
              nameWithOwner
            }
          }
        }
      }
    }
    """

    func fetchCurrentUser() async throws -> GitHubUser {
        let responseData = try await run(arguments: ["api", "user"])

        do {
            return try JSONDecoder().decode(GitHubUser.self, from: responseData)
        } catch {
            throw GitHubClientError.invalidResponse
        }
    }

    func fetchPullRequestInbox() async throws -> PullRequestInbox {
        async let authoredPullRequests = searchPullRequests(
            matching: "is:pr is:open author:@me"
        )
        async let needsYourReview = searchPullRequests(
            matching: "is:pr is:open user-review-requested:@me"
        )

        return try await PullRequestInbox(
            authoredPullRequests: authoredPullRequests,
            needsYourReview: needsYourReview
        )
    }

    private func searchPullRequests(
        matching searchQuery: String
    ) async throws -> [PullRequest] {
        var cursor: String?
        var pullRequestsByURL: [URL: PullRequest] = [:]

        repeat {
            var arguments = [
                "api", "graphql",
                "-f", "query=\(Self.pullRequestSearchQuery)",
                "-f", "searchQuery=\(searchQuery)"
            ]

            if let cursor {
                arguments.append(contentsOf: ["-f", "cursor=\(cursor)"])
            }

            let responseData = try await run(arguments: arguments)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let response: PullRequestSearchResponse

            do {
                response = try decoder.decode(
                    PullRequestSearchResponse.self,
                    from: responseData
                )
            } catch {
                throw GitHubClientError.invalidResponse
            }

            for pullRequest in response.data.search.nodes {
                pullRequestsByURL[pullRequest.url] = pullRequest
            }

            let pageInfo = response.data.search.pageInfo
            cursor = pageInfo.hasNextPage ? pageInfo.endCursor : nil
        } while cursor != nil

        return Array(pullRequestsByURL.values)
    }

    private func run(arguments: [String]) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let executableURL = try findGitHubCLI()
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError

            var environment = ProcessInfo.processInfo.environment
            environment["GH_PAGER"] = "cat"
            environment["NO_COLOR"] = "1"
            process.environment = environment

            do {
                try process.run()
            } catch {
                throw GitHubClientError.couldNotLaunch(error.localizedDescription)
            }

            process.waitUntilExit()

            let responseData = standardOutput.fileHandleForReading.readDataToEndOfFile()
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let failureMessage = message.flatMap {
                    $0.isEmpty ? nil : $0
                } ?? "GitHub CLI exited with an error."

                throw GitHubClientError.commandFailed(
                    failureMessage
                )
            }

            return responseData
        }.value
    }

    private func findGitHubCLI() throws -> URL {
        let candidatePaths = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh"
        ]

        guard let path = candidatePaths.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            throw GitHubClientError.cliNotFound
        }

        return URL(fileURLWithPath: path)
    }
}

@MainActor
final class GitHubConnection: ObservableObject {
    private static let refreshInterval: Duration = .seconds(5 * 60)

    enum State {
        case idle
        case connecting
        case connected(GitHubUser)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var openPullRequests: [PullRequest] = []
    @Published private(set) var pullRequestInbox = PullRequestInbox.empty
    @Published private(set) var pullRequestError: String?
    @Published private(set) var isLoadingPullRequests = false
    private let client = GitHubClient()

    func connect() async {
        guard !isLoadingPullRequests else { return }

        state = .connecting
        isLoadingPullRequests = true
        defer { isLoadingPullRequests = false }

        do {
            let user = try await client.fetchCurrentUser()
            state = .connected(user)
            await loadPullRequestInbox()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refreshPeriodically() async {
        while !Task.isCancelled {
            await connect()

            do {
                try await Task.sleep(for: Self.refreshInterval)
            } catch {
                return
            }
        }
    }

#if DEBUG
    static func preview() -> GitHubConnection {
        let connection = GitHubConnection()
        connection.state = .connected(
            GitHubUser(
                login: "octocat",
                name: "The Octocat",
                avatarURL: nil
            )
        )

        let repository = PullRequest.Repository(
            name: "dailyglow",
            nameWithOwner: "octocat/dailyglow"
        )

        connection.openPullRequests = [
            PullRequest(
                number: 128,
                title: "Polish the browser sidebar layout",
                url: URL(string: "https://github.com/octocat/dailyglow/pull/128")!,
                repository: repository,
                isDraft: false,
                updatedAt: Date(),
                reviewDecision: .reviewRequired,
                mergeStateStatus: .blocked,
                mergeable: .mergeable,
                statusCheckRollup: GitHubStatusCheckRollup(state: .pending)
            ),
            PullRequest(
                number: 121,
                title: "Add cookie table importing",
                url: URL(string: "https://github.com/octocat/dailyglow/pull/121")!,
                repository: repository,
                isDraft: false,
                updatedAt: Date().addingTimeInterval(-3_600),
                reviewDecision: .approved,
                mergeStateStatus: .clean,
                mergeable: .mergeable,
                statusCheckRollup: GitHubStatusCheckRollup(state: .success)
            ),
            PullRequest(
                number: 119,
                title: "Experiment with component previews",
                url: URL(string: "https://github.com/octocat/dailyglow/pull/119")!,
                repository: repository,
                isDraft: true,
                updatedAt: Date().addingTimeInterval(-7_200),
                reviewDecision: nil,
                mergeStateStatus: .draft,
                mergeable: .mergeable,
                statusCheckRollup: nil
            )
        ]
        connection.pullRequestInbox = PullRequestInbox(
            authoredPullRequests: connection.openPullRequests,
            needsYourReview: []
        )

        return connection
    }
#endif

    private func loadPullRequestInbox() async {
        do {
            let inbox = try await client.fetchPullRequestInbox()
            pullRequestInbox = inbox
            openPullRequests = inbox.authoredPullRequests
            pullRequestError = nil
            printPullRequestInbox(inbox)
        } catch {
            pullRequestError = error.localizedDescription
            print(
                "Dailyglow could not fetch the pull request inbox: "
                    + error.localizedDescription
            )
        }
    }

    private func printPullRequestInbox(_ inbox: PullRequestInbox) {
        print("\n✨ Dailyglow Pull Request Inbox")
        printPullRequests(inbox.open.pullRequests, title: "Open", indent: "")
        printPullRequests(inbox.drafts, title: "Your drafts", indent: "")
        printPullRequests(
            inbox.needsYourReview,
            title: "Needs your review",
            indent: ""
        )
        print("")
    }

    private func printPullRequests(
        _ pullRequests: [PullRequest],
        title: String,
        indent: String = "  "
    ) {
        print("\(indent)\(title) (\(pullRequests.count))")

        for pullRequest in pullRequests {
            let detailIndent = indent + "  "
            let metadataIndent = detailIndent + "  "
            let review = pullRequest.reviewDecision?.rawValue ?? "NONE"
            let checks = pullRequest.statusCheckRollup?.state.rawValue ?? "NONE"

            print(
                "\(detailIndent)• "
                    + "\(pullRequest.repository.nameWithOwner)"
                    + "#\(pullRequest.number)"
            )
            print("\(metadataIndent)\(pullRequest.title)")
            print(
                "\(metadataIndent)review=\(review) "
                    + "merge=\(pullRequest.mergeStateStatus.rawValue) "
                    + "checks=\(checks)"
            )
            print("\(metadataIndent)\(pullRequest.url.absoluteString)")
        }
    }
}
