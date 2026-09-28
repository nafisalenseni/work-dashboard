import SwiftUI

struct ContentView: View {
    @State private var sidebarWidth: CGFloat = 280
    @State private var resizeStartWidth: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 900 || sidebarWidth < 200
            HStack(spacing: 0) {
                InboxPanelView(isCompact: compact)
                    .frame(width: compact ? 56 : min(sidebarWidth, geometry.size.width - 480))
                    .clipped()
                    .overlay(alignment: .trailing) {
                        Color.clear
                            .frame(width: 8)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering { NSCursor.resizeLeftRight.push() }
                                else { NSCursor.pop() }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .named("workspaceLayout"))
                                    .onChanged { value in
                                        if resizeStartWidth == nil { resizeStartWidth = compact ? 56 : sidebarWidth }
                                        sidebarWidth = min(420, max(64, (resizeStartWidth ?? sidebarWidth) + value.translation.width))
                                    }
                                    .onEnded { _ in resizeStartWidth = nil }
                            )
                            .accessibilityLabel("Sidebar width")
                            .accessibilityValue("\(Int(sidebarWidth)) points")
                            .accessibilityAdjustableAction { direction in
                                switch direction {
                                case .increment: sidebarWidth = min(420, sidebarWidth + 20)
                                case .decrement: sidebarWidth = max(64, sidebarWidth - 20)
                                @unknown default: break
                                }
                            }
                    }
                WorkspaceView()
                    .frame(minWidth: 400, maxWidth: .infinity)
            }
        }
        .frame(minWidth: 480, minHeight: 300)
        .coordinateSpace(name: "workspaceLayout")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .containerBackground(.ultraThinMaterial, for: .window)
    }
}

#if DEBUG
#Preview("Dailyglow") {
    ContentView()
}
#endif
