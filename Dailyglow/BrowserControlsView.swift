import SwiftUI

struct BrowserControlTab: Identifiable, Equatable {
    let id: UUID
    let title: String
}

struct BrowserToolbarContent: ToolbarContent {
    let tabs: [BrowserControlTab]
    let selectedTabID: BrowserControlTab.ID?
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let hasPage: Bool

    let onSelectTab: (BrowserControlTab.ID) -> Void
    let onCloseTab: (BrowserControlTab.ID) -> Void
    let onNewTab: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    let onHome: () -> Void
    let onReloadOrStop: () -> Void
    let onImportCookies: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            BrowserTabBarView(
                tabs: tabs,
                selectedTabID: selectedTabID,
                onSelectTab: onSelectTab,
                onCloseTab: onCloseTab,
                onNewTab: onNewTab
            )
        }

        ToolbarItemGroup(placement: .primaryAction) {
            BrowserControlsView(
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                isLoading: isLoading,
                hasPage: hasPage,
                onBack: onBack,
                onForward: onForward,
                onHome: onHome,
                onReloadOrStop: onReloadOrStop,
                onImportCookies: onImportCookies
            )
        }
    }
}

struct BrowserTabBarView: View {
    let tabs: [BrowserControlTab]
    let selectedTabID: BrowserControlTab.ID?

    let onSelectTab: (BrowserControlTab.ID) -> Void
    let onCloseTab: (BrowserControlTab.ID) -> Void
    let onNewTab: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        tabItem(tab)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("New Tab")
        }
        .frame(minWidth: 180, idealWidth: 420, maxWidth: 620)
    }

    private func tabItem(_ tab: BrowserControlTab) -> some View {
        HStack(spacing: 5) {
            Button {
                onSelectTab(tab.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.pull")
                        .foregroundStyle(.secondary)

                    Text(tab.title)
                        .lineLimit(1)
                        .frame(maxWidth: 140, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onCloseTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close Tab")
        }
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    tab.id == selectedTabID
                        ? Color.primary.opacity(0.10)
                        : Color.clear
                )
        }
    }
}

struct BrowserControlsView: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let hasPage: Bool

    let onBack: () -> Void
    let onForward: () -> Void
    let onHome: () -> Void
    let onReloadOrStop: () -> Void
    let onImportCookies: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .disabled(!canGoBack)

            Button(action: onForward) {
                Label("Forward", systemImage: "chevron.right")
            }
            .disabled(!canGoForward)

            Button(action: onHome) {
                Label("GitHub Home", systemImage: "house")
            }

            Button(action: onReloadOrStop) {
                Label(
                    isLoading ? "Stop" : "Reload",
                    systemImage: isLoading ? "xmark" : "arrow.clockwise"
                )
            }
            .disabled(!hasPage)

            Button(action: onImportCookies) {
                Label(
                    "Import Cookies",
                    systemImage: "square.and.arrow.down"
                )
            }
        }
        .labelStyle(.iconOnly)
    }
}

#if DEBUG
private let previewTabs = [
    BrowserControlTab(id: UUID(), title: "Dailyglow #128"),
    BrowserControlTab(id: UUID(), title: "Cookie importer")
]

#Preview("Browser Tabs") {
    BrowserTabBarView(
        tabs: previewTabs,
        selectedTabID: previewTabs.first?.id,
        onSelectTab: { _ in },
        onCloseTab: { _ in },
        onNewTab: {}
    )
    .padding()
}

#Preview("Browser Controls") {
    BrowserControlsView(
        canGoBack: true,
        canGoForward: false,
        isLoading: false,
        hasPage: true,
        onBack: {},
        onForward: {},
        onHome: {},
        onReloadOrStop: {},
        onImportCookies: {}
    )
    .padding()
}
#endif
