import Foundation
import WebKit

@MainActor
final class BrowserTab: Identifiable {
    let id = UUID()
    let page: WebPage
    private var requestedURL: URL?

    init(url: URL?, dataStore: WKWebsiteDataStore) {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = dataStore

        let page = WebPage(configuration: configuration)
        self.page = page
        requestedURL = url

        if let url {
            page.load(url)
        }
    }

    func represents(_ url: URL) -> Bool {
        let currentURL = page.url ?? requestedURL

        if let currentPullRequest = currentURL.flatMap(PullRequestID.init),
           let incomingPullRequest = PullRequestID(url: url) {
            return currentPullRequest == incomingPullRequest
        }

        return currentURL == url
    }

    func load(_ url: URL) {
        requestedURL = url
        page.load(url)
    }

    var title: String {
        if !page.title.isEmpty {
            return page.title
        }

        guard let url = page.url else {
            return "New Tab"
        }

        if let pullRequest = PullRequestID(url: url) {
            return "\(pullRequest.repository) #\(pullRequest.number)"
        }

        return url.host ?? "GitHub"
    }
}

private struct PullRequestID: Equatable {
    let owner: String
    let repository: String
    let number: Int

    init?(url: URL) {
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 4,
              components[2] == "pull",
              let number = Int(components[3])
        else {
            return nil
        }

        owner = components[0].lowercased()
        repository = components[1].lowercased()
        self.number = number
    }
}
