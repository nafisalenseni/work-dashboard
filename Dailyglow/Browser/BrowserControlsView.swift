import SwiftUI

struct BrowserControlsView: View {
    @Environment(BrowserSession.self) private var browserSession

    var body: some View {
        HStack(spacing: 8) {
            ControlButton(
                title: "Back",
                systemImage: "chevron.left",
                action: browserSession.goBack
            )
            .disabled(!browserSession.canGoBack)

            ControlButton(
                title: "Forward",
                systemImage: "chevron.right",
                action: browserSession.goForward
            )
            .disabled(!browserSession.canGoForward)

            ControlButton(
                title: "Reload",
                systemImage: "arrow.clockwise",
                action: browserSession.reload
            )
            .disabled(browserSession.page == nil)

            ControlButton(
                title: "Import Cookies",
                systemImage: "square.and.arrow.down",
                action: { browserSession.isShowingCookieImporter = true }
            )
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .fixedSize()
        .padding(6)
    }
}


struct ControlButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovered = false

    init(
        title: String,
        systemImage: String,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(
                            isHovered
                                ? Color.primary.opacity(0.10)
                                : Color.clear
                        )
                }
                .contentShape(Rectangle())
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(
            .easeOut(duration: 0.12),
            value: isHovered
        )
        .help(title)
    }
}


#if DEBUG
#Preview("Browser Controls") {
    BrowserControlsView()
        .environment(BrowserSession())
}
#endif
