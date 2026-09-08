import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class BrowserSession {
    var isShowingCookieImporter = false
    var page: WebPage?
    private var pendingURL: URL?

    var canGoBack: Bool {
        page?.backForwardList.backList.isEmpty == false
    }

    var canGoForward: Bool {
        page?.backForwardList.forwardList.isEmpty == false
    }

    func goBack() {
        guard let page,
              let destination = page.backForwardList.backList.last
        else {
            return
        }

        page.load(destination)
    }

    func goForward() {
        guard let page,
              let destination = page.backForwardList.forwardList.first
        else {
            return
        }

        page.load(destination)
    }

    func reload() {
        page?.reload()
    }

    func attach(_ page: WebPage, initialURL: URL) {
        self.page = page

        let destination = pendingURL ?? initialURL
        pendingURL = nil
        page.load(destination)
    }

    func detach(_ page: WebPage) {
        if self.page === page {
            self.page = nil
        }
    }

    func open(_ incomingURL: URL) {
        guard let destination = Self.destinationURL(from: incomingURL) else {
            return
        }

        if let page {
            page.load(destination)
        } else {
            pendingURL = destination
        }
    }

    private static func destinationURL(from incomingURL: URL) -> URL? {
        if incomingURL.scheme == "https" {
            return validatedGitHubURL(incomingURL)
        }

        guard incomingURL.scheme == "dailyglow",
              incomingURL.host == "open",
              let components = URLComponents(
                url: incomingURL,
                resolvingAgainstBaseURL: false
              ),
              let destination = components.queryItems?.first(where: {
                $0.name == "url"
              })?.value,
              let destinationURL = URL(string: destination)
        else {
            return nil
        }

        return validatedGitHubURL(destinationURL)
    }

    private static func validatedGitHubURL(_ url: URL) -> URL? {
        guard url.scheme == "https",
              url.host == "github.com" || url.host == "www.github.com"
        else {
            return nil
        }

        return url
    }
}
