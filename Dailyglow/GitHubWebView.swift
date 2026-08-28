import SwiftUI
import WebKit

struct GitHubNavigationRequest: Equatable {
    let id = UUID()
    let url: URL
}

struct GitHubWebView: View {
    @State private var tabs: [BrowserTab]
    @State private var selectedTabID: BrowserTab.ID
    @State private var isShowingCookieImporter = false
    @State private var importedCookieCount = 0
    @State private var isShowingImportConfirmation = false

    private let dataStore: WKWebsiteDataStore
    private let navigationRequest: GitHubNavigationRequest?

    private static let homeURL = URL(string: "https://github.com")

    init(
        navigationRequest: GitHubNavigationRequest? = nil,
        startsAtHome: Bool = true
    ) {
        let dataStore = WKWebsiteDataStore.default()
        let firstTab = BrowserTab(
            url: startsAtHome ? Self.homeURL : nil,
            dataStore: dataStore
        )

        self.dataStore = dataStore
        self.navigationRequest = navigationRequest
        _tabs = State(initialValue: [firstTab])
        _selectedTabID = State(initialValue: firstTab.id)
    }

    var body: some View {
        Group {
            if let tab = selectedTab {
                WebView(tab.page)
                    .id(tab.id)
                    .webViewBackForwardNavigationGestures(.enabled)
                    .overlay(alignment: .top) {
                        if tab.page.isLoading {
                            ProgressView(value: tab.page.estimatedProgress)
                                .progressViewStyle(.linear)
                                .transition(.opacity)
                        }
                    }
            } else {
                ContentUnavailableView(
                    "No Open Tabs",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("Open a new tab to keep browsing GitHub.")
                )
            }
        }
        .toolbar {
            BrowserToolbarContent(
                tabs: tabs.map {
                    BrowserControlTab(id: $0.id, title: $0.title)
                },
                selectedTabID: selectedTabID,
                canGoBack: selectedPage?.backForwardList.backList.isEmpty == false,
                canGoForward: selectedPage?.backForwardList.forwardList.isEmpty == false,
                isLoading: selectedPage?.isLoading == true,
                hasPage: selectedPage != nil,
                onSelectTab: { selectedTabID = $0 },
                onCloseTab: closeTab,
                onNewTab: addHomeTab,
                onBack: goBack,
                onForward: goForward,
                onHome: loadHome,
                onReloadOrStop: reloadOrStop,
                onImportCookies: { isShowingCookieImporter = true }
            )
        }
        .sheet(isPresented: $isShowingCookieImporter) {
            CookieImportSheet(onImport: importCookies)
        }
        .alert("Cookies Imported", isPresented: $isShowingImportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Imported \(importedCookieCount) cookie\(importedCookieCount == 1 ? "" : "s") and reloaded GitHub.")
        }
        .onOpenURL(perform: openIncomingURL)
        .onChange(of: navigationRequest) { _, request in
            openTab(for: request?.url)
        }
        .animation(.easeInOut(duration: 0.15), value: selectedPage?.isLoading)
    }

    private var selectedTab: BrowserTab? {
        tabs.first(where: { $0.id == selectedTabID })
    }

    private var selectedPage: WebPage? {
        selectedTab?.page
    }

    private func goBack() {
        guard let page = selectedPage,
              let item = page.backForwardList.backList.last
        else {
            return
        }

        page.load(item)
    }

    private func goForward() {
        guard let page = selectedPage,
              let item = page.backForwardList.forwardList.first
        else {
            return
        }

        page.load(item)
    }

    private func loadHome() {
        selectedPage?.load(Self.homeURL)
    }

    private func addHomeTab() {
        openTab(for: Self.homeURL)
    }

    private func reloadOrStop() {
        guard let page = selectedPage else { return }

        if page.isLoading {
            page.stopLoading()
        } else {
            page.reload()
        }
    }

    private func importCookies(_ cookies: [HTTPCookie]) {
        dataStore.httpCookieStore.setCookies(cookies) {
            importedCookieCount = cookies.count
            isShowingImportConfirmation = true
            selectedPage?.reload()
        }
    }

    private func openIncomingURL(_ incomingURL: URL) {
        guard let githubURL = Self.githubURL(from: incomingURL) else { return }
        openTab(for: githubURL)
    }

    private func openTab(for url: URL?) {
        guard let url else { return }

        if let existingTab = tabs.first(where: { $0.represents(url) }) {
            selectedTabID = existingTab.id
            existingTab.load(url)
            return
        }

        let tab = BrowserTab(url: url, dataStore: dataStore)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    private func closeTab(_ tabID: BrowserTab.ID) {
        guard let closingIndex = tabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }

        let wasSelected = selectedTabID == tabID
        tabs.remove(at: closingIndex)

        if tabs.isEmpty {
            let replacementTab = BrowserTab(
                url: Self.homeURL,
                dataStore: dataStore
            )
            tabs = [replacementTab]
            selectedTabID = replacementTab.id
        } else if wasSelected {
            let nextIndex = min(closingIndex, tabs.count - 1)
            selectedTabID = tabs[nextIndex].id
        }
    }

    private static func githubURL(from incomingURL: URL) -> URL? {
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

#if DEBUG
#Preview("Browser Content") {
    GitHubWebView(startsAtHome: false)
        .frame(width: 760, height: 640)
}
#endif
