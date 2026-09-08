import SwiftUI

struct SidebarSectionHeader: View {
    let title: String
    let leadingImage: String?
    let actionTitle: String?
    let systemImage: String?
    let isWorking: Bool
    let action: (() -> Void)?

    @State private var isHovering = false

    init(
        title: String,
        leadingImage: String? = nil,
        actionTitle: String? = nil,
        systemImage: String? = nil,
        isWorking: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.leadingImage = leadingImage
        self.actionTitle = actionTitle
        self.systemImage = systemImage
        self.isWorking = isWorking
        self.action = action
    }

    var body: some View {
        HStack(spacing: 8) {
            if let leadingImage {
                Image(leadingImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.black)
                    .frame(width: 19, height: 19)
            }

            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color.black)

            Spacer(minLength: 8)

            if let actionTitle, let systemImage, let action {
                Group {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 22, height: 22)
                    } else {
                        Button(action: action) {
                            Image(systemName: systemImage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.black)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(actionTitle)
                    }
                }
                .opacity(isHovering || isWorking ? 1 : 0)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { isHovering in
            self.isHovering = isHovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isWorking)
    }
}

#if DEBUG
#Preview("Sidebar Section Header") {
    SidebarSectionHeader(
        title: "Pull Requests",
        actionTitle: "Refresh Pull Requests",
        systemImage: "arrow.clockwise",
        action: {}
    )
    .padding()
    .frame(width: 260)
}
#endif
