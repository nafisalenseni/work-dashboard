import Foundation
import SwiftUI

struct MainView: View {
    let browserSession: BrowserSession

    init(
        browserSession: BrowserSession = BrowserSession()
    ) {
        self.browserSession = browserSession
    }

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            BrowserWebView(
                url: URL(string: "https://github.com/pulls/inbox")!
            )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
        }
        .environment(browserSession)
        .background(.white)
        .clipShape(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(
            color: .black.opacity(0.15),
            radius: 12,
            x: 0,
            y: 4
        )
        .padding(8)
        .onOpenURL(perform: browserSession.open)
    }
}

#if DEBUG
#Preview("Browser Content") {
    MainView()
}
#endif
