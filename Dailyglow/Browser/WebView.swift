import Foundation
import SwiftUI
import WebKit

struct BrowserWebView: View {
    let url: URL

    @Environment(BrowserSession.self) private var browserSession
    @State private var page: WebPage

    private let dataStore: WKWebsiteDataStore

    init(
        url: URL,
        dataStore: WKWebsiteDataStore = .default()
    ) {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = dataStore

        let page = WebPage(configuration: configuration)

        self.url = url
        self.dataStore = dataStore
        _page = State(initialValue: page)
    }

    var body: some View {
        @Bindable var browserSession = browserSession

        WebKit.WebView(page)
            .webViewBackForwardNavigationGestures(.enabled)
            .overlay(alignment: .top) {
                if page.isLoading {
                    ProgressView(value: page.estimatedProgress)
                        .progressViewStyle(.linear)
                        .transition(.opacity)
                }
            }
            .task(id: url) {
                browserSession.attach(page, initialURL: url)
            }
            .onDisappear {
                browserSession.detach(page)
            }
            .webCookieImporter(
                isPresented: $browserSession.isShowingCookieImporter,
                page: page,
                dataStore: dataStore,
                url: page.url ?? url
            )
            .animation(.easeInOut(duration: 0.15), value: page.isLoading)
    }
}

private struct WebCookieImportModifier: ViewModifier {
    @Binding var isPresented: Bool

    let page: WebPage?
    let dataStore: WKWebsiteDataStore
    let url: URL

    @State private var importedCookieCount = 0
    @State private var isShowingImportConfirmation = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if let host = url.host {
                    CookieImportSheet(
                        defaultDomain: host,
                        secureByDefault: url.scheme == "https",
                        onImport: importCookies
                    )
                } else {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "Cookies Unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text(
                                "This URL does not have a host to associate with cookies."
                            )
                        )

                        Button("Close") {
                            isPresented = false
                        }
                    }
                    .padding(24)
                    .frame(minWidth: 420, minHeight: 240)
                }
            }
            .alert(
                "Cookies Imported",
                isPresented: $isShowingImportConfirmation
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importConfirmationMessage)
            }
    }

    private var importConfirmationMessage: String {
        let cookieWord = importedCookieCount == 1 ? "cookie" : "cookies"
        let destination = url.host ?? "the page"
        return "Imported \(importedCookieCount) \(cookieWord) and reloaded \(destination)."
    }

    private func importCookies(_ cookies: [HTTPCookie]) {
        dataStore.httpCookieStore.setCookies(cookies) {
            importedCookieCount = cookies.count
            isShowingImportConfirmation = true
            page?.reload()
        }
    }
}

extension View {
    func webCookieImporter(
        isPresented: Binding<Bool>,
        page: WebPage?,
        dataStore: WKWebsiteDataStore,
        url: URL
    ) -> some View {
        modifier(
            WebCookieImportModifier(
                isPresented: isPresented,
                page: page,
                dataStore: dataStore,
                url: url
            )
        )
    }
}

#if DEBUG
#Preview("Generic Web View") {
    BrowserWebView(
        url: URL(string: "https://example.com")!
    )
    .environment(BrowserSession())
    .frame(width: 760, height: 640)
}
#endif
