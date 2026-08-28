import Foundation
import Combine

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

nonisolated struct GitHubPullRequest: Decodable, Identifiable, Sendable {
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

    var id: URL { url }

    func withReviewDecision(
        _ reviewDecision: GitHubReviewDecision?
    ) -> GitHubPullRequest {
        GitHubPullRequest(
            number: number,
            title: title,
            url: url,
            repository: repository,
            isDraft: isDraft,
            updatedAt: updatedAt,
            reviewDecision: reviewDecision
        )
    }
}

nonisolated private struct PullRequestReviewDetails: Decodable, Sendable {
    let reviewDecision: GitHubReviewDecision?
}

nonisolated struct GitHubClient: Sendable {
    func fetchCurrentUser() async throws -> GitHubUser {
        let responseData = try await run(arguments: ["api", "user"])

        do {
            return try JSONDecoder().decode(GitHubUser.self, from: responseData)
        } catch {
            throw GitHubClientError.invalidResponse
        }
    }

    func fetchOpenPullRequests() async throws -> [GitHubPullRequest] {
        let responseData = try await run(arguments: [
            "search", "prs",
            "--author", "@me",
            "--state", "open",
            "--limit", "1000",
            "--json", "number,title,url,repository,isDraft,updatedAt"
        ])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let pullRequests: [GitHubPullRequest]

        do {
            pullRequests = try decoder.decode(
                [GitHubPullRequest].self,
                from: responseData
            )
        } catch {
            throw GitHubClientError.invalidResponse
        }

        return await addReviewDecisions(to: pullRequests)
    }

    private func addReviewDecisions(
        to pullRequests: [GitHubPullRequest]
    ) async -> [GitHubPullRequest] {
        await withTaskGroup(
            of: (URL, GitHubReviewDecision?).self
        ) { group in
            for pullRequest in pullRequests {
                group.addTask {
                    do {
                        let responseData = try await run(arguments: [
                            "pr", "view",
                            pullRequest.url.absoluteString,
                            "--json", "reviewDecision"
                        ])
                        let details = try JSONDecoder().decode(
                            PullRequestReviewDetails.self,
                            from: responseData
                        )
                        return (pullRequest.url, details.reviewDecision)
                    } catch {
                        return (pullRequest.url, nil)
                    }
                }
            }

            var reviewDecisions: [URL: GitHubReviewDecision] = [:]

            for await (url, reviewDecision) in group {
                if let reviewDecision {
                    reviewDecisions[url] = reviewDecision
                }
            }

            return pullRequests.map { pullRequest in
                pullRequest.withReviewDecision(
                    reviewDecisions[pullRequest.url]
                )
            }
        }
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
    enum State {
        case idle
        case connecting
        case connected(GitHubUser)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var openPullRequests: [GitHubPullRequest] = []
    @Published private(set) var pullRequestError: String?
    private let client = GitHubClient()

    func connect() async {
        if case .connecting = state { return }

        state = .connecting

        do {
            let user = try await client.fetchCurrentUser()
            state = .connected(user)
            await loadOpenPullRequests()
        } catch {
            state = .failed(error.localizedDescription)
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

        let repository = GitHubPullRequest.Repository(
            name: "dailyglow",
            nameWithOwner: "octocat/dailyglow"
        )

        connection.openPullRequests = [
            GitHubPullRequest(
                number: 128,
                title: "Polish the browser sidebar layout",
                url: URL(string: "https://github.com/octocat/dailyglow/pull/128")!,
                repository: repository,
                isDraft: false,
                updatedAt: Date(),
                reviewDecision: .reviewRequired
            ),
            GitHubPullRequest(
                number: 121,
                title: "Add cookie table importing",
                url: URL(string: "https://github.com/octocat/dailyglow/pull/121")!,
                repository: repository,
                isDraft: false,
                updatedAt: Date().addingTimeInterval(-3_600),
                reviewDecision: .approved
            ),
            GitHubPullRequest(
                number: 119,
                title: "Experiment with component previews",
                url: URL(string: "https://github.com/octocat/dailyglow/pull/119")!,
                repository: repository,
                isDraft: true,
                updatedAt: Date().addingTimeInterval(-7_200),
                reviewDecision: nil
            )
        ]

        return connection
    }
#endif

    private func loadOpenPullRequests() async {
        do {
            let pullRequests = try await client.fetchOpenPullRequests()
            openPullRequests = pullRequests
            pullRequestError = nil
            printPullRequests(pullRequests)
        } catch {
            pullRequestError = error.localizedDescription
            print("Dailyglow could not fetch open pull requests: \(error.localizedDescription)")
        }
    }

    private func printPullRequests(_ pullRequests: [GitHubPullRequest]) {
        print("\nDailyglow found \(pullRequests.count) open pull request\(pullRequests.count == 1 ? "" : "s"):")

        if pullRequests.isEmpty {
            print("  No open pull requests authored by you. ✨")
            return
        }

        for pullRequest in pullRequests {
            let draftLabel = pullRequest.isDraft ? " [Draft]" : ""
            let reviewLabel = pullRequest.reviewDecision.map {
                " [\($0.rawValue)]"
            } ?? ""
            print("  • \(pullRequest.repository.nameWithOwner)#\(pullRequest.number)\(draftLabel)\(reviewLabel)")
            print("    \(pullRequest.title)")
            print("    \(pullRequest.url.absoluteString)")
        }
    }
}

nonisolated private enum GitHubClientError: LocalizedError, Sendable {
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
